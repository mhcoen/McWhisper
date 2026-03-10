import Foundation
import Qwen3ASR
import ParakeetASR

/// Transcription engine wrapping qwen3-asr-swift for Qwen3-ASR and Parakeet TDT models.
final class Qwen3ASREngine: ObservableObject, TranscriptionEngine {
    enum EngineKind: Equatable {
        case qwen3asr
        case parakeet
    }

    @Published private(set) var engineState: EngineState = .unloaded

    enum EngineState: Equatable {
        case unloaded
        case loading
        case loaded
    }

    private var qwen3Model: Qwen3ASRModel?
    private var parakeetModel: ParakeetASRModel?
    private var loadedModelID: String?

    var isLoaded: Bool { engineState == .loaded }

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

        engineState = .loading
        do {
            let kind = Self.engineKind(for: modelID)
            switch kind {
            case .qwen3asr:
                parakeetModel = nil
                let model = try await Qwen3ASRModel.fromPretrained(modelId: hfID)
                qwen3Model = model
            case .parakeet:
                qwen3Model = nil
                let model = try await ParakeetASRModel.fromPretrained(modelId: hfID)
                parakeetModel = model
            }
            loadedModelID = modelID
            engineState = .loaded
        } catch {
            engineState = .unloaded
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
        // qwen3-asr-swift's basic transcribe is synchronous; no streaming callback.
        // Run on a background thread and deliver the result as a single partial + final.
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
        onPartial(trimmed)
        return trimmed
    }

    // MARK: - Audio loading

    private func loadAudioSamples(from url: URL) throws -> [Float] {
        try AudioEngine.loadWhisperSamples(from: url)
    }
}
