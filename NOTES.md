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

`run.sh` builds, codesigns, and launches the app successfully (exit 0). `appshot` is not installed on this system — `which appshot` returns nothing, pip install fails (not a PyPI package), not in homebrew. `screencapture` also fails inside the Claude Code sandbox (`could not create image from display`). Visual verification of the menu bar icon requires `appshot` to be installed first. The build and all 7 unit tests pass.

`Package.swift` currently has no WhisperKit or qwen3-asr-swift dependencies despite session history claiming [1.2] added them. They may have been removed to keep the scaffold building quickly, or the history is inaccurate. Will need to be re-added when transcription is implemented.
