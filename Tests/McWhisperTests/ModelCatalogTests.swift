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

    // MARK: - Parakeet TDT and Qwen3-ASR model entries

    @Test("Qwen3-ASR 0.6B entry has correct metadata")
    func qwen3asr06bEntry() {
        let model = ModelCatalog.model(for: "qwen3-asr-0.6b")
        #expect(model != nil)
        #expect(model?.displayName == "Qwen3-ASR 0.6B")
        #expect(model?.sizeLabel == "~350 MB")
        #expect(model?.isBundled == false)
        #expect(model?.engine == .qwen3asr)
    }

    @Test("Qwen3-ASR 1.7B entry has correct metadata")
    func qwen3asr17bEntry() {
        let model = ModelCatalog.model(for: "qwen3-asr-1.7b")
        #expect(model != nil)
        #expect(model?.displayName == "Qwen3-ASR 1.7B")
        #expect(model?.sizeLabel == "~900 MB")
        #expect(model?.isBundled == false)
        #expect(model?.engine == .qwen3asr)
    }

    @Test("Parakeet TDT v3 entry has correct metadata")
    func parakeetTdtV3Entry() {
        let model = ModelCatalog.model(for: "parakeet-tdt-v3")
        #expect(model != nil)
        #expect(model?.displayName == "Parakeet TDT v3")
        #expect(model?.sizeLabel == "~315 MB")
        #expect(model?.isBundled == false)
        #expect(model?.engine == .qwen3asr)
    }

    // MARK: - HuggingFace model ID mapping

    @Test("huggingFaceModelID returns correct slug for Qwen3-ASR 0.6B")
    func hfSlugQwen3asr06b() {
        #expect(ModelCatalog.huggingFaceModelID(for: "qwen3-asr-0.6b") == "aufklarer/Qwen3-ASR-0.6B-MLX-4bit")
    }

    @Test("huggingFaceModelID returns correct slug for Qwen3-ASR 1.7B")
    func hfSlugQwen3asr17b() {
        #expect(ModelCatalog.huggingFaceModelID(for: "qwen3-asr-1.7b") == "aufklarer/Qwen3-ASR-1.7B-MLX-8bit")
    }

    @Test("huggingFaceModelID returns correct slug for Parakeet TDT v3")
    func hfSlugParakeetTdtV3() {
        #expect(ModelCatalog.huggingFaceModelID(for: "parakeet-tdt-v3") == "aufklarer/Parakeet-TDT-v3-CoreML-INT4")
    }

    @Test("huggingFaceModelID returns nil for WhisperKit models")
    func hfSlugWhisperKit() {
        #expect(ModelCatalog.huggingFaceModelID(for: "openai_whisper-base") == nil)
        #expect(ModelCatalog.huggingFaceModelID(for: "openai_whisper-large-v3") == nil)
    }

    @Test("huggingFaceModelID returns nil for unknown ID")
    func hfSlugUnknown() {
        #expect(ModelCatalog.huggingFaceModelID(for: "nonexistent") == nil)
    }

    @Test("All qwen3asr engine models have a HuggingFace slug")
    func allQwen3asrModelsHaveHfSlug() {
        let qwenModels = ModelCatalog.availableModels.filter { $0.engine == .qwen3asr }
        for model in qwenModels {
            #expect(ModelCatalog.huggingFaceModelID(for: model.id) != nil, "Missing HF slug for \(model.id)")
        }
    }
}
