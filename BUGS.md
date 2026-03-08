# Bugs

## RecordingCoordinator.swift:80 -- Error state is unrecoverable
**Severity**: high
`handleKeyDown()` guards on `state == .idle` and returns otherwise. When state enters `.error(...)` (from a failed stop-recording on line 106 or failed transcription on line 232), there is no mechanism to reset it back to `.idle`. The user cannot start a new recording and the floating panel stays visible with the error message. The app is stuck until quit and relaunched.

## HotkeyManager.swift:160 -- Data race on isKeyDown from event tap callback
**Severity**: medium
The `hotkeyCallback` C function runs on the event tap's Mach port thread, not the main thread. It reads `manager.isKeyDown` (lines 160, 165, 181, 189, 204) without synchronization. `isKeyDown` is a `@Published` property that is only written on `DispatchQueue.main.async`. Reading it from the callback thread while it could be concurrently written from the main thread is a data race that could cause duplicate keyDown/keyUp callbacks or missed events.

## HotkeyManager.swift:150 -- Caps Lock and Fn hotkeys silently non-functional
**Severity**: medium
`isModifierOnlyKey` (line 92) includes keyCodes 57 (Caps Lock) and 63 (Fn). However, the `modifierFlag` switch in `hotkeyCallback` (lines 150-156) only handles Command/Shift/Option/Control keyCodes, with `default: return Unmanaged.passUnretained(event)`. If the user configures Caps Lock or Fn as the hotkey via the recorder (which allows it at SettingsView.swift:279), the event tap callback will exit early without ever triggering `onKeyDown`/`onKeyUp`, making the hotkey silently non-functional.

## AudioEngine.swift:106 -- Data race on VAD state from audio tap callback
**Severity**: medium
The audio tap callback (installed at line 80) reads and writes `self.vadSilentFrameCount` (lines 106, 109) and reads `self.vadHangoverFrames` (line 114) on the audio render thread. These same properties are written on the caller's thread in `startRecording()` (lines 78, 75) and `stopRecording()` (line 168). `AudioEngine` has no isolation or synchronization, so concurrent access between the audio thread and the calling thread is a data race.

## McWhisperApp.swift:57 -- Status text shows wrong hotkey
**Severity**: low
`StatusView` displays a hardcoded string `"Ready (Option+Space)"` but the default hotkey is Right Command (keyCode 54, modifiers 0), not Option+Space. This text is also never updated when the user changes the hotkey in settings, so it will always be wrong unless the user happens to set Option+Space.

## HistoryView.swift:5 -- HistoryStore changes don't trigger UI updates
**Severity**: low
`HistoryStore` is a plain class, not an `ObservableObject`, and `records` is not `@Published`. `HistoryView` holds it as `let historyStore: HistoryStore`. If a new recording is added to the store while the history window is open (e.g., user records while browsing history), the new record will not appear until the window is closed and reopened. Deletions within the view work incidentally because the `@State selectedRecordIDs` change triggers a re-render that re-reads `records`.
