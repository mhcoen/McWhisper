import Foundation

/// Lifecycle state for a transcription engine's model.
enum ModelState: Equatable {
    case unloaded
    case loading
    case loaded
}

/// Common interface for local speech-to-text engines (WhisperKit, Qwen3-ASR, Parakeet TDT).
protocol TranscriptionEngine: AnyObject {
    /// Current model lifecycle state.
    var modelState: ModelState { get }

    /// Whether the engine has a model loaded and ready for transcription.
    var isLoaded: Bool { get }

    /// Whether the currently loaded model matches AppSettings.selectedModelID.
    var isModelCurrent: Bool { get }

    func loadModel() async throws
    func transcribe(audioURL: URL, language: String?) async throws -> String
    func transcribe(audioSamples: [Float], language: String?) async throws -> String
    func transcribeStreaming(
        audioURL: URL,
        language: String?,
        onPartial: @escaping @Sendable (String) -> Void
    ) async throws -> String
    func transcribeStreaming(
        audioSamples: [Float],
        language: String?,
        onPartial: @escaping @Sendable (String) -> Void
    ) async throws -> String
}
