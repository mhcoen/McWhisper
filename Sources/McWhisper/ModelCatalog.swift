import Foundation

enum ModelEngine: String, Equatable, CaseIterable {
    case whisperKit
    case qwen3asr
}

enum EngineAvailability {
    /// Whether the current Mac has Apple Silicon (arm64).
    static let isAppleSilicon: Bool = {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }()

    /// Returns true if the given engine can run on this hardware.
    static func isAvailable(_ engine: ModelEngine) -> Bool {
        switch engine {
        case .whisperKit:
            return true  // WhisperKit works on both Intel (via CoreML CPU/GPU) and Apple Silicon
        case .qwen3asr:
            return isAppleSilicon  // qwen3-asr-swift requires Apple Silicon Neural Engine
        }
    }

    /// Human-readable reason why the engine is unavailable, or nil if available.
    static func unavailabilityReason(_ engine: ModelEngine) -> String? {
        guard !isAvailable(engine) else { return nil }
        switch engine {
        case .qwen3asr:
            return "Requires Apple Silicon"
        case .whisperKit:
            return nil
        }
    }
}

struct ModelInfo: Identifiable, Equatable {
    let id: String
    let displayName: String
    let sizeLabel: String
    let isBundled: Bool
    let engine: ModelEngine

    init(id: String, displayName: String, sizeLabel: String, isBundled: Bool, engine: ModelEngine = .whisperKit) {
        self.id = id
        self.displayName = displayName
        self.sizeLabel = sizeLabel
        self.isBundled = isBundled
        self.engine = engine
    }
}

enum ModelCatalog {
    static let bundledModelID = AppSettings.defaultModelID

    static let availableModels: [ModelInfo] = [
        // WhisperKit models
        ModelInfo(id: "openai_whisper-tiny", displayName: "Tiny", sizeLabel: "~75 MB", isBundled: false),
        ModelInfo(id: "openai_whisper-tiny.en", displayName: "Tiny (English)", sizeLabel: "~75 MB", isBundled: false),
        ModelInfo(id: "openai_whisper-base", displayName: "Base", sizeLabel: "~140 MB", isBundled: true),
        ModelInfo(id: "openai_whisper-base.en", displayName: "Base (English)", sizeLabel: "~140 MB", isBundled: false),
        ModelInfo(id: "openai_whisper-small", displayName: "Small", sizeLabel: "~460 MB", isBundled: false),
        ModelInfo(id: "openai_whisper-small.en", displayName: "Small (English)", sizeLabel: "~460 MB", isBundled: false),
        ModelInfo(id: "openai_whisper-medium", displayName: "Medium", sizeLabel: "~1.5 GB", isBundled: false),
        ModelInfo(id: "openai_whisper-medium.en", displayName: "Medium (English)", sizeLabel: "~1.5 GB", isBundled: false),
        ModelInfo(id: "openai_whisper-large-v3", displayName: "Large v3", sizeLabel: "~3 GB", isBundled: false),
        ModelInfo(id: "openai_whisper-large-v3-turbo", displayName: "Large v3 Turbo", sizeLabel: "~1.6 GB", isBundled: false),
        // Qwen3-ASR models (via qwen3-asr-swift)
        ModelInfo(id: "qwen3-asr-0.6b", displayName: "Qwen3-ASR 0.6B", sizeLabel: "~350 MB", isBundled: false, engine: .qwen3asr),
        ModelInfo(id: "qwen3-asr-1.7b", displayName: "Qwen3-ASR 1.7B", sizeLabel: "~900 MB", isBundled: false, engine: .qwen3asr),
        // Parakeet TDT model (via qwen3-asr-swift, runs on Neural Engine)
        ModelInfo(id: "parakeet-tdt-v3", displayName: "Parakeet TDT v3", sizeLabel: "~315 MB", isBundled: false, engine: .qwen3asr),
    ]

    static func model(for id: String) -> ModelInfo? {
        availableModels.first { $0.id == id }
    }

    static var bundledModel: ModelInfo {
        availableModels.first { $0.isBundled }!
    }

    static var downloadableModels: [ModelInfo] {
        availableModels.filter { !$0.isBundled }
    }

    /// HuggingFace model ID used by qwen3-asr-swift's `fromPretrained` for each catalog entry.
    static func huggingFaceModelID(for catalogID: String) -> String? {
        switch catalogID {
        case "qwen3-asr-0.6b": return "aufklarer/Qwen3-ASR-0.6B-MLX-4bit"
        case "qwen3-asr-1.7b": return "aufklarer/Qwen3-ASR-1.7B-MLX-8bit"
        case "parakeet-tdt-v3": return "aufklarer/Parakeet-TDT-v3-CoreML-INT4"
        default: return nil
        }
    }
}
