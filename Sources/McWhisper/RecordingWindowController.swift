import AppKit
import SwiftUI

/// Manages a floating NSPanel that displays recording state.
/// The panel uses `.nonactivatingPanel` style so it floats above all apps
/// without stealing focus from the active application.
/// Animates appearance/disappearance with a fade, and persists window
/// position to UserDefaults so it restores on next show.
@MainActor
final class RecordingWindowController {
    private(set) var panel: NSPanel?

    static let fadeDuration: TimeInterval = 0.2

    /// Creates and shows the floating panel with a fade-in animation.
    /// Pass a coordinator to host `RecordingView` inside the panel.
    func show(coordinator: RecordingCoordinator? = nil) {
        if panel != nil { return }

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.level = .floating
        newPanel.isFloatingPanel = true
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = true
        newPanel.titlebarAppearsTransparent = true
        newPanel.titleVisibility = .hidden
        newPanel.backgroundColor = .windowBackgroundColor

        if let coordinator = coordinator {
            let hostingView = NSHostingView(rootView: RecordingView(coordinator: coordinator))
            newPanel.contentView = hostingView
        }

        restorePosition(newPanel)

        newPanel.alphaValue = 0
        newPanel.orderFront(nil)
        panel = newPanel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeDuration
            newPanel.animator().alphaValue = 1
        }
    }

    /// Hides the panel with a fade-out animation and releases it.
    func hide() {
        guard let currentPanel = panel else { return }

        savePosition(currentPanel)
        panel = nil

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.fadeDuration
            currentPanel.animator().alphaValue = 0
        }, completionHandler: {
            Task { @MainActor in
                currentPanel.orderOut(nil)
            }
        })
    }

    /// Whether the panel is currently visible on screen.
    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Position persistence

    func savePosition(_ window: NSPanel) {
        let origin = window.frame.origin
        AppSettings.panelPositionX = origin.x
        AppSettings.panelPositionY = origin.y
        AppSettings.hasSavedPanelPosition = true
    }

    func restorePosition(_ window: NSPanel) {
        if AppSettings.hasSavedPanelPosition {
            let point = NSPoint(
                x: AppSettings.panelPositionX,
                y: AppSettings.panelPositionY
            )
            window.setFrameOrigin(point)
        } else {
            centerOnScreen(window)
        }
    }

    // MARK: - Private

    private func centerOnScreen(_ window: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - window.frame.width / 2
        let y = screenFrame.midY - window.frame.height / 2
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
