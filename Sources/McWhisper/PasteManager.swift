import AppKit

/// Manages capturing the frontmost application and pasting text into it.
@MainActor
final class PasteManager {
    /// The frontmost application captured before recording began.
    private(set) var targetApplication: NSRunningApplication?

    /// Captures the current frontmost application for later paste targeting.
    func captureTarget() {
        targetApplication = NSWorkspace.shared.frontmostApplication
    }

    /// Clears the captured target application.
    func clearTarget() {
        targetApplication = nil
    }

    /// Re-focuses the captured app, writes text to the system pasteboard, and simulates Cmd+V to paste.
    func paste(_ text: String) {
        targetApplication?.activate()

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
