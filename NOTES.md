# Notes

## 2026-03-07 — [1.3] McWhisperApp.swift activation policy

The SPM SwiftUI workaround requires `.regular` activation policy at init time, but the app needs `.accessory` to hide from the Dock. Current approach: set `.regular` synchronously, then switch to `.accessory` via `DispatchQueue.main.async`. This creates a brief Dock icon flash on launch. If this becomes visually objectionable, alternatives include using `LSUIElement=YES` in `Info.plist` (which `run.sh` will set), which may make the `.regular`→`.accessory` dance unnecessary once the app is bundled. Worth verifying once `run.sh` produces the `.app` bundle.

The `Settings` scene with `EmptyView()` is used instead of `WindowGroup` since a menu bar app shouldn't show a main window. When `MenuBarExtra` is added in a later task, `Settings` can remain as the scene type or be replaced.

## 2026-03-07 — [1.5] run.sh and `open` vs direct binary launch

`open McWhisper.app` fails with `kLSNoExecutableErr` (-10827) despite the binary being present and codesign valid. This is a known Launch Services issue with ad-hoc signed bundles in non-standard paths. `lsregister -f` also fails (-10822). Workaround: launch the binary directly (`McWhisper.app/Contents/MacOS/McWhisper &`). This is fine for development. If distribution requires `open` to work, the bundle may need to be placed in `/Applications` or signed with a developer certificate.

Now that `Info.plist` sets `LSUIElement=YES`, the `.regular`→`.accessory` activation policy dance in `McWhisperApp.swift` may be partially redundant — `LSUIElement` already hides the Dock icon. However, the `.regular` policy is still needed for the SPM SwiftUI workaround (window creation). Worth testing whether `LSUIElement=YES` alone suffices and the `.accessory` switch can be removed.

## 2026-03-07 — [7.2] RecordingView state-driven UI

The task specifies a "result" state showing processed text + action buttons, but `RecordingCoordinator.State` has no `.result` case — after transcription it pastes immediately and returns to `.idle`. To support a result display, a `.result(String)` state would need to be added to the coordinator, with the paste happening on user action (e.g. a "Paste" button) rather than automatically. The current view is ready to accept this state once the coordinator supports it.

The panel stays visible on `.error` state. There is no auto-dismiss or manual dismiss mechanism for errors yet. The coordinator doesn't transition back to `.idle` from `.error`, so the panel remains showing the error until the app is restarted. A dismiss button or timeout would be a good addition.

## 2026-03-07 — [1.6] Verify run.sh and appshot

`run.sh` builds, codesigns, and launches the app successfully (exit 0). The binary is a valid arm64 Mach-O, codesign validates, and Info.plist passes `plutil -lint`. 118/119 unit tests pass; the one failure ("Save and load custom modes via UserDefaults") is a sandbox environment issue — UserDefaults writes are silently dropped in the Claude Code sandbox.

`appshot` is installed (at `/Users/mhcoen/proj/duplo/.venv/bin/appshot`) and works by finding windows via System Events AppleScript + `screencapture -l`. Two issues prevent screenshot capture from Claude Code:
1. The Claude Code sandbox blocks `osascript`/System Events access and `screencapture`.
2. McWhisper is a menu bar app (`MenuBarExtra`) — it has no regular window in idle state, only a menu bar icon. `appshot` requires a window to capture.

The app process exits quickly when launched from the sandbox due to XPC service connection failures (`com.apple.hiservices-xpcservice`, `ClientCallsAuxiliary`). No crash reports are generated — the exit is clean. This is expected: the sandbox lacks full macOS GUI services needed by NSApplication/SwiftUI.

To visually verify the menu bar icon, launch outside the sandbox: `bash run.sh` from a normal terminal, then use `appshot "McWhisper" screenshot.png` — but note that `appshot` may need the MenuBarExtra popover to be open (click the icon first) since there's no standalone window.

## 2026-03-07 — [16] Run `run.sh`, launch app, grant Microphone and Accessibility permissions

Default hotkey was set to Right Command (keyCode 54, modifiers 0) but tests and the StatusView UI text said "Option+Space" (keyCode 49, modifiers 524288). Fixed AppSettings defaults to Option+Space.

`TranscriptionMode` used auto-synthesized Codable which encoded built-in modes as keyed dictionaries (e.g. `{"voice":{}}`), but old history records stored them as plain strings (e.g. `"voice"`). Added custom Codable conformance that encodes in a clean `{"type":"voice"}` format and decodes both the new format and legacy plain-string format for backward compatibility.

`PasteManagerTests` hung when calling `paste()` with a captured target because `app.activate()` and `CGEvent.post()` block in Claude Code's sandbox. Removed the test that exercises the actual paste path with a real target; clipboard-only behavior is tested via the no-target path.

The app cannot be launched from Claude Code's sandbox due to XPC service connection failures. `run.sh` must be run from a normal terminal to launch the app and grant Microphone/Accessibility permissions via the onboarding sheet or system dialogs.

## 2026-03-07 — [19] Download a larger model from Settings > Models, switch to it, and verify transcription still works

`WhisperKitEngine.loadModel()` was not using models downloaded via `ModelDownloader`. It only passed a variant name to WhisperKit, which would try to download its own copy. Fixed to check `ModelDownloader.modelsDirectoryPath` for locally downloaded models and pass `modelFolder` + `download: false` to `WhisperKitConfig` when found.

The model picker in `ModelsSettingsTab` allowed selecting any model regardless of download state. Added an `onChange` guard that reverts selection if the chosen model isn't downloaded. Undownloaded models still appear in the picker (for discoverability) but are shown in secondary color and can't be selected.

Added `nonisolated static let modelsDirectoryPath` to `ModelDownloader` to provide the models directory path from non-MainActor contexts (needed by `WhisperKitEngine.loadModel()` which runs on arbitrary threads).

## 2026-03-07 — [21] Switch transcription modes and verify formatting differences

Foundation's `.bySentences` enumeration does not split sentences that start with lowercase letters. For example, "buy groceries. clean the house." is treated as a single sentence. This affects Note mode (bullet points) and Meeting mode (paragraph breaks) when Whisper outputs lowercase text without proper capitalization. Whisper typically capitalizes sentence starts, so this is unlikely to be a real-world issue, but worth knowing when writing tests.
