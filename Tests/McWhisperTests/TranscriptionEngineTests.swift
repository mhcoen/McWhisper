import Foundation
import Testing
@testable import McWhisper

@Suite("ModelState")
struct ModelStateTests {

    @Test("ModelState has three cases")
    func cases() {
        let states: [ModelState] = [.unloaded, .loading, .loaded]
        #expect(states.count == 3)
    }

    @Test("ModelState is equatable")
    func equatable() {
        #expect(ModelState.unloaded == ModelState.unloaded)
        #expect(ModelState.loading == ModelState.loading)
        #expect(ModelState.loaded == ModelState.loaded)
        #expect(ModelState.unloaded != ModelState.loading)
        #expect(ModelState.unloaded != ModelState.loaded)
        #expect(ModelState.loading != ModelState.loaded)
    }
}

@Suite("TranscriptionEngine protocol")
struct TranscriptionEngineProtocolTests {

    @Test("WhisperKitEngine conforms to TranscriptionEngine")
    func whisperKitConformance() {
        let engine: any TranscriptionEngine = WhisperKitEngine()
        #expect(engine.modelState == .unloaded)
        #expect(engine.isLoaded == false)
        #expect(engine.isModelCurrent == false)
    }

    @Test("Qwen3ASREngine conforms to TranscriptionEngine")
    func qwen3Conformance() {
        let engine: any TranscriptionEngine = Qwen3ASREngine()
        #expect(engine.modelState == .unloaded)
        #expect(engine.isLoaded == false)
        #expect(engine.isModelCurrent == false)
    }

    @Test("isLoaded reflects modelState for WhisperKitEngine")
    func whisperKitIsLoaded() {
        let engine = WhisperKitEngine()
        #expect(engine.modelState == .unloaded)
        #expect(engine.isLoaded == false)
    }

    @Test("isLoaded reflects modelState for Qwen3ASREngine")
    func qwen3IsLoaded() {
        let engine = Qwen3ASREngine()
        #expect(engine.modelState == .unloaded)
        #expect(engine.isLoaded == false)
    }

    @Test("Protocol requires AnyObject (class-only)")
    func classOnly() {
        let engine: any TranscriptionEngine = WhisperKitEngine()
        #expect(engine === engine)
    }

    @Test("Both engines are distinct class instances")
    func distinctInstances() {
        let a: any TranscriptionEngine = WhisperKitEngine()
        let b: any TranscriptionEngine = WhisperKitEngine()
        #expect(a !== b)
    }
}

@Suite("EngineTag lookup")
struct EngineTagTests {

    @Test("All WhisperKit models have whisperKit engine tag")
    func whisperKitEngineTags() {
        let whisperModels = ModelCatalog.availableModels.filter { $0.id.hasPrefix("openai_whisper") }
        #expect(!whisperModels.isEmpty)
        for model in whisperModels {
            #expect(model.engine == .whisperKit, "Expected whisperKit engine for \(model.id)")
        }
    }

    @Test("All Qwen3-ASR models have qwen3asr engine tag")
    func qwen3asrEngineTags() {
        let qwen3Models = ModelCatalog.availableModels.filter { $0.id.hasPrefix("qwen3-asr") }
        #expect(!qwen3Models.isEmpty)
        for model in qwen3Models {
            #expect(model.engine == .qwen3asr, "Expected qwen3asr engine for \(model.id)")
        }
    }

    @Test("Parakeet models have qwen3asr engine tag")
    func parakeetEngineTags() {
        let parakeetModels = ModelCatalog.availableModels.filter { $0.id.hasPrefix("parakeet") }
        #expect(!parakeetModels.isEmpty)
        for model in parakeetModels {
            #expect(model.engine == .qwen3asr, "Expected qwen3asr engine for \(model.id)")
        }
    }

    @Test("Engine tag lookup works for every catalog model")
    func allModelsHaveEngineTag() {
        for model in ModelCatalog.availableModels {
            let engine = model.engine
            #expect(ModelEngine.allCases.contains(engine), "Unknown engine for \(model.id)")
        }
    }

    @Test("EngineKind lookup for qwen3 catalog IDs")
    func engineKindQwen3() {
        #expect(Qwen3ASREngine.engineKind(for: "qwen3-asr-0.6b") == .qwen3asr)
        #expect(Qwen3ASREngine.engineKind(for: "qwen3-asr-1.7b") == .qwen3asr)
    }

    @Test("EngineKind lookup for parakeet catalog IDs")
    func engineKindParakeet() {
        #expect(Qwen3ASREngine.engineKind(for: "parakeet-tdt-v3") == .parakeet)
    }

    @Test("EngineKind defaults to qwen3asr for unknown IDs")
    func engineKindUnknown() {
        #expect(Qwen3ASREngine.engineKind(for: "unknown-model") == .qwen3asr)
    }

    @Test("Bundled model has whisperKit engine")
    func bundledModelEngine() {
        #expect(ModelCatalog.bundledModel.engine == .whisperKit)
    }
}

@Suite("Qwen3ASREngine initial state")
struct Qwen3ASREngineInitTests {

    @Test("Init does not crash and sets unloaded state")
    func initNoCrash() {
        let engine = Qwen3ASREngine()
        #expect(engine.modelState == .unloaded)
    }

    @Test("isModelCurrent is false on init")
    func isModelCurrentFalse() {
        let engine = Qwen3ASREngine()
        #expect(engine.isModelCurrent == false)
    }

    @Test("isLoaded is false on init")
    func isLoadedFalse() {
        let engine = Qwen3ASREngine()
        #expect(engine.isLoaded == false)
    }
}
