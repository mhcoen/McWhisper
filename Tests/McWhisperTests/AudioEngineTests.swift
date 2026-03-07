import Testing
import Foundation
import AVFoundation
@testable import McWhisper

@Suite("AudioEngine")
struct AudioEngineTests {

    @Test("Initial state is not recording")
    func initialState() {
        let engine = AudioEngine()
        #expect(!engine.isRecording)
    }

    @Test("stopRecording throws when not recording")
    func stopWithoutStart() {
        let engine = AudioEngine()
        #expect(throws: AudioEngineError.notRecording) {
            try engine.stopRecording()
        }
    }

    @Test("AudioEngineError cases are distinct")
    func errorEquality() {
        #expect(AudioEngineError.alreadyRecording == AudioEngineError.alreadyRecording)
        #expect(AudioEngineError.notRecording == AudioEngineError.notRecording)
        #expect(AudioEngineError.noInputAvailable == AudioEngineError.noInputAvailable)
        #expect(AudioEngineError.alreadyRecording != AudioEngineError.notRecording)
    }

    @Test("Whisper format is 16 kHz mono 16-bit")
    func whisperFormat() {
        let fmt = AudioEngine.whisperFormat
        #expect(fmt.sampleRate == 16000)
        #expect(fmt.channelCount == 1)
        #expect(fmt.commonFormat == .pcmFormatInt16)
        #expect(fmt.isInterleaved)
    }

    @Test("Whisper format settings produce valid AVAudioFile")
    func whisperFormatWritable() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        let file = try AVAudioFile(
            forWriting: url,
            settings: AudioEngine.whisperFormat.settings
        )
        #expect(file.fileFormat.sampleRate == 16000)
        #expect(file.fileFormat.channelCount == 1)
        try? FileManager.default.removeItem(at: url)
    }

    @Test("audioLevel defaults to zero")
    func audioLevelDefault() {
        let engine = AudioEngine()
        #expect(engine.audioLevel == 0.0)
    }

    @Test("audioLevel is zero when not recording")
    func audioLevelNotRecording() {
        let engine = AudioEngine()
        #expect(!engine.isRecording)
        #expect(engine.audioLevel == 0.0)
    }

    @Test("AudioEngine conforms to ObservableObject")
    func observableConformance() {
        let engine = AudioEngine()
        // objectWillChange exists on ObservableObject conformers
        _ = engine.objectWillChange
    }

    @Test("isRecording is observable via @Published")
    func isRecordingPublished() {
        let engine = AudioEngine()
        // $isRecording publisher exists — confirms @Published annotation
        _ = engine.$isRecording
    }

    @Test("speechDetected defaults to false")
    func speechDetectedDefault() {
        let engine = AudioEngine()
        #expect(engine.speechDetected == false)
    }

    @Test("VAD frame duration is 20 ms")
    func vadFrameDuration() {
        #expect(AudioEngine.vadFrameDuration == 0.020)
    }

    @Test("VAD threshold is positive and reasonable")
    func vadThreshold() {
        #expect(AudioEngine.vadThreshold > 0)
        #expect(AudioEngine.vadThreshold < 1)
    }

    @Test("VAD hangover duration is positive")
    func vadHangoverDuration() {
        #expect(AudioEngine.vadHangoverDuration > 0)
    }

    @Test("engineStartFailed and fileCreationFailed carry messages")
    func errorMessages() {
        let e1 = AudioEngineError.engineStartFailed("boom")
        let e2 = AudioEngineError.fileCreationFailed("bad path")
        #expect(e1 == AudioEngineError.engineStartFailed("boom"))
        #expect(e1 != AudioEngineError.engineStartFailed("other"))
        #expect(e2 == AudioEngineError.fileCreationFailed("bad path"))
        #expect(e1 != AudioEngineError.alreadyRecording)
    }

    // MARK: - Silence trimming tests

    /// Helper: create a 16 kHz mono Int16 WAV file from Float sample values.
    /// AVAudioFile handles float→Int16 conversion automatically when the processing
    /// format differs from the file format.
    private func writeTestWAV(samples: [Float]) throws -> URL {
        let fmt = AudioEngine.whisperFormat
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let floatFmt = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        // Open file with Int16 on disk but float processing format.
        let file = try AVAudioFile(
            forWriting: url,
            settings: fmt.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        guard samples.count > 0 else { return url }

        guard let buf = AVAudioPCMBuffer(pcmFormat: floatFmt, frameCapacity: AVAudioFrameCount(samples.count)) else {
            return url
        }
        buf.frameLength = AVAudioFrameCount(samples.count)
        if let ptr = buf.floatChannelData?[0] {
            for i in 0..<samples.count {
                ptr[i] = samples[i]
            }
        }
        try file.write(from: buf)
        return url
    }

    /// Helper: read WAV frame count.
    private func frameCount(at url: URL) throws -> Int {
        let file = try AVAudioFile(forReading: url)
        return Int(file.length)
    }

    @Test("trimSilence strips leading silence")
    func trimLeadingSilence() throws {
        // 320 silent frames (20 ms) + 320 loud frames
        let silence = [Float](repeating: 0, count: 320)
        let loud = [Float](repeating: 0.5, count: 320)
        let url = try writeTestWAV(samples: silence + loud)
        let before = try frameCount(at: url)
        try AudioEngine.trimSilence(url: url, frameDuration: 0.020, threshold: 0.015)
        let after = try frameCount(at: url)
        #expect(after < before)
        #expect(after == 320)
        try? FileManager.default.removeItem(at: url)
    }

    @Test("trimSilence strips trailing silence")
    func trimTrailingSilence() throws {
        // 320 loud frames + 320 silent frames
        let loud = [Float](repeating: 0.5, count: 320)
        let silence = [Float](repeating: 0, count: 320)
        let url = try writeTestWAV(samples: loud + silence)
        let before = try frameCount(at: url)
        try AudioEngine.trimSilence(url: url, frameDuration: 0.020, threshold: 0.015)
        let after = try frameCount(at: url)
        #expect(after < before)
        #expect(after == 320)
        try? FileManager.default.removeItem(at: url)
    }

    @Test("trimSilence strips both leading and trailing silence")
    func trimBothSides() throws {
        let silence = [Float](repeating: 0, count: 320)
        let loud = [Float](repeating: 0.5, count: 320)
        let url = try writeTestWAV(samples: silence + loud + silence)
        try AudioEngine.trimSilence(url: url, frameDuration: 0.020, threshold: 0.015)
        let after = try frameCount(at: url)
        #expect(after == 320)
        try? FileManager.default.removeItem(at: url)
    }

    @Test("trimSilence keeps file unchanged when no silence at edges")
    func trimNoSilence() throws {
        let loud = [Float](repeating: 0.5, count: 640)
        let url = try writeTestWAV(samples: loud)
        let before = try frameCount(at: url)
        try AudioEngine.trimSilence(url: url, frameDuration: 0.020, threshold: 0.015)
        let after = try frameCount(at: url)
        #expect(after == before)
        try? FileManager.default.removeItem(at: url)
    }

    @Test("trimSilence produces empty file for all-silent input")
    func trimAllSilent() throws {
        let silence = [Float](repeating: 0, count: 640)
        let url = try writeTestWAV(samples: silence)
        try AudioEngine.trimSilence(url: url, frameDuration: 0.020, threshold: 0.015)
        let after = try frameCount(at: url)
        #expect(after == 0)
        try? FileManager.default.removeItem(at: url)
    }

    @Test("trimSilence preserves interior silence")
    func trimPreservesInterior() throws {
        let loud = [Float](repeating: 0.5, count: 320)
        let silence = [Float](repeating: 0, count: 320)
        // loud + silence + loud — interior silence should be kept
        let url = try writeTestWAV(samples: loud + silence + loud)
        try AudioEngine.trimSilence(url: url, frameDuration: 0.020, threshold: 0.015)
        let after = try frameCount(at: url)
        #expect(after == 960)
        try? FileManager.default.removeItem(at: url)
    }
}
