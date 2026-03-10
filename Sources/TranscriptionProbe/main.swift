import AVFoundation
import Foundation
import WhisperKit

@main
struct TranscriptionProbe {
    static func main() async {
        do {
            try await ensureMicrophonePermission()
        } catch {
            fputs("TranscriptionProbe error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        let recorder = Recorder()

        print("TranscriptionProbe")
        print("Press Enter to start recording.")
        _ = readLine()

        let audioURL: URL
        do {
            audioURL = try recorder.start()
        } catch {
            fputs("Failed to start recording: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        print("Recording from the microphone. Speak, then press Enter to stop.")
        _ = readLine()

        do {
            try recorder.stop()
        } catch {
            fputs("Failed to stop recording: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        defer {
            try? FileManager.default.removeItem(at: audioURL)
        }

        print("Loading Whisper model...")

        let whisperKit: WhisperKit
        do {
            let config = WhisperKitConfig(model: "base", verbose: false, logLevel: .none)
            whisperKit = try await WhisperKit(config)
        } catch {
            fputs("Failed to load WhisperKit model: \(error.localizedDescription)\n", stderr)
            exit(1)
        }

        print("Transcribing...")
        do {
            let results = try await whisperKit.transcribe(audioPath: audioURL.path)
            let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                fputs("Transcription returned no text.\n", stderr)
                exit(1)
            }
            print("")
            print("Transcript:")
            print(text)
        } catch {
            fputs("Transcription failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func ensureMicrophonePermission() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { continuation.resume(returning: $0) }
            }
            if granted {
                return
            }
            throw ProbeError.microphonePermissionDenied
        case .denied, .restricted:
            throw ProbeError.microphonePermissionDenied
        @unknown default:
            throw ProbeError.microphonePermissionDenied
        }
    }
}

private final class Recorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?

    func start() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = false
        guard recorder.record() else {
            throw ProbeError.recordingDidNotStart
        }

        self.recorder = recorder
        return url
    }

    func stop() throws {
        guard let recorder else {
            throw ProbeError.recordingDidNotStart
        }
        recorder.stop()
        self.recorder = nil
    }
}

private enum ProbeError: LocalizedError {
    case microphonePermissionDenied
    case recordingDidNotStart

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required for TranscriptionProbe."
        case .recordingDidNotStart:
            return "The recorder did not start."
        }
    }
}
