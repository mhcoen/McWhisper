import Foundation
import Qwen3ASR
import ParakeetASR
import SpeechVAD

/// Transcription engine wrapping qwen3-asr-swift for Qwen3-ASR and Parakeet TDT models.
final class Qwen3ASREngine: ObservableObject, TranscriptionEngine {
    enum EngineKind: Equatable {
        case qwen3asr
        case parakeet
    }

    @Published private(set) var modelState: ModelState = .unloaded

    private var qwen3Model: Qwen3ASRModel?
    private var parakeetModel: ParakeetASRModel?
    private var streamingASR: StreamingASR?
    private var loadedModelID: String?

    var isLoaded: Bool { modelState == .loaded }

    var isModelCurrent: Bool {
        loadedModelID == AppSettings.selectedModelID && isLoaded
    }

    /// Determine engine kind from a catalog model ID.
    static func engineKind(for modelID: String) -> EngineKind {
        if modelID.hasPrefix("parakeet") {
            return .parakeet
        }
        return .qwen3asr
    }

    func loadModel() async throws {
        let modelID = AppSettings.selectedModelID
        guard let hfID = ModelCatalog.huggingFaceModelID(for: modelID) else {
            throw TranscriptionError.modelNotLoaded
        }

        modelState = .loading
        do {
            let kind = Self.engineKind(for: modelID)
            switch kind {
            case .qwen3asr:
                parakeetModel = nil
                streamingASR = nil
                let model = try await Qwen3ASRModel.fromPretrained(modelId: hfID)
                qwen3Model = model
                // Load VAD model for streaming support
                let vadModel = try await SileroVADModel.fromPretrained()
                streamingASR = StreamingASR(asrModel: model, vadModel: vadModel)
            case .parakeet:
                qwen3Model = nil
                streamingASR = nil
                let model = try await ParakeetASRModel.fromPretrained(modelId: hfID)
                try model.warmUp()
                parakeetModel = model
            }
            loadedModelID = modelID
            modelState = .loaded
        } catch {
            modelState = .unloaded
            throw error
        }
    }

    func transcribe(audioURL: URL, language: String?) async throws -> String {
        let samples = try loadAudioSamples(from: audioURL)
        return try await transcribe(audioSamples: samples, language: language)
    }

    func transcribe(audioSamples: [Float], language: String?) async throws -> String {
        guard isLoaded else { throw TranscriptionError.modelNotLoaded }

        let lang: String? = (language == nil || language == "auto") ? nil : language
        let text: String

        if let model = qwen3Model {
            text = model.transcribe(audio: audioSamples, sampleRate: 16000, language: lang)
        } else if let model = parakeetModel {
            text = try model.transcribeAudio(audioSamples, sampleRate: 16000, language: lang)
        } else {
            throw TranscriptionError.modelNotLoaded
        }

        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw TranscriptionError.emptyResult }
        return trimmed
    }

    func transcribeStreaming(
        audioURL: URL,
        language: String?,
        onPartial: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let samples = try loadAudioSamples(from: audioURL)
        return try await transcribeStreaming(audioSamples: samples, language: language, onPartial: onPartial)
    }

    func transcribeStreaming(
        audioSamples: [Float],
        language: String?,
        onPartial: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        guard isLoaded else { throw TranscriptionError.modelNotLoaded }

        // Use StreamingASR with VAD for Qwen3 models (real partial results).
        if let streaming = streamingASR {
            let lang: String? = (language == nil || language == "auto") ? nil : language
            let config = StreamingASRConfig(
                language: lang,
                emitPartialResults: true,
                partialResultInterval: 0.5
            )

            let stream = streaming.transcribeStream(
                audio: audioSamples,
                sampleRate: 16000,
                config: config
            )

            var finalText = ""
            for try await segment in stream {
                let partial = segment.text.trimmingCharacters(in: .whitespaces)
                if !partial.isEmpty {
                    onPartial(partial)
                    if segment.isFinal {
                        if !finalText.isEmpty { finalText += " " }
                        finalText += partial
                    }
                }
            }

            let trimmed = finalText.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                return trimmed
            }
            // Fall back to batch if streaming yielded no final segments.
        }

        // Parakeet or fallback: batch transcription with single partial callback.
        let result = try await transcribe(audioSamples: audioSamples, language: language)
        onPartial(result)
        return result
    }

    // MARK: - Audio loading

    private func loadAudioSamples(from url: URL) throws -> [Float] {
        try AudioEngine.loadWhisperSamples(from: url)
    }
}
