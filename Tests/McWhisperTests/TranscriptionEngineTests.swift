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
}
