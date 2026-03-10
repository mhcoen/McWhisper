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
        Task { @MainActor in
            if let hotkeyManager = self.hotkeyManager {
                try? hotkeyManager.start()
                self.hotkeyManager = nil
            }
        }
    }
}
