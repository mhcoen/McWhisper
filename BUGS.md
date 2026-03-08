# Bugs

## RecordingWindowController.swift:18 -- show() is a no-op during hide() fade-out animation
**Severity**: medium
`hide()` starts a 0.2s fade-out animation and only sets `panel = nil` in the completion handler. `show()` checks `if panel != nil { return }` and exits early if a panel exists. During the fade-out window, calling `show()` is silently ignored. This is triggered in two ways: (1) If the user presses the hotkey within 0.2s of the panel hiding after a successful paste, the recording starts but no panel appears. (2) In `RecordingCoordinator.handleKeyDown()`, when `state == .error`, `windowController.hide()` and `windowController.show(coordinator: self)` are called in the same synchronous execution — `show()` always fails because the fade-out hasn't completed yet, so the panel never appears for the new recording.

## SettingsView.swift:307 -- previousModelID initialized to default instead of current selection
**Severity**: low
`@State private var previousModelID: String = AppSettings.defaultModelID` initializes to the hardcoded default (`"openai_whisper-base"`), not the user's current `selectedModelID` from AppStorage. If the user has a non-default model active (e.g. `"openai_whisper-small"`) and tries to select a non-downloaded model from the picker, the `onChange` handler reverts `selectedModelID` to `previousModelID` — which is the default model, not their actual current model. This silently switches their active model.
