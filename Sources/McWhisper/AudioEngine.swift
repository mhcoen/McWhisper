import AVFoundation
import Combine

struct RecordedAudio: Equatable {
    let samples: [Float]
}

enum AudioEngineError: Error, Equatable {
    case alreadyRecording
    case notRecording
    case noInputAvailable
    case engineStartFailed(String)
    case fileCreationFailed(String)
}

final class AudioEngine: ObservableObject {
    private var engine: AVAudioEngine?
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
    private let vadLock = NSLock()

    /// Accumulated audio buffers from the tap, written to file on stop.
    private var recordedBuffers: [AVAudioPCMBuffer] = []
    private let bufferLock = NSLock()

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

        // Compute VAD hangover in frames based on hardware sample rate.
        let vadFrameSize = Int(hwFormat.sampleRate * AudioEngine.vadFrameDuration)
        vadLock.withLock {
            self.vadHangoverFrames = vadFrameSize > 0
                ? Int(AudioEngine.vadHangoverDuration / AudioEngine.vadFrameDuration)
                : 0
            self.vadSilentFrameCount = vadHangoverFrames  // start as silent
        }

        bufferLock.withLock { recordedBuffers = [] }

        // Install tap with hardware format. Buffers are accumulated in memory
        // and converted to 16 kHz mono WAV on stop.
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
                let detected: Bool = self.vadLock.withLock {
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
                    return speechInBuffer || self.vadSilentFrameCount < self.vadHangoverFrames
                }

                DispatchQueue.main.async { [weak self] in
                    self?.audioLevel = clamped
                    self?.speechDetected = detected
                }
            }

            // Copy and accumulate the buffer.
            guard buffer.frameLength > 0,
                  let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
                return
            }
            copy.frameLength = buffer.frameLength
            let channelCount = Int(buffer.format.channelCount)
            if let src = buffer.floatChannelData, let dst = copy.floatChannelData {
                for ch in 0..<channelCount {
                    dst[ch].update(from: src[ch], count: Int(buffer.frameLength))
                }
            }
            self.bufferLock.withLock {
                self.recordedBuffers.append(copy)
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
        self.isRecording = true
    }

    /// Stop recording and return trimmed 16 kHz mono float samples.
    /// Throws if not currently recording.
    func stopRecording() throws -> RecordedAudio {
        guard isRecording, let engine = engine else {
            throw AudioEngineError.notRecording
        }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        // Grab accumulated buffers and convert them directly to Whisper-ready samples.
        let buffers = bufferLock.withLock {
            let b = recordedBuffers
            recordedBuffers = []
            return b
        }
        let samples = try convertBuffersToWhisperSamples(buffers)

        self.engine = nil
        self.isRecording = false
        self.audioLevel = 0.0
        self.speechDetected = false
        vadLock.withLock { self.vadSilentFrameCount = 0 }

        return RecordedAudio(samples: AudioEngine.trimSilence(
            samples: samples,
            frameDuration: AudioEngine.vadFrameDuration,
            threshold: AudioEngine.vadThreshold,
            sampleRate: 16000
        ))
    }

    /// Convert accumulated hardware-format buffers to 16 kHz mono float samples.
    private func convertBuffersToWhisperSamples(_ buffers: [AVAudioPCMBuffer]) throws -> [Float] {
        guard let srcFormat = buffers.first?.format else { return [] }

        let floatFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        guard let converter = AVAudioConverter(from: srcFormat, to: floatFormat) else {
            throw AudioEngineError.fileCreationFailed("Could not create audio converter")
        }

        var output: [Float] = []
        for buffer in buffers {
            let frameCapacity = AVAudioFrameCount(
                Double(buffer.frameLength) * (16000.0 / srcFormat.sampleRate)
            )
            guard frameCapacity > 0,
                  let convertedBuffer = AVAudioPCMBuffer(pcmFormat: floatFormat, frameCapacity: frameCapacity) else {
                continue
            }
            var error: NSError?
            var inputConsumed = false
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                if inputConsumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                inputConsumed = true
                outStatus.pointee = .haveData
                return buffer
            }
            if let error {
                throw AudioEngineError.fileCreationFailed(error.localizedDescription)
            }
            if convertedBuffer.frameLength > 0, let samples = convertedBuffer.floatChannelData?[0] {
                output.append(contentsOf: UnsafeBufferPointer(start: samples, count: Int(convertedBuffer.frameLength)))
            }
        }
        return output
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

    /// Trim leading and trailing silence from in-memory 16 kHz mono float samples.
    static func trimSilence(
        samples: [Float],
        frameDuration: Double,
        threshold: Float,
        sampleRate: Double
    ) -> [Float] {
        let count = samples.count
        guard count > 0 else { return [] }

        let frameSize = max(1, Int(sampleRate * frameDuration))

        var firstSample = count
        var offset = 0
        while offset + frameSize <= count {
            let rms = samples.withUnsafeBufferPointer { ptr in
                rmsOfSlice(ptr.baseAddress!, offset: offset, length: frameSize)
            }
            if rms >= threshold {
                firstSample = offset
                break
            }
            offset += frameSize
        }

        guard firstSample < count else {
            return []
        }

        var lastSampleEnd = count
        offset = (count / frameSize) * frameSize
        if offset == count { offset -= frameSize }
        while offset >= firstSample {
            let len = min(frameSize, count - offset)
            let rms = samples.withUnsafeBufferPointer { ptr in
                rmsOfSlice(ptr.baseAddress!, offset: offset, length: len)
            }
            if rms >= threshold {
                lastSampleEnd = offset + len
                break
            }
            offset -= frameSize
        }

        return Array(samples[firstSample..<lastSampleEnd])
    }

    static func writeWhisperSamples(_ samples: [Float], to url: URL) throws {
        let file = try AVAudioFile(
            forWriting: url,
            settings: whisperFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )

        guard !samples.isEmpty else {
            let emptyBuffer = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: 0)!
            try file.write(from: emptyBuffer)
            return
        }

        let floatFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: floatFormat,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else {
            throw AudioEngineError.fileCreationFailed("Could not allocate audio buffer")
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let dst = buffer.floatChannelData?[0] {
            dst.update(from: samples, count: samples.count)
        }
        try file.write(from: buffer)
    }

    /// Load a WAV file as 16 kHz mono float samples suitable for transcription.
    static func loadWhisperSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let floatFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: floatFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        ) else {
            throw AudioEngineError.fileCreationFailed("Could not allocate read buffer")
        }
        try file.read(into: buffer)
        guard let data = buffer.floatChannelData?[0] else {
            return []
        }
        return Array(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength)))
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
