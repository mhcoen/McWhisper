import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var hotkeyManager: HotkeyManager?

    func show(hotkeyManager: HotkeyManager? = nil) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        self.hotkeyManager = hotkeyManager
        hotkeyManager?.stop()

        let view = SettingsView()
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 520, height: 400)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = window
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            if let hotkeyManager = self.hotkeyManager {
                do {
                    try hotkeyManager.start()
                } catch {
                    print("[McWhisper] Failed to restart hotkey listener: \(error)")
                    let alert = NSAlert()
                    alert.messageText = "Hotkey Unavailable"
                    alert.informativeText = "The push-to-talk hotkey could not be restarted. Please check that Accessibility permission is granted in System Settings > Privacy & Security > Accessibility."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
                self.hotkeyManager = nil
            }
        }
    }
}
