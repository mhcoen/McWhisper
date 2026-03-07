import AVFoundation
import Combine

enum AudioEngineError: Error, Equatable {
    case alreadyRecording
    case notRecording
    case noInputAvailable
    case engineStartFailed(String)
    case fileCreationFailed(String)
}

final class AudioEngine: ObservableObject {
    private var engine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    private var recordingURL: URL?
    @Published private(set) var isRecording = false

    /// RMS audio level (0.0–1.0) updated on each buffer during recording.
    @Published private(set) var audioLevel: Float = 0.0

    /// True when speech energy is detected above the VAD threshold.
    @Published private(set) var speechDetected: Bool = false

    // VAD configuration
    static let vadFrameDuration: Double = 0.020   // 20 ms
    /// RMS threshold for speech — reads from AppSettings at recording start.
    static var vadThreshold: Float { Float(AppSettings.silenceThreshold) }
    static let vadHangoverDuration: Double = 0.300 // keep speechDetected true for 300 ms after energy drops

    /// Frames since last frame above threshold (used for hangover).
    private var vadSilentFrameCount: Int = 0
    private var vadHangoverFrames: Int = 0  // computed at start based on sample rate

    /// 16-bit 16 kHz mono — standard Whisper input format.
    static let whisperFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: true
    )!

    /// Start recording from the default input device.
    /// Throws if already recording or no input device is available.
    func startRecording() throws {
        guard !isRecording else { throw AudioEngineError.alreadyRecording }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        let hwFormat = inputNode.outputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0, hwFormat.channelCount > 0 else {
            throw AudioEngineError.noInputAvailable
        }

        let wavFormat = AudioEngine.whisperFormat

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let file: AVAudioFile
        do {
            file = try AVAudioFile(forWriting: url, settings: wavFormat.settings)
        } catch {
            throw AudioEngineError.fileCreationFailed(error.localizedDescription)
        }

        // Install a tap that converts hardware format → 16 kHz mono and writes to file.
        guard let converter = AVAudioConverter(from: hwFormat, to: wavFormat) else {
            throw AudioEngineError.fileCreationFailed("Could not create audio converter")
        }

        // Compute VAD hangover in frames based on hardware sample rate.
        let vadFrameSize = Int(hwFormat.sampleRate * AudioEngine.vadFrameDuration)
        self.vadHangoverFrames = vadFrameSize > 0
            ? Int(AudioEngine.vadHangoverDuration / AudioEngine.vadFrameDuration)
            : 0
        self.vadSilentFrameCount = vadHangoverFrames  // start as silent

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            // Compute RMS from the raw hardware buffer.
            if let channelData = buffer.floatChannelData {
                let totalFrames = Int(buffer.frameLength)
                let samples = channelData[0]
                var sumOfSquares: Float = 0
                for i in 0..<totalFrames {
                    let s = samples[i]
                    sumOfSquares += s * s
                }
                let rms = totalFrames > 0 ? sqrtf(sumOfSquares / Float(totalFrames)) : 0
                let clamped = min(max(rms, 0), 1)

                // VAD: process 20 ms frames within this buffer.
                var speechInBuffer = false
                if vadFrameSize > 0 {
                    var offset = 0
                    while offset + vadFrameSize <= totalFrames {
                        var frameSum: Float = 0
                        for i in offset..<(offset + vadFrameSize) {
                            let s = samples[i]
                            frameSum += s * s
                        }
                        let frameRMS = sqrtf(frameSum / Float(vadFrameSize))
                        if frameRMS >= AudioEngine.vadThreshold {
                            self.vadSilentFrameCount = 0
                            speechInBuffer = true
                        } else {
                            self.vadSilentFrameCount += 1
                        }
                        offset += vadFrameSize
                    }
                }
                let detected = speechInBuffer || self.vadSilentFrameCount < self.vadHangoverFrames

                DispatchQueue.main.async {
                    self.audioLevel = clamped
                    self.speechDetected = detected
                }
            }
            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * (16000.0 / hwFormat.sampleRate)
            )
            guard frameCapacity > 0,
                  let convertedBuffer = AVAudioPCMBuffer(pcmFormat: wavFormat, frameCapacity: frameCapacity) else {
                return
            }
            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            if error == nil, convertedBuffer.frameLength > 0 {
                try? file.write(from: convertedBuffer)
            }
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioEngineError.engineStartFailed(error.localizedDescription)
        }

        self.engine = engine
        self.outputFile = file
        self.recordingURL = url
        self.isRecording = true
    }

    /// Stop recording and return the URL of the WAV file.
    /// Throws if not currently recording.
    func stopRecording() throws -> URL {
        guard isRecording, let engine = engine, let url = recordingURL else {
            throw AudioEngineError.notRecording
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        self.engine = nil
        self.outputFile = nil
        self.recordingURL = nil
        self.isRecording = false
        self.audioLevel = 0.0
        self.speechDetected = false
        self.vadSilentFrameCount = 0

        // Trim leading/trailing silence in-place.
        try AudioEngine.trimSilence(
            url: url,
            frameDuration: AudioEngine.vadFrameDuration,
            threshold: AudioEngine.vadThreshold
        )

        return url
    }

    /// Trim leading and trailing silence from a 16 kHz mono WAV file.
    /// Rewrites the file in-place. If the entire file is silent, writes an empty file.
    static func trimSilence(url: URL, frameDuration: Double, threshold: Float) throws {
        let sourceFile = try AVAudioFile(forReading: url)
        let totalFrames = AVAudioFrameCount(sourceFile.length)
        guard totalFrames > 0 else { return }

        let readFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sourceFile.fileFormat.sampleRate,
            channels: sourceFile.fileFormat.channelCount,
            interleaved: false
        )!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: readFormat, frameCapacity: totalFrames) else {
            return
        }
        try sourceFile.read(into: buffer)

        guard let samples = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        let frameSize = max(1, Int(readFormat.sampleRate * frameDuration))

        // Find first frame above threshold.
        var firstSample = count  // default: everything is silent
        var offset = 0
        while offset + frameSize <= count {
            let rms = rmsOfSlice(samples, offset: offset, length: frameSize)
            if rms >= threshold {
                firstSample = offset
                break
            }
            offset += frameSize
        }

        guard firstSample < count else {
            // Entire file is silence — write an empty file.
            let emptyBuffer = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: 0)!
            let outFile = try AVAudioFile(forWriting: url, settings: whisperFormat.settings)
            try outFile.write(from: emptyBuffer)
            return
        }

        // Find last frame above threshold (scan backwards).
        var lastSampleEnd = count
        offset = (count / frameSize) * frameSize  // align to frame boundary at end
        if offset == count { offset -= frameSize }
        while offset >= firstSample {
            let len = min(frameSize, count - offset)
            let rms = rmsOfSlice(samples, offset: offset, length: len)
            if rms >= threshold {
                lastSampleEnd = offset + len
                break
            }
            offset -= frameSize
        }

        // Write trimmed audio back to the same URL.
        let trimmedCount = lastSampleEnd - firstSample
        guard trimmedCount > 0 else { return }

        guard let trimmedBuffer = AVAudioPCMBuffer(
            pcmFormat: readFormat,
            frameCapacity: AVAudioFrameCount(trimmedCount)
        ) else { return }
        trimmedBuffer.frameLength = AVAudioFrameCount(trimmedCount)
        if let dst = trimmedBuffer.floatChannelData?[0] {
            dst.update(from: samples + firstSample, count: trimmedCount)
        }

        // Write trimmed float buffer; AVAudioFile converts to Int16 on disk.
        let outFile = try AVAudioFile(
            forWriting: url,
            settings: whisperFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try outFile.write(from: trimmedBuffer)
    }

    /// Compute RMS of a slice of float samples.
    private static func rmsOfSlice(_ samples: UnsafePointer<Float>, offset: Int, length: Int) -> Float {
        var sum: Float = 0
        for i in offset..<(offset + length) {
            let s = samples[i]
            sum += s * s
        }
        return sqrtf(sum / Float(length))
    }
}
