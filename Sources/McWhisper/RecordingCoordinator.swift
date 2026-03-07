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

    enum State: Equatable {
        case idle
        case recording
        case transcribing
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var partialText: String = ""

    /// Rolling buffer of recent RMS audio levels for waveform display.
    static let levelBufferSize = 30
    @Published private(set) var levelSamples: [Float] = Array(repeating: 0, count: 30)

    private var levelCancellable: AnyCancellable?
    private var recordingStartTime: Date?

    func start() {
        levelCancellable = audioEngine.$audioLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                guard let self, self.state == .recording else { return }
                withAnimation(.linear(duration: 0.05)) {
                    self.levelSamples.append(level)
                    if self.levelSamples.count > Self.levelBufferSize {
                        self.levelSamples.removeFirst(self.levelSamples.count - Self.levelBufferSize)
                    }
                }
            }

        hotkeyManager.onKeyDown = { [weak self] in
            self?.handleKeyDown()
        }
        hotkeyManager.onKeyUp = { [weak self] in
            self?.handleKeyUp()
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

        Task {
            try? await whisperEngine.loadModel()
        }
    }

    func stop() {
        hotkeyManager.stop()
        levelCancellable?.cancel()
        levelCancellable = nil
    }

    // MARK: - Hotkey handlers

    private func handleKeyDown() {
        guard state == .idle else { return }

        do {
            levelSamples = Array(repeating: 0, count: Self.levelBufferSize)
            try audioEngine.startRecording()
            recordingStartTime = Date()
            state = .recording
            windowController.show(coordinator: self)
        } catch {
            state = .error("Recording failed: \(error.localizedDescription)")
        }
    }

    private func handleKeyUp() {
        guard state == .recording else { return }

        let duration = recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0
        let audioURL: URL
        do {
            audioURL = try audioEngine.stopRecording()
        } catch {
            state = .error("Stop recording failed: \(error.localizedDescription)")
            return
        }

        state = .transcribing
        partialText = ""

        Task {
            await transcribeAndPaste(audioURL: audioURL, duration: duration)
        }
    }

    // MARK: - Transcription pipeline

    private func transcribeAndPaste(audioURL: URL, duration: TimeInterval) async {
        if !whisperEngine.isModelCurrent {
            try? await whisperEngine.loadModel()
        }

        let language = AppSettings.selectedLanguage
        let lang: String? = language == "auto" ? nil : language

        do {
            let text = try await whisperEngine.transcribeStreaming(
                audioURL: audioURL,
                language: lang
            ) { [weak self] partial in
                Task { @MainActor in
                    self?.partialText = partial
                }
            }

            let mode = TranscriptionMode.from(id: AppSettings.selectedMode) ?? .voice
            let record = TranscriptionRecord(
                duration: duration,
                rawText: text,
                processedText: text,
                mode: mode,
                modelID: AppSettings.selectedModelID
            )
            historyStore.add(record)

            pasteText(text)
            windowController.hide()
            state = .idle
            partialText = ""
        } catch {
            state = .error("Transcription failed: \(error.localizedDescription)")
        }

        try? FileManager.default.removeItem(at: audioURL)
    }

    // MARK: - Paste into active app

    /// Writes text to the system pasteboard and simulates Cmd+V.
    private func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)
        // keyCode 9 = 'v'
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
