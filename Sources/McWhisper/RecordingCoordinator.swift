import AppKit
import Combine
import SwiftUI

/// Orchestrates the push-to-talk flow: hotkey → record → transcribe → paste.
@MainActor
final class RecordingCoordinator: ObservableObject {
    let hotkeyManager = HotkeyManager()
    let audioEngine = AudioEngine()
    let whisperEngine = WhisperKitEngine()
    let historyStore = HistoryStore()
    let windowController = RecordingWindowController()
    let pasteManager = PasteManager()

    enum State: Equatable {
        case idle
        case recording
        case transcribing
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var partialText: String = ""
    @Published private(set) var rawText: String = ""
    @Published private(set) var processedText: String = ""
    @Published private(set) var hudMessage: String = ""

    /// Rolling buffer of recent RMS audio levels for waveform display.
    static let levelBufferSize = 30
    @Published private(set) var levelSamples: [Float] = Array(repeating: 0, count: 30)

    private var levelCancellable: AnyCancellable?

    /// Whether the audio-level Combine subscription is active. Exposed for testing.
    var hasLevelSubscription: Bool { levelCancellable != nil }
    private var recordingStartTime: Date?
    private var hudDismissTask: Task<Void, Never>?

    func start() {
        if levelCancellable == nil {
            levelCancellable = audioEngine.$audioLevel
                .sink { [weak self] level in
                    guard let self, self.state == .recording else { return }
                    withAnimation(.linear(duration: 0.05)) {
                        self.levelSamples.append(level)
                        if self.levelSamples.count > Self.levelBufferSize {
                            self.levelSamples.removeFirst(self.levelSamples.count - Self.levelBufferSize)
                        }
                    }
                }
        }

        hotkeyManager.onKeyDown = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.handleKeyDown()
            }
        }
        hotkeyManager.onKeyUp = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.handleKeyUp()
            }
        }

        if HotkeyManager.hasAccessibilityPermission {
            do {
                try hotkeyManager.start()
            } catch {
                state = .error("Failed to start hotkey listener: \(error.localizedDescription)")
            }
        } else {
            HotkeyManager.requestAccessibilityPermission()
        }

        // Model loads lazily on first transcription.
    }

    func stop() {
        hotkeyManager.stop()
        levelCancellable?.cancel()
        levelCancellable = nil
    }

    // MARK: - Hotkey handlers

    private func handleKeyDown() {
        switch state {
        case .error:
            state = .idle
            windowController.hide()
        case .idle:
            break
        default:
            return
        }

        hudDismissTask?.cancel()
        hudMessage = ""
        pasteManager.captureTarget()
        levelSamples = Array(repeating: 0, count: Self.levelBufferSize)
        rawText = ""
        processedText = ""
        partialText = ""
        state = .recording
        windowController.show(coordinator: self)

        do {
            try audioEngine.startRecording()
            recordingStartTime = Date()
        } catch {
            state = .error("Recording failed: \(error.localizedDescription)")
        }
    }

    private func handleKeyUp() {
        guard state == .recording else { return }

        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let recording: RecordedAudio
        do {
            recording = try audioEngine.stopRecording()
        } catch {
            state = .error("Stop recording failed: \(error.localizedDescription)")
            return
        }

        state = .transcribing
        partialText = ""

        Task {
            await transcribeAndPaste(recording: recording, duration: duration)
        }
    }

    // MARK: - HUD

    static let hudDisplayDuration: TimeInterval = 2.0

    private func showHud(_ message: String) {
        hudDismissTask?.cancel()
        hudMessage = message
        state = .idle
        partialText = ""
        hudDismissTask = Task {
            try? await Task.sleep(for: .seconds(Self.hudDisplayDuration))
            guard !Task.isCancelled else { return }
            hudMessage = ""
            windowController.hide()
        }
    }

    // MARK: - Audio file storage

    static let audioDirectory: URL = {
        HistoryStore.defaultDirectory.appendingPathComponent("Audio", isDirectory: true)
    }()

    static func saveAudioFile(from samples: [Float]) -> String? {
        let fileName = UUID().uuidString + ".wav"
        let dest = audioDirectory.appendingPathComponent(fileName)
        do {
            try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
            try AudioEngine.writeWhisperSamples(samples, to: dest)
            return fileName
        } catch {
            return nil
        }
    }

    // MARK: - Re-transcription

    func retranscribe(record: TranscriptionRecord) {
        guard let audioURL = record.audioFileURL, record.hasAudioFile else { return }

        Task {
            if !whisperEngine.isModelCurrent {
                try? await whisperEngine.loadModel()
            }

            let language = AppSettings.selectedLanguage
            let lang: String? = language == "auto" ? nil : language

            do {
                let text = try await whisperEngine.transcribe(audioURL: audioURL, language: lang)
                let mode = TranscriptionMode.from(id: AppSettings.selectedMode) ?? .voice
                let processed = ModeProcessor.process(text, mode: mode)
                let updated = TranscriptionRecord(
                    id: record.id,
                    date: record.date,
                    duration: record.duration,
                    rawText: text,
                    processedText: processed,
                    mode: mode,
                    modelID: AppSettings.selectedModelID,
                    audioFileName: record.audioFileName
                )
                historyStore.updateRecord(updated)
            } catch {
                // Re-transcription failure is non-fatal
            }
        }
    }

    // MARK: - Transcription pipeline

    private func transcribeAndPaste(recording: RecordedAudio, duration: TimeInterval) async {
        if !whisperEngine.isModelCurrent {
            do {
                try await whisperEngine.loadModel()
            } catch {
                state = .error("Transcription failed: \(error.localizedDescription)")
                return
            }
        }

        let language = AppSettings.selectedLanguage
        let lang: String? = language == "auto" ? nil : language

        do {
            let text = try await whisperEngine.transcribeStreaming(
                audioSamples: recording.samples,
                language: lang
            ) { [weak self] partial in
                Task { @MainActor in
                    self?.partialText = partial
                }
            }
            let mode = TranscriptionMode.from(id: AppSettings.selectedMode) ?? .voice
            let processed = ModeProcessor.process(text, mode: mode)
            rawText = text
            processedText = processed
            let audioFileName = Self.saveAudioFile(from: recording.samples)
            let record = TranscriptionRecord(
                duration: duration,
                rawText: text,
                processedText: processed,
                mode: mode,
                modelID: AppSettings.selectedModelID,
                audioFileName: audioFileName
            )
            historyStore.add(record)

            let pasted = pasteManager.paste(processed)
            if pasted {
                pasteManager.clearTarget()
                windowController.hide()
                state = .idle
                partialText = ""
            } else {
                pasteManager.clearTarget()
                showHud("Copied to clipboard")
            }
        } catch {
            state = .error("Transcription failed: \(error.localizedDescription)")
        }
    }

}
