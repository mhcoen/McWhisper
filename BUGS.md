# Bugs

## HotkeyManager.swift:184 -- Data race on `isKeyDown` between tap thread and main thread
**Severity**: medium
`isKeyDown` is read on the event tap background thread (e.g., line 184 `!isKeyDown`, line 211 `!isKeyDown`, line 220 `isKeyDown`, line 231 `isKeyDown`) but written asynchronously on the main thread via `DispatchQueue.main.async { self.isKeyDown = true/false }`. There is no synchronization protecting these reads. If two key events arrive on the tap thread before the main queue processes the first async write, `isKeyDown` will still be `false` for both checks, causing duplicate `onKeyDown` callbacks (or conversely, duplicate `onKeyUp` callbacks). The `stateLock` exists but is only used for startup state, not for `isKeyDown`.

## HotkeyManager.swift:190 -- Data race on `onKeyDown`/`onKeyUp` closures
**Severity**: medium
The `onKeyDown` and `onKeyUp` closure properties are set from the `@MainActor` context in `RecordingCoordinator.start()` (line 76-84 of RecordingCoordinator.swift) but read (invoked) on the event tap background thread in `handleModifierOnlyEvent` (line 190: `onKeyDown?()`) and `handleRegularEvent` (lines 215, 225, 236). These are unsynchronized cross-thread accesses to mutable properties, which is a data race under the Swift memory model.

## HistoryStore.swift:31 -- Deleting records does not delete associated audio files from disk
**Severity**: medium
`deleteRecord(id:)`, `deleteRecords(ids:)`, and `clearAll()` remove `TranscriptionRecord` entries from the JSON store but never delete the corresponding audio WAV files from `~/Library/Application Support/McWhisper/Audio/`. The files referenced by `TranscriptionRecord.audioFileName` become orphaned on disk and accumulate indefinitely. Users who delete recordings to reclaim space will not see disk usage decrease.

## ModelDownloader.swift:171 -- Partial model downloads appear as complete after app restart
**Severity**: medium
When a model download fails mid-way with a non-cancellation error (e.g., network timeout on the 3rd of 10 files), the partially downloaded model directory is not cleaned up (lines 171-176 only set the state to `.failed` but leave the directory). On next app launch, `refreshStates()` calls `isModelDownloaded()` which checks for directory existence (line 73-76) and returns `true` for the incomplete directory, setting the state to `.downloaded`. The user sees the model as ready, but loading it will fail because required files are missing.

## SettingsWindowController.swift:41 -- Hotkey manager restart is async, creating a gap with no hotkey listening
**Severity**: low
`windowWillClose` is marked `nonisolated` and dispatches the hotkey manager restart via `Task { @MainActor in ... }` (line 42). This means the `hotkeyManager.start()` call does not execute immediately when the window closes but is deferred to a future main-actor task. Between `show()` calling `hotkeyManager.stop()` (line 19) and the deferred `start()` executing, the push-to-talk hotkey is inactive. If the user closes the settings window and immediately tries to use the hotkey, it will not respond until the async task runs.
