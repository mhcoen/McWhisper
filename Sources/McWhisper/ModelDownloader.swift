import Foundation

// MARK: - Download State

enum ModelDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case downloaded
    case failed(String)

    var isDownloading: Bool {
        if case .downloading = self { return true }
        return false
    }
}

enum ModelDownloadError: Error, Equatable {
    case invalidResponse
    case networkError(String)
    case noFilesFound
}

// MARK: - Model Downloader

@MainActor
final class ModelDownloader: ObservableObject {
    @Published var downloads: [String: ModelDownloadState] = [:]

    let modelsDirectory: URL

    /// Non-isolated path string for use from any context.
    nonisolated static let modelsDirectoryPath: String = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("McWhisper/Models", isDirectory: true).path
    }()

    static let defaultModelsDirectory: URL = {
        URL(fileURLWithPath: modelsDirectoryPath)
    }()

    nonisolated static let repoID = "argmaxinc/whisperkit-coreml"

    /// Resolves the HuggingFace repo slug for a given model ID.
    /// WhisperKit models use the shared `repoID`; qwen3-asr engine models
    /// use per-model repos from `ModelCatalog.huggingFaceModelID(for:)`.
    nonisolated static func repoID(for modelID: String) -> String? {
        guard let model = ModelCatalog.model(for: modelID) else { return nil }
        switch model.engine {
        case .whisperKit:
            return repoID
        case .qwen3asr:
            return ModelCatalog.huggingFaceModelID(for: modelID)
        }
    }

    init(modelsDirectory: URL? = nil) {
        self.modelsDirectory = modelsDirectory ?? Self.defaultModelsDirectory
        refreshStates()
    }

    func refreshStates() {
        for model in ModelCatalog.availableModels {
            if model.isBundled {
                downloads[model.id] = .downloaded
            } else if let current = downloads[model.id], current.isDownloading {
                // preserve active downloads
            } else {
                downloads[model.id] = isModelDownloaded(model.id) ? .downloaded : .notDownloaded
            }
        }
    }

    func isModelDownloaded(_ modelID: String) -> Bool {
        let dir = modelsDirectory.appendingPathComponent(modelID)
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir) && isDir.boolValue
    }

    func modelDirectory(for modelID: String) -> URL {
        modelsDirectory.appendingPathComponent(modelID)
    }

    func state(for modelID: String) -> ModelDownloadState {
        downloads[modelID] ?? .notDownloaded
    }

    // MARK: - Download

    func downloadModel(_ modelID: String) async throws {
        guard let repo = Self.repoID(for: modelID) else {
            downloads[modelID] = .failed("Unknown model")
            throw ModelDownloadError.invalidResponse
        }

        let model = ModelCatalog.model(for: modelID)
        let isQwen = model?.engine == .qwen3asr

        downloads[modelID] = .downloading(progress: 0)

        do {
            try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

            let files = try await listFiles(for: modelID, repo: repo)
            guard !files.isEmpty else {
                downloads[modelID] = .failed("No model files found")
                throw ModelDownloadError.noFilesFound
            }

            let totalSize = files.reduce(Int64(0)) { $0 + $1.size }
            var completedSize: Int64 = 0

            let modelDir = modelsDirectory.appendingPathComponent(modelID)
            try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

            for file in files {
                try Task.checkCancellation()

                let encodedPath = file.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file.path
                // WhisperKit models live under a modelID subdirectory in the shared repo;
                // qwen3-asr models live at the repo root.
                let remotePath = isQwen ? encodedPath : "\(modelID)/\(encodedPath)"
                guard let fileURL = URL(string: "https://huggingface.co/\(repo)/resolve/main/\(remotePath)") else {
                    continue
                }

                let completedBefore = completedSize
                let fileSize = file.size
                let delegate = DownloadProgressDelegate { [weak self] fileProgress in
                    let currentBytes = Int64(Double(fileSize) * fileProgress)
                    let overall = totalSize > 0 ? Double(completedBefore + currentBytes) / Double(totalSize) : 0
                    Task { @MainActor [weak self] in
                        self?.downloads[modelID] = .downloading(progress: min(overall, 1.0))
                    }
                }

                let (tempURL, response) = try await URLSession.shared.download(from: fileURL, delegate: delegate)

                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    try? FileManager.default.removeItem(at: modelDir)
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    downloads[modelID] = .failed("HTTP \(code)")
                    throw ModelDownloadError.networkError("HTTP \(code)")
                }

                let destURL = modelDir.appendingPathComponent(file.path)
                try FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: destURL)

                completedSize += file.size
                downloads[modelID] = .downloading(progress: totalSize > 0 ? Double(completedSize) / Double(totalSize) : 1.0)
            }

            downloads[modelID] = .downloaded
        } catch is CancellationError {
            let modelDir = modelsDirectory.appendingPathComponent(modelID)
            try? FileManager.default.removeItem(at: modelDir)
            downloads[modelID] = .notDownloaded
            throw CancellationError()
        } catch {
            if downloads[modelID]?.isDownloading == true {
                downloads[modelID] = .failed(error.localizedDescription)
            }
            throw error
        }
    }

    // MARK: - Delete

    func deleteModel(_ modelID: String) throws {
        let modelDir = modelsDirectory.appendingPathComponent(modelID)
        if FileManager.default.fileExists(atPath: modelDir.path) {
            try FileManager.default.removeItem(at: modelDir)
        }
        downloads[modelID] = .notDownloaded
    }

    // MARK: - HuggingFace File Listing

    struct RemoteFile: Equatable {
        let path: String
        let size: Int64
    }

    func listFiles(for modelID: String, repo: String? = nil, subpath: String = "") async throws -> [RemoteFile] {
        let resolvedRepo = repo ?? Self.repoID
        let model = ModelCatalog.model(for: modelID)
        let isQwen = model?.engine == .qwen3asr

        // WhisperKit: files under {repo}/tree/main/{modelID}/{subpath}
        // qwen3-asr: files at {repo}/tree/main/{subpath} (repo root)
        let treePath: String
        if isQwen {
            treePath = subpath
        } else {
            treePath = subpath.isEmpty ? modelID : "\(modelID)/\(subpath)"
        }

        let apiPath: String
        if treePath.isEmpty {
            apiPath = "https://huggingface.co/api/models/\(resolvedRepo)/tree/main"
        } else {
            guard let encoded = treePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
                throw ModelDownloadError.invalidResponse
            }
            apiPath = "https://huggingface.co/api/models/\(resolvedRepo)/tree/main/\(encoded)"
        }

        guard let url = URL(string: apiPath) else {
            throw ModelDownloadError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ModelDownloadError.invalidResponse
        }

        guard let entries = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ModelDownloadError.invalidResponse
        }

        // For WhisperKit models, strip the modelID prefix from paths.
        // For qwen3-asr models, paths are already relative to the repo root.
        let stripPrefix = isQwen ? nil : (modelID + "/")

        var files: [RemoteFile] = []
        for entry in entries {
            guard let type = entry["type"] as? String else { continue }

            if type == "file" {
                guard let rfilename = entry["rfilename"] as? String else { continue }
                let size: Int64
                if let s = entry["size"] as? Int64 {
                    size = s
                } else if let s = entry["size"] as? Int {
                    size = Int64(s)
                } else {
                    size = 0
                }
                let relativePath: String
                if let prefix = stripPrefix, rfilename.hasPrefix(prefix) {
                    relativePath = String(rfilename.dropFirst(prefix.count))
                } else {
                    relativePath = rfilename
                }
                files.append(RemoteFile(path: relativePath, size: size))
            } else if type == "directory" {
                guard let path = entry["path"] as? String else { continue }
                let dirSubpath: String
                if let prefix = stripPrefix, path.hasPrefix(prefix) {
                    dirSubpath = String(path.dropFirst(prefix.count))
                } else {
                    dirSubpath = path
                }
                let subFiles = try await listFiles(for: modelID, repo: resolvedRepo, subpath: dirSubpath)
                files.append(contentsOf: subFiles)
            }
        }

        return files
    }
}

// MARK: - Download Progress Delegate

final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: (Double) -> Void

    init(onProgress: @escaping (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled by async/await return
    }
}
