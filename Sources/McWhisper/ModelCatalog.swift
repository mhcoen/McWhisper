import Foundation

struct ModelInfo: Identifiable, Equatable {
    let id: String
    let displayName: String
    let sizeLabel: String
    let isBundled: Bool
}

enum ModelCatalog {
    static let bundledModelID = AppSettings.defaultModelID

    static let availableModels: [ModelInfo] = [
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
}
