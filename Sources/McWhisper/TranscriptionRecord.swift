import Foundation

struct TranscriptionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let rawText: String
    let processedText: String
    let mode: TranscriptionMode
    let modelID: String
    let audioFileName: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: TimeInterval,
        rawText: String,
        processedText: String,
        mode: TranscriptionMode,
        modelID: String,
        audioFileName: String? = nil
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.rawText = rawText
        self.processedText = processedText
        self.mode = mode
        self.modelID = modelID
        self.audioFileName = audioFileName
    }

    var audioFileURL: URL? {
        guard let audioFileName else { return nil }
        let dir = HistoryStore.defaultDirectory.appendingPathComponent("Audio", isDirectory: true)
        return dir.appendingPathComponent(audioFileName)
    }

    var hasAudioFile: Bool {
        guard let url = audioFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}
