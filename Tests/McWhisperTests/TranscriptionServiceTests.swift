import Foundation
import Testing
@testable import McWhisper

@Suite("WhisperKitEngine")
struct WhisperKitEngineTests {

    @Test("Initial state is unloaded with no model")
    func initialState() {
        let engine = WhisperKitEngine()
        #expect(engine.modelState == .unloaded)
        #expect(engine.isModelCurrent == false)
    }

    @Test("modelVariant extracts variant from standard model IDs")
    func modelVariantExtraction() {
        let engine = WhisperKitEngine()
        #expect(engine.modelVariant(from: "openai_whisper-base") == "base")
        #expect(engine.modelVariant(from: "openai_whisper-large-v3") == "large-v3")
        #expect(engine.modelVariant(from: "openai_whisper-tiny.en") == "tiny.en")
        #expect(engine.modelVariant(from: "openai_whisper-small") == "small")
    }

    @Test("modelVariant returns raw ID when no whisper- prefix found")
    func modelVariantFallback() {
        let engine = WhisperKitEngine()
        #expect(engine.modelVariant(from: "custom-model") == "custom-model")
        #expect(engine.modelVariant(from: "") == "")
    }

    @Test("transcribe throws modelNotLoaded when no model is loaded")
    func transcribeWithoutModel() async {
        let engine = WhisperKitEngine()
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        do {
            _ = try await engine.transcribe(audioURL: url, language: nil)
            Issue.record("Expected TranscriptionError.modelNotLoaded")
        } catch let error as TranscriptionError {
            #expect(error == .modelNotLoaded)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("TranscriptionError cases are equatable")
    func errorEquality() {
        #expect(TranscriptionError.modelNotLoaded == TranscriptionError.modelNotLoaded)
        #expect(TranscriptionError.emptyResult == TranscriptionError.emptyResult)
        #expect(TranscriptionError.transcriptionFailed("a") == TranscriptionError.transcriptionFailed("a"))
        #expect(TranscriptionError.transcriptionFailed("a") != TranscriptionError.transcriptionFailed("b"))
        #expect(TranscriptionError.modelNotLoaded != TranscriptionError.emptyResult)
    }

    @Test("transcribeStreaming throws modelNotLoaded when no model is loaded")
    func transcribeStreamingWithoutModel() async {
        let engine = WhisperKitEngine()
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        do {
            _ = try await engine.transcribeStreaming(audioURL: url, language: nil) { _ in }
            Issue.record("Expected TranscriptionError.modelNotLoaded")
        } catch let error as TranscriptionError {
            #expect(error == .modelNotLoaded)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("transcribeStreaming throws modelNotLoaded with auto language")
    func transcribeStreamingAutoLanguage() async {
        let engine = WhisperKitEngine()
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        do {
            _ = try await engine.transcribeStreaming(audioURL: url, language: "auto") { _ in }
            Issue.record("Expected TranscriptionError.modelNotLoaded")
        } catch let error as TranscriptionError {
            #expect(error == .modelNotLoaded)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("ObservableObject conformance")
    func observableConformance() {
        let engine = WhisperKitEngine()
        // Verify objectWillChange publisher exists (ObservableObject conformance)
        _ = engine.objectWillChange
    }
}
