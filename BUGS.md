# Bugs

## Sources/McWhisper/ModelDownloader.swift:145 -- Path traversal via unsanitized HuggingFace API file paths
**Severity**: high
The `file.path` used to construct `destURL` comes directly from the HuggingFace API response (`rfilename` field) without any sanitization. A malicious or compromised HuggingFace repository could return filenames containing `../` sequences (e.g., `../../.ssh/authorized_keys`), causing `modelDir.appendingPathComponent(file.path)` to resolve to a path outside the intended model directory. Line 146 then creates intermediate directories and line 150 moves the downloaded file to that location, enabling arbitrary file writes anywhere the user has permission. This affects both WhisperKit and qwen3-asr model downloads.

## Sources/McWhisper/HotkeyManager.swift:182 -- Data race on @Published isKeyDown from background thread
**Severity**: medium
`handleModifierOnlyEvent` and `handleRegularEvent` directly mutate `@Published var isKeyDown` from the event tap callback thread (a background thread created at line 54). The `@Published` property wrapper is not thread-safe and its `objectWillChange` publisher can be observed on the main thread. While the current code doesn't directly observe `HotkeyManager` in SwiftUI views, the `onKeyDown`/`onKeyUp` closures are also invoked on this background thread (lines 184, 192, 205, 213, 221), meaning any non-thread-safe work in those closures is a data race. The `RecordingCoordinator` mitigates this by wrapping callbacks in `DispatchQueue.main.async`, but `isKeyDown` itself is still mutated unsafely.

## Sources/McWhisper/SettingsWindowController.swift:44 -- Hotkey listener silently fails to restart after closing Settings
**Severity**: medium
In `windowWillClose`, the hotkey manager restart uses `try? hotkeyManager.start()`, silently swallowing any error. If Accessibility permission was revoked while Settings was open, or if the event tap fails to create for any other reason, the push-to-talk hotkey silently stops working with no user-visible indication. The user would have no way to know their hotkey is dead without manually testing it.

## Sources/McWhisper/HotkeyManager.swift:235 -- Unmanaged.passUnretained pointer race with async stop()
**Severity**: low
`runEventTapLoop` passes an unretained pointer to `self` via `Unmanaged.passUnretained(self).toOpaque()` as the event tap's `userInfo`. The `stop()` method tears down the tap asynchronously (posting a block to the tap's run loop via `CFRunLoopPerformBlock`, then calling `CFRunLoopStop`), but does not synchronously wait for the tap thread to exit. There is a race window where the C callback `hotkeyCallback` could fire and dereference the unretained pointer after `deinit` has begun or completed. In practice this is mitigated because `HotkeyManager` is owned by `RecordingCoordinator` which lives for the app's lifetime, but it remains a use-after-free risk if the ownership model ever changes.
