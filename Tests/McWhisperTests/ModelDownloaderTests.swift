import Testing
import Foundation
@testable import McWhisper

@Suite("ModelDownloader")
struct ModelDownloaderTests {

    // MARK: - Download State

    @Test("ModelDownloadState equality")
    func downloadStateEquality() {
        #expect(ModelDownloadState.notDownloaded == ModelDownloadState.notDownloaded)
        #expect(ModelDownloadState.downloaded == ModelDownloadState.downloaded)
        #expect(ModelDownloadState.downloading(progress: 0.5) == ModelDownloadState.downloading(progress: 0.5))
        #expect(ModelDownloadState.downloading(progress: 0.5) != ModelDownloadState.downloading(progress: 0.7))
        #expect(ModelDownloadState.failed("err") == ModelDownloadState.failed("err"))
        #expect(ModelDownloadState.failed("a") != ModelDownloadState.failed("b"))
        #expect(ModelDownloadState.notDownloaded != ModelDownloadState.downloaded)
    }

    @Test("ModelDownloadState isDownloading")
    func isDownloading() {
        #expect(ModelDownloadState.downloading(progress: 0.5).isDownloading == true)
        #expect(ModelDownloadState.notDownloaded.isDownloading == false)
        #expect(ModelDownloadState.downloaded.isDownloading == false)
        #expect(ModelDownloadState.failed("err").isDownloading == false)
    }

    // MARK: - Error

    @Test("ModelDownloadError equality")
    func downloadErrorEquality() {
        #expect(ModelDownloadError.invalidResponse == ModelDownloadError.invalidResponse)
        #expect(ModelDownloadError.noFilesFound == ModelDownloadError.noFilesFound)
        #expect(ModelDownloadError.networkError("a") == ModelDownloadError.networkError("a"))
        #expect(ModelDownloadError.networkError("a") != ModelDownloadError.networkError("b"))
    }

    // MARK: - Init and State

    @MainActor
    @Test("ModelDownloader initializes with states for all catalog models")
    func initializesStates() {
        let downloader = ModelDownloader()
        for model in ModelCatalog.availableModels {
            let state = downloader.state(for: model.id)
            if model.isBundled {
                #expect(state == .downloaded)
            } else {
                // non-bundled models default to notDownloaded (unless already on disk)
                #expect(state == .notDownloaded || state == .downloaded)
            }
        }
    }

    @MainActor
    @Test("Bundled model always shows as downloaded")
    func bundledModelDownloaded() {
        let downloader = ModelDownloader()
        #expect(downloader.state(for: ModelCatalog.bundledModelID) == .downloaded)
    }

    @MainActor
    @Test("State for unknown model returns notDownloaded")
    func unknownModelState() {
        let downloader = ModelDownloader()
        #expect(downloader.state(for: "nonexistent-model") == .notDownloaded)
    }

    @MainActor
    @Test("Default models directory is in Application Support")
    func defaultModelsDirectory() {
        let dir = ModelDownloader.defaultModelsDirectory
        #expect(dir.path.contains("Application Support"))
        #expect(dir.path.contains("McWhisper"))
        #expect(dir.path.hasSuffix("Models"))
    }

    @Test("modelsDirectoryPath matches defaultModelsDirectory")
    func modelsDirectoryPathConsistency() {
        let path = ModelDownloader.modelsDirectoryPath
        #expect(path.contains("Application Support"))
        #expect(path.contains("McWhisper"))
        #expect(path.hasSuffix("Models"))
    }

    @MainActor
    @Test("Custom models directory is used")
    func customModelsDirectory() {
        let customDir = FileManager.default.temporaryDirectory.appendingPathComponent("ModelDownloaderTest-\(UUID())")
        let downloader = ModelDownloader(modelsDirectory: customDir)
        #expect(downloader.modelsDirectory == customDir)
    }

    @MainActor
    @Test("modelDirectory returns subdirectory of modelsDirectory")
    func modelDirectoryPath() {
        let downloader = ModelDownloader()
        let dir = downloader.modelDirectory(for: "openai_whisper-small")
        #expect(dir.path.hasSuffix("openai_whisper-small"))
        #expect(dir.path.contains("Models"))
    }

    @MainActor
    @Test("isModelDownloaded returns false for non-existent directory")
    func isModelDownloadedFalse() {
        let customDir = FileManager.default.temporaryDirectory.appendingPathComponent("ModelDownloaderTest-\(UUID())")
        let downloader = ModelDownloader(modelsDirectory: customDir)
        #expect(downloader.isModelDownloaded("openai_whisper-tiny") == false)
    }

