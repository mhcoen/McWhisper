import Foundation

struct TranscriptionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let rawText: String
    let processedText: String
    let mode: TranscriptionMode
    let modelID: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: TimeInterval,
        rawText: String,
        processedText: String,
        mode: TranscriptionMode,
        modelID: String
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.rawText = rawText
        self.processedText = processedText
        self.mode = mode
        self.modelID = modelID
    }
}
