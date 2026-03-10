# McWhisper — Phase 1: Core

macOS 14+ menu bar app built with Swift/SwiftUI and Swift Package Manager. Apple Silicon required. No Dock icon. Local-only transcription via WhisperKit (Whisper models) and qwen3-asr-swift (Parakeet TDT / Qwen3-ASR). No cloud APIs. No external dependencies beyond Apple frameworks and those two packages.

Phase goal: smallest end-to-end working thing — hold a hotkey to record, release to transcribe with a local model, paste the result into the active app.

Build output is a signed `.app` bundle produced by `run.sh`. The app must launch successfully as part of every build verification step.

---

- [x] Scaffold SPM project and menu bar app shell
  - [x] Create `Package.swift` targeting macOS 14, Swift 5.10, single executable target `McWhisper`
  - [x] Add WhisperKit and qwen3-asr-swift as package dependencies
  - [x] Create `Sources/McWhisper/McWhisperApp.swift` with `@main` App struct; set activation policy to `.accessory` (no Dock icon) and include the `NSApplication.shared.setActivationPolicy(.regular)` workaround for SPM SwiftUI in `init()`
  - [x] Add a bare `MenuBarExtra` with a placeholder "McWhisper" label and a Quit button so the app is launchable
  - [x] Create `run.sh`: builds with `swift build -c release --disable-sandbox`, assembles `McWhisper.app` bundle with correct `Info.plist` (LSUIElement=YES, NSMicrophoneUsageDescription, bundle ID `com.mcwhisper.app`), ad-hoc codesigns with `codesign --deep -s -`, launches the app, and exits 0
  - [x] Verify `run.sh` succeeds and app appears in menu bar; capture screenshot with `appshot`

- [x] Define app-wide data model and settings store
  - [x] Create `AppSettings.swift` using `@AppStorage` / `UserDefaults` for: selected model ID, push-to-talk hotkey keycode + modifiers, selected mode, language selection ("auto" default)
  - [x] Create `TranscriptionMode.swift` enum with cases Voice, Message, Email, Note, Meeting plus a Custom case carrying a name and prompt string; store custom modes as JSON in UserDefaults
  - [x] Create `TranscriptionRecord.swift` struct (id, date, duration, rawText, processedText, mode, modelID) and a `HistoryStore` class persisting an array to a JSON file in Application Support

- [x] Implement microphone audio capture engine
  - [x] Create `AudioEngine.swift` wrapping `AVAudioEngine` + `AVAudioInputNode`; expose `startRecording()` / `stopRecording()` returning a temporary `.wav` file URL
  - [x] Tap the input node at 16 kHz mono (required by Whisper); write raw PCM via `AVAudioFile`
  - [x] Publish a `@Published var audioLevel: Float` (RMS) updated on each buffer for waveform use
  - [x] Add `AVCaptureDevice.requestAccess(for: .audio)` call at first launch with graceful error alert if denied

- [x] Implement Voice Activity Detection (VAD) and silence trimming
  - [x] Add lightweight energy-based VAD in `AudioEngine.swift`: track RMS per 20 ms frame; expose `@Published var speechDetected: Bool`
  - [x] After `stopRecording()`, strip leading and trailing silence frames below threshold before writing final audio file
  - [x] Expose a configurable silence threshold in `AppSettings`

- [x] Integrate WhisperKit for local transcription
  - [x] Create `TranscriptionService.swift` with a `WhisperKitEngine` class; on init, load the model specified in `AppSettings.selectedModelID` asynchronously
  - [x] Implement `transcribe(audioURL:language:) async throws -> String` using WhisperKit's pipeline; pass `language: nil` when auto-detect is selected
  - [x] Implement `transcribeStreaming(audioURL:language:onPartial:) async throws -> String` for real-time partial results via WhisperKit's decode loop; call `onPartial` closure with each partial string
  - [x] Default bundled model: `openai_whisper-base` (small enough to ship); larger models downloadable later

- [x] Implement global push-to-talk hotkey
  - [x] Create `HotkeyManager.swift` using `CGEventTap` (requires Accessibility permission); register a key-down event tap for the configured keycode + modifiers
  - [x] On key-down start recording via `AudioEngine`; on key-up stop recording and kick off transcription pipeline
  - [x] Request Accessibility permission at first launch with an alert linking to System Settings if not granted
  - [x] Store and restore the hotkey binding from `AppSettings`; default to Right Command

- [x] Build floating recording window
  - [x] Create `RecordingWindowController.swift` managing an `NSPanel` with `NSPanel.styleMask` `.nonactivatingPanel`; window floats above all apps (`level = .floating`) and does not steal focus
  - [x] `RecordingView.swift` (SwiftUI): show state-driven UI — idle (hidden), recording (waveform + live transcript), processing (spinner), result (processed text + action buttons)
  - [x] Animate window appearance/disappearance with fade; save last window position to `UserDefaults` and restore on next show
  - [x] Wire `AudioEngine.audioLevel` to the view; render a 30-bar animated waveform using bars whose heights are driven by a rolling buffer of recent RMS values

