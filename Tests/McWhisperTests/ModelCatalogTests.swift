import Testing
@testable import McWhisper

@Suite("ModelCatalog")
struct ModelCatalogTests {

    @Test("Bundled model ID matches AppSettings default")
    func bundledModelIDMatchesDefault() {
        #expect(ModelCatalog.bundledModelID == AppSettings.defaultModelID)
        #expect(ModelCatalog.bundledModelID == "openai_whisper-base")
    }

    @Test("Exactly one model is marked as bundled")
    func exactlyOneBundled() {
        let bundledModels = ModelCatalog.availableModels.filter(\.isBundled)
        #expect(bundledModels.count == 1)
        #expect(bundledModels[0].id == ModelCatalog.bundledModelID)
    }

    @Test("Bundled model convenience property returns correct model")
    func bundledModelProperty() {
        let model = ModelCatalog.bundledModel
        #expect(model.id == "openai_whisper-base")
        #expect(model.isBundled == true)
        #expect(model.displayName == "Base")
    }

    @Test("Downloadable models exclude the bundled model")
    func downloadableModelsExcludeBundled() {
        let downloadable = ModelCatalog.downloadableModels
        #expect(downloadable.allSatisfy { !$0.isBundled })
        #expect(downloadable.count == ModelCatalog.availableModels.count - 1)
    }

    @Test("All model IDs are unique")
    func uniqueIDs() {
        let ids = ModelCatalog.availableModels.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Lookup by ID returns matching model")
    func lookupByID() {
        let model = ModelCatalog.model(for: "openai_whisper-small")
        #expect(model != nil)
        #expect(model?.displayName == "Small")
    }

    @Test("Lookup by unknown ID returns nil")
    func lookupUnknownID() {
        #expect(ModelCatalog.model(for: "nonexistent") == nil)
    }

    @Test("Every model has a non-empty display name and size label")
    func modelsHaveMetadata() {
        for model in ModelCatalog.availableModels {
            #expect(!model.displayName.isEmpty)
            #expect(!model.sizeLabel.isEmpty)
        }
    }

    @Test("ModelInfo equatable conformance")
    func modelInfoEquatable() {
        let a = ModelInfo(id: "x", displayName: "X", sizeLabel: "1 MB", isBundled: false)
        let b = ModelInfo(id: "x", displayName: "X", sizeLabel: "1 MB", isBundled: false)
        let c = ModelInfo(id: "y", displayName: "Y", sizeLabel: "2 MB", isBundled: true)
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - ModelEngine tests

    @Test("ModelEngine has two cases")
    func modelEngineCases() {
        let all = ModelEngine.allCases
        #expect(all.count == 2)
        #expect(all.contains(.whisperKit))
        #expect(all.contains(.qwen3asr))
    }

    @Test("ModelEngine raw values")
    func modelEngineRawValues() {
        #expect(ModelEngine.whisperKit.rawValue == "whisperKit")
        #expect(ModelEngine.qwen3asr.rawValue == "qwen3asr")
    }

    @Test("ModelEngine equatable conformance")
    func modelEngineEquatable() {
        #expect(ModelEngine.whisperKit == ModelEngine.whisperKit)
        #expect(ModelEngine.whisperKit != ModelEngine.qwen3asr)
    }

    @Test("Bundled model uses whisperKit engine")
    func bundledModelEngine() {
        #expect(ModelCatalog.bundledModel.engine == .whisperKit)
    }

    @Test("Every model has an engine tag")
    func allModelsHaveEngine() {
        for model in ModelCatalog.availableModels {
            #expect(ModelEngine.allCases.contains(model.engine))
        }
    }

    @Test("WhisperKit models use whisperKit engine")
    func whisperKitModelsEngine() {
        let whisperModels = ModelCatalog.availableModels.filter { $0.id.hasPrefix("openai_whisper-") }
        #expect(!whisperModels.isEmpty)
        for model in whisperModels {
            #expect(model.engine == .whisperKit)
        }
    }

    @Test("Qwen3-ASR and Parakeet models use qwen3asr engine")
    func qwen3asrModelsEngine() {
        let qwenModels = ModelCatalog.availableModels.filter { $0.engine == .qwen3asr }
        #expect(!qwenModels.isEmpty)
        for model in qwenModels {
            #expect(!model.id.hasPrefix("openai_whisper-"))
        }
    }

    @Test("ModelInfo default engine is whisperKit")
    func modelInfoDefaultEngine() {
        let model = ModelInfo(id: "test", displayName: "Test", sizeLabel: "1 MB", isBundled: false)
        #expect(model.engine == .whisperKit)
    }

    @Test("ModelInfo with explicit qwen3asr engine")
    func modelInfoExplicitEngine() {
        let model = ModelInfo(id: "test", displayName: "Test", sizeLabel: "1 MB", isBundled: false, engine: .qwen3asr)
        #expect(model.engine == .qwen3asr)
    }

    @Test("ModelInfo engine affects equality")
    func modelInfoEngineEquality() {
        let a = ModelInfo(id: "x", displayName: "X", sizeLabel: "1 MB", isBundled: false, engine: .whisperKit)
        let b = ModelInfo(id: "x", displayName: "X", sizeLabel: "1 MB", isBundled: false, engine: .qwen3asr)
        #expect(a != b)
    }
}