    @MainActor
    @Test("isModelDownloaded returns true for existing directory")
    func isModelDownloadedTrue() throws {
        let customDir = FileManager.default.temporaryDirectory.appendingPathComponent("ModelDownloaderTest-\(UUID())")
        let modelDir = customDir.appendingPathComponent("test-model")
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: customDir) }

        let downloader = ModelDownloader(modelsDirectory: customDir)
        #expect(downloader.isModelDownloaded("test-model") == true)
    }

    @MainActor
    @Test("isModelDownloaded returns false for file (not directory)")
    func isModelDownloadedFile() throws {
        let customDir = FileManager.default.temporaryDirectory.appendingPathComponent("ModelDownloaderTest-\(UUID())")
        try FileManager.default.createDirectory(at: customDir, withIntermediateDirectories: true)
        let filePath = customDir.appendingPathComponent("test-model")
        FileManager.default.createFile(atPath: filePath.path, contents: Data("test".utf8))
        defer { try? FileManager.default.removeItem(at: customDir) }

        let downloader = ModelDownloader(modelsDirectory: customDir)
        #expect(downloader.isModelDownloaded("test-model") == false)
    }

    @MainActor
    @Test("refreshStates preserves active download state")
    func refreshPreservesDownloading() {
        let downloader = ModelDownloader()
        let modelID = ModelCatalog.downloadableModels.first!.id
        downloader.downloads[modelID] = .downloading(progress: 0.5)
        downloader.refreshStates()
        #expect(downloader.state(for: modelID) == .downloading(progress: 0.5))
    }

    // MARK: - Delete

    @MainActor
    @Test("deleteModel removes directory and sets state to notDownloaded")
    func deleteModelRemovesDir() throws {
        let customDir = FileManager.default.temporaryDirectory.appendingPathComponent("ModelDownloaderTest-\(UUID())")
        let modelDir = customDir.appendingPathComponent("test-model")
        try FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: customDir) }

        let downloader = ModelDownloader(modelsDirectory: customDir)
        downloader.downloads["test-model"] = .downloaded
        try downloader.deleteModel("test-model")

        #expect(downloader.state(for: "test-model") == .notDownloaded)
        #expect(FileManager.default.fileExists(atPath: modelDir.path) == false)
    }

    @MainActor
    @Test("deleteModel is safe for non-existent model")
    func deleteNonExistent() throws {
        let customDir = FileManager.default.temporaryDirectory.appendingPathComponent("ModelDownloaderTest-\(UUID())")
        let downloader = ModelDownloader(modelsDirectory: customDir)
        try downloader.deleteModel("nonexistent")
        #expect(downloader.state(for: "nonexistent") == .notDownloaded)
    }

    // MARK: - Remote File

    @Test("RemoteFile equality")
    func remoteFileEquality() {
        let a = ModelDownloader.RemoteFile(path: "model.bin", size: 100)
        let b = ModelDownloader.RemoteFile(path: "model.bin", size: 100)
        let c = ModelDownloader.RemoteFile(path: "other.bin", size: 200)
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - Repo ID

    @Test("Repo ID is argmaxinc/whisperkit-coreml")
    func repoID() {
        #expect(ModelDownloader.repoID == "argmaxinc/whisperkit-coreml")
    }

    // MARK: - Download Progress Delegate

    @Test("DownloadProgressDelegate reports progress")
    func progressDelegate() {
        var reported: Double?
        let delegate = DownloadProgressDelegate { progress in
            reported = progress
        }
        // Simulate a callback (totalBytesWritten / totalBytesExpectedToWrite)
        delegate.urlSession(
            URLSession.shared,
            downloadTask: URLSession.shared.downloadTask(with: URL(string: "https://example.com")!),
            didWriteData: 50,
            totalBytesWritten: 50,
            totalBytesExpectedToWrite: 100
        )
        #expect(reported == 0.5)
    }

    @Test("DownloadProgressDelegate ignores unknown total")
    func progressDelegateUnknownTotal() {
        var reported: Double?
        let delegate = DownloadProgressDelegate { progress in
            reported = progress
        }
        delegate.urlSession(
            URLSession.shared,
            downloadTask: URLSession.shared.downloadTask(with: URL(string: "https://example.com")!),
            didWriteData: 50,
            totalBytesWritten: 50,
            totalBytesExpectedToWrite: -1
        )
        #expect(reported == nil)
    }

    // MARK: - ObservableObject

    @MainActor
    @Test("ModelDownloader conforms to ObservableObject")
    func observableObject() {
        let downloader = ModelDownloader()
        _ = downloader.objectWillChange
    }
}
