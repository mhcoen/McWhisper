import Foundation
import WhisperKit

enum TranscriptionError: Error, Equatable {
    case modelNotLoaded
    case transcriptionFailed(String)
    case emptyResult
}

final class WhisperKitEngine: ObservableObject {
    @Published private(set) var modelState: ModelState = .unloaded
    private var whisperKit: WhisperKit?
    private var loadedModelID: String?

    /// Load the model specified in AppSettings asynchronously.
    func loadModel() async throws {
        let modelID = AppSettings.selectedModelID
        // Extract variant name from model ID (e.g. "openai_whisper-base" -> "base")
        let variant = modelVariant(from: modelID)

        modelState = .loading
        do {
            let kit = try await WhisperKit(
                WhisperKitConfig(model: variant, verbose: false, logLevel: .none)
            )
            whisperKit = kit
            loadedModelID = modelID
            modelState = .loaded
        } catch {
            modelState = .unloaded
            throw error
        }
    }

    /// Transcribe audio from a WAV file URL.
    /// Pass `language: nil` or `"auto"` for auto-detection.
    func transcribe(audioURL: URL, language: String?) async throws -> String {
        guard let kit = whisperKit, modelState == .loaded else {
            throw TranscriptionError.modelNotLoaded
        }

        let lang: String? = (language == nil || language == "auto") ? nil : language
        let options = DecodingOptions(
            language: lang,
            detectLanguage: lang == nil
        )

        let results: [TranscriptionResult] = try await kit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: options
        )

        let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            throw TranscriptionError.emptyResult
        }
        return text
    }

    /// Transcribe audio with real-time partial results via WhisperKit's decode callback.
    /// Calls `onPartial` with each intermediate text string during decoding.
    /// Returns the final transcribed text.
    func transcribeStreaming(
        audioURL: URL,
        language: String?,
        onPartial: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        guard let kit = whisperKit, modelState == .loaded else {
            throw TranscriptionError.modelNotLoaded
        }

        let lang: String? = (language == nil || language == "auto") ? nil : language
        let options = DecodingOptions(
            language: lang,
            detectLanguage: lang == nil
        )

        let callback: ((TranscriptionProgress) -> Bool?) = { progress in
            let partial = progress.text.trimmingCharacters(in: .whitespaces)
            if !partial.isEmpty {
                onPartial(partial)
            }
            return true
        }

        let results: [TranscriptionResult] = try await kit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: options,
            callback: callback
        )

        let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            throw TranscriptionError.emptyResult
        }
        return text
    }

    /// Whether the currently loaded model matches AppSettings.
    var isModelCurrent: Bool {
        loadedModelID == AppSettings.selectedModelID && modelState == .loaded
    }

    /// Extract the whisper model variant from our model ID string.
    /// e.g. "openai_whisper-base" -> "base", "openai_whisper-large-v3" -> "large-v3"
    func modelVariant(from modelID: String) -> String {
        if let range = modelID.range(of: "whisper-") {
            return String(modelID[range.upperBound...])
        }
        return modelID
    }
}
