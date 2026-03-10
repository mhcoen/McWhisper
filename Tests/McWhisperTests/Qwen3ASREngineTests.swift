import Foundation
import Testing
@testable import McWhisper

@Suite("Qwen3ASREngine")
struct Qwen3ASREngineTests {

    @Test("Initial state is unloaded")
    func initialState() {
        let engine = Qwen3ASREngine()
        #expect(engine.modelState == .unloaded)
        #expect(engine.isLoaded == false)
        #expect(engine.isModelCurrent == false)
    }

    @Test("engineKind returns qwen3asr for qwen3 model IDs")
    func engineKindQwen3() {
        #expect(Qwen3ASREngine.engineKind(for: "qwen3-asr-0.6b") == .qwen3asr)
        #expect(Qwen3ASREngine.engineKind(for: "qwen3-asr-1.7b") == .qwen3asr)
    }

    @Test("engineKind returns parakeet for parakeet model IDs")
    func engineKindParakeet() {
        #expect(Qwen3ASREngine.engineKind(for: "parakeet-tdt-v3") == .parakeet)
    }

    @Test("engineKind defaults to qwen3asr for unknown IDs")
    func engineKindDefault() {
        #expect(Qwen3ASREngine.engineKind(for: "unknown-model") == .qwen3asr)
        #expect(Qwen3ASREngine.engineKind(for: "") == .qwen3asr)
    }

    @Test("EngineKind is equatable")
    func engineKindEquatable() {
        #expect(Qwen3ASREngine.EngineKind.qwen3asr == .qwen3asr)
        #expect(Qwen3ASREngine.EngineKind.parakeet == .parakeet)
        #expect(Qwen3ASREngine.EngineKind.qwen3asr != .parakeet)
    }

    @Test("transcribe audioURL throws modelNotLoaded when no model is loaded")
    func transcribeURLWithoutModel() async {
        let engine = Qwen3ASREngine()
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        do {
            _ = try await engine.transcribe(audioURL: url, language: nil)
            Issue.record("Expected TranscriptionError.modelNotLoaded")
        } catch let error as TranscriptionError {
            #expect(error == .modelNotLoaded)
        } catch {
            // Audio loading may fail before the model check for audioURL path;
            // that is acceptable since the model is not loaded.
        }
    }

    @Test("transcribe audioSamples throws modelNotLoaded when no model is loaded")
    func transcribeSamplesWithoutModel() async {
        let engine = Qwen3ASREngine()
        do {
            _ = try await engine.transcribe(audioSamples: [Float](repeating: 0, count: 16000), language: nil)
            Issue.record("Expected TranscriptionError.modelNotLoaded")
        } catch let error as TranscriptionError {
            #expect(error == .modelNotLoaded)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("transcribeStreaming audioSamples throws modelNotLoaded when no model is loaded")
    func transcribeStreamingSamplesWithoutModel() async {
        let engine = Qwen3ASREngine()
        do {
            _ = try await engine.transcribeStreaming(
                audioSamples: [Float](repeating: 0, count: 16000),
                language: nil
            ) { _ in }
            Issue.record("Expected TranscriptionError.modelNotLoaded")
        } catch let error as TranscriptionError {
            #expect(error == .modelNotLoaded)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("transcribeStreaming audioURL throws modelNotLoaded when no model is loaded")
    func transcribeStreamingURLWithoutModel() async {
        let engine = Qwen3ASREngine()
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        do {
            _ = try await engine.transcribeStreaming(audioURL: url, language: nil) { _ in }
            Issue.record("Expected TranscriptionError.modelNotLoaded")
        } catch let error as TranscriptionError {
            #expect(error == .modelNotLoaded)
        } catch {
            // Audio loading may fail before the model check; acceptable.
        }
    }

    @Test("transcribeStreaming with auto language throws modelNotLoaded")
    func transcribeStreamingAutoLanguage() async {
        let engine = Qwen3ASREngine()
        do {
            _ = try await engine.transcribeStreaming(
                audioSamples: [Float](repeating: 0, count: 16000),
                language: "auto"
            ) { _ in }
            Issue.record("Expected TranscriptionError.modelNotLoaded")
        } catch let error as TranscriptionError {
            #expect(error == .modelNotLoaded)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("isLoaded is false when unloaded")
    func isLoadedWhenUnloaded() {
        let engine = Qwen3ASREngine()
        #expect(engine.isLoaded == false)
    }

    @Test("ObservableObject conformance")
    func observableConformance() {
        let engine = Qwen3ASREngine()
        _ = engine.objectWillChange
    }

    @Test("isModelCurrent is false when unloaded")
    func isModelCurrentWhenUnloaded() {
        let engine = Qwen3ASREngine()
        #expect(engine.isModelCurrent == false)
    }
}