- [x] Build audio waveform visualization component
  - [x] Create `WaveformView.swift`: a SwiftUI `Canvas` drawing 30 vertical bars centered horizontally; bar heights are proportional to values in a `[Float]` ring buffer (capacity 30)
  - [x] Animate smoothly with `withAnimation(.linear(duration: 0.05))` on each new audio level sample
  - [x] Show flat bars when not recording; pulse gently with a sine wave to indicate standby

- [x] Implement transcription mode post-processing
  - [x] Create `ModeProcessor.swift`; for Phase 1 apply simple rule-based formatting per mode (Voice: raw text; Message: ensure sentence case and punctuation; Email: add greeting/sign-off placeholders; Note: bullet-point line breaks; Meeting: paragraph breaks on pauses)
  - [x] Expose `process(rawText:mode:) -> String`; hook into the transcription pipeline between raw result and paste
  - [x] Display both raw and processed text in `RecordingView` with a toggle

- [x] Implement auto-paste and clipboard fallback
  - [x] Create `PasteManager.swift`; before push-to-talk key-down, capture the frontmost `NSRunningApplication` via `NSWorkspace.shared.frontmostApplication`
  - [x] After transcription, re-focus the captured app with `app.activate(options: .activateIgnoringOtherApps)`, write text to `NSPasteboard.general`, then synthesize Cmd+V via `CGEvent` keystroke
  - [x] If paste fails (no frontmost app captured or app no longer running), copy to clipboard and show a brief HUD notification in `RecordingView` ("Copied to clipboard")

- [x] Build menu bar menu
  - [x] Expand `MenuBarExtra` menu with sections: current mode selector (radio group), separator, "Recording History..." (opens history window), "Settings..." (opens settings window), separator, "Quit"
  - [x] Show a pulsing red dot on the menu bar icon while recording using a `MenuBarExtra` label view that reacts to `AudioEngine.isRecording`

- [x] Build settings window
  - [x] Create `SettingsView.swift` with tabs: General (hotkey recorder, launch at login toggle), Models (list of WhisperKit model IDs with download/delete, active model picker), Modes (list of built-in and custom modes with edit sheet for name + prompt)
  - [x] Hotkey recorder: a focusable `NSViewRepresentable` that captures the next key combo and saves it to `AppSettings`
  - [x] Model download: show download progress with `URLSession` downloading the WhisperKit model package to `~/Library/Application Support/McWhisper/Models/`

- [x] Build transcription history window
  - [x] Create `HistoryView.swift`: searchable `List` of `TranscriptionRecord` sorted by date descending; each row shows timestamp, duration, mode badge, and first line of processed text
  - [x] Detail pane on row selection: full processed text, raw text toggle, Copy button, Re-transcribe button (re-runs current model + mode on the saved audio file)
  - [x] Multi-select delete with confirmation alert; persist deletions to `HistoryStore`

- [x] Wire end-to-end pipeline and integration test
  - [x] Connect hotkey -> audio capture -> VAD -> WhisperKit streaming transcription -> mode post-processing -> auto-paste, updating `RecordingView` state at each step
  - [x] Save completed transcription to `HistoryStore` including audio file path, timestamps, model, and mode

- [x] Polish, permissions flow, and launch-at-login
  - [x] Add `SMAppService.mainApp.register()` for launch-at-login toggled from Settings > General
  - [x] On first launch show a one-time onboarding sheet: request Microphone access, Accessibility access (for global hotkey and paste), explain no data leaves the device
  - [x] Ensure `run.sh` exits non-zero if the app fails to appear within 5 seconds (use `pgrep McWhisper` check)

---

## Manual verification (user must test)

- [x] Run `run.sh`, launch app, grant Microphone and Accessibility permissions
- [x] Hold Right Command, speak a sentence, release. Confirm waveform animates during recording, partial text appears in the floating window, and final text is pasted into the frontmost app
- [x] Open Settings, change the hotkey, verify the new hotkey works
- [x] Download a larger model from Settings > Models, switch to it, and verify transcription still works
- [x] Open Recording History, verify past transcriptions appear, select one, copy it, delete it
- [x] Switch transcription modes (Voice, Message, Email, Note, Meeting) and verify formatting differences
- [x] Quit and relaunch. Verify launch-at-login setting persists and the app reappears in the menu bar
- [x] With no frontmost app, record and release. Verify clipboard fallback and HUD notification

---

## Implemented but not originally planned

- [x] Create `ModelCatalog.swift` enum listing available Whisper models with `bundledModelID`, `availableModels`, `downloadableModels`, and `model(for:)` lookup; `openai_whisper-base` as the single bundled default
- [x] Create `MicrophonePermission.swift` helper with static `status` and async `request()` wrapping `AVCaptureDevice` audio authorization
- [x] Create `RecordingCoordinator.swift` (`@MainActor ObservableObject`) orchestrating the full push-to-talk flow: owns `HotkeyManager`, `AudioEngine`, `WhisperKitEngine`, `HistoryStore`, and `RecordingWindowController`; manages state machine (idle/recording/transcribing/error), rolling level buffer, and inline paste via `NSPasteboard` + `CGEvent` Cmd+V
- [x] Add comprehensive unit test suite: `McWhisperTests`, `AppSettingsTests`, `TranscriptionServiceTests`, `TranscriptionModeTests`, `HistoryStoreTests`, `AudioEngineTests`, `HotkeyManagerTests`, `ModelCatalogTests`, `MicrophonePermissionTests`, `RecordingViewTests`, `RecordingWindowControllerTests`, `RecordingCoordinatorTests`, `BundleTests`, `AppBundleTests`

---

# McWhisper — Phase 2: Parakeet TDT and Qwen3-ASR engines

macOS 14+ desktop menu bar app in Swift/SwiftUI using SPM. This phase wires the qwen3-asr-swift package into a new `TranscriptionEngine` protocol, adds Parakeet TDT and Qwen3-ASR models to `ModelCatalog`, routes transcription to the correct backend based on the selected model, and fixes the audio level pipeline so the waveform animates during real push-to-talk recording. No cloud APIs; all inference is local, Apple Silicon required.

- [x] Fix audio level pipeline so waveform animates during real push-to-talk recording [fix: "waveform shows static dashes during real recording (works in panel preview but not during actual push-to-talk recording, audio levels not flowing to view)"]
  - [x] Trace `AudioEngine.$audioLevel` → `RecordingCoordinator.levelSamples` Combine subscription; confirm tap is installed before `startRecording()` emits levels and that the subscription is not cancelled on key-up before the UI reads it
  - [x] Verify `RecordingView` observes `coordinator.levelSamples` and that `WaveformView` receives non-zero values during recording; add a debug `print` temporarily if needed to confirm data flow
  - [x] Fix the root cause (e.g. subscription lifetime, wrong thread, buffer reset timing) and remove any debug logging
- [x] Add `qwen3-asr-swift` as an explicit SPM package dependency in `Package.swift` if not already declared, and confirm it builds with `swift build --disable-sandbox` [fix: "qwen3-asr-swift is a package dependency in Package.swift but never wired into ModelCatalog or TranscriptionService, no Parakeet/Qwen3-ASR models available to the user"]
- [x] Define `TranscriptionEngine` protocol in a new file `Sources/McWhisper/TranscriptionEngine.swift` with `loadModel() async throws`, `transcribe(audioURL:language:) async throws -> String`, `transcribeStreaming(audioURL:language:onPartial:) async throws -> String`, `var modelState: ModelState { get }`, and `var isModelCurrent: Bool { get }` [feat: "Multiple local voice models"]
- [x] Refactor `WhisperKitEngine` in `TranscriptionService.swift` to conform to `TranscriptionEngine` protocol; keep all existing behaviour intact [feat: "Multiple local voice models"]
- [x] Add an `EngineTag` enum (or property on `ModelInfo`) to `ModelCatalog.swift` with cases `.whisperKit` and `.qwen3asr`, and annotate every existing model entry with its engine tag [feat: "Multiple local voice models"]
- [x] Add Parakeet TDT and Qwen3-ASR model entries to `ModelCatalog.swift` (display names, size labels, HuggingFace repo slugs, `isBundled: false`, engine tag `.qwen3asr`) [feat: "Multiple local voice models"]
- [x] Implement `Qwen3ASREngine` in a new file `Sources/McWhisper/Qwen3ASREngine.swift` conforming to `TranscriptionEngine`, wrapping the qwen3-asr-swift API for `loadModel`, `transcribe`, and `transcribeStreaming` (poll partial results if the library lacks a callback) [feat: "Multiple local voice models"]
- [x] Update `ModelDownloader` to resolve the correct HuggingFace repo slug per engine tag when downloading Parakeet TDT or Qwen3-ASR models, so `downloadModel(_:)` targets the right repository [feat: "Multiple local voice models"]
- [ ] Update `RecordingCoordinator` to instantiate the correct `TranscriptionEngine` (`WhisperKitEngine` or `Qwen3ASREngine`) based on `AppSettings.selectedModelID` and the model's engine tag; switch engine when the selected model changes [feat: "Multiple local voice models"]
- [ ] Update `SettingsView` `ModelsSettingsTab` to guard model selection by engine availability (Apple Silicon check if needed) and display engine badge (e.g. "WhisperKit" / "Qwen3-ASR") alongside model rows [feat: "Multiple local voice models"]
- [ ] Add unit tests in `TranscriptionEngineTests.swift` verifying protocol conformance, `EngineTag` lookup for all catalog models, and `Qwen3ASREngine` initial state (modelState, isModelCurrent, no crash on init) [feat: "Multiple local voice models"]
- [ ] Run full test suite with `swift test --disable-sandbox` and fix any failures before proceeding
- [ ] Wire up 13 documentation-example test(s) (markdown, shell, text)
  - [ ] Replace `run_example()` stub in test_doc_examples_generated.py with actual project imports
  - [ ] Run pytest and fix any failing doc-example tests
- [ ] Update `run.sh` if any new build flags or plist keys are required, then do an end-to-end smoke test: build, launch, open Settings → Models, confirm Parakeet TDT and Qwen3-ASR entries appear, download one, select it, record a short phrase, and verify a transcript is returned without error [feat: "Multiple local voice models"]

