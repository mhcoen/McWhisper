import AppKit
import SwiftUI

/// Non-activating panel that can still render SwiftUI content as key.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class RecordingWindowController {
    private(set) var panel: NSPanel?

    static let fadeDuration: TimeInterval = 0.2

    func show(coordinator: RecordingCoordinator? = nil) {
        if panel != nil { return }

        let newPanel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newPanel.styleMask.insert(.nonactivatingPanel)
        newPanel.level = .floating
        newPanel.isFloatingPanel = true
        newPanel.hidesOnDeactivate = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isMovableByWindowBackground = true
        newPanel.titlebarAppearsTransparent = true
        newPanel.titleVisibility = .hidden
        newPanel.title = "McWhisper"
        newPanel.backgroundColor = .windowBackgroundColor
        newPanel.isReleasedWhenClosed = false

        if let coordinator = coordinator {
            let hostingView = NSHostingView(rootView: RecordingView(coordinator: coordinator))
            newPanel.contentView = hostingView
        }

        restorePosition(newPanel)

        newPanel.alphaValue = 1
        panel = newPanel
        newPanel.orderFrontRegardless()
    }

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
            let savedOrigin = NSPoint(
                x: AppSettings.panelPositionX,
                y: AppSettings.panelPositionY
            )
            window.setFrameOrigin(clampedOrigin(for: window, savedOrigin: savedOrigin))
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

    private func clampedOrigin(for window: NSPanel, savedOrigin: NSPoint) -> NSPoint {
        let matchingScreen = NSScreen.screens.first { screen in
            let frame = screen.visibleFrame
            return frame.insetBy(dx: -window.frame.width, dy: -window.frame.height).contains(savedOrigin)
        } ?? NSScreen.main

        guard let matchingScreen else { return savedOrigin }

        let frame = matchingScreen.visibleFrame
        let minX = frame.minX
        let maxX = frame.maxX - window.frame.width
        let minY = frame.minY
        let maxY = frame.maxY - window.frame.height

        return NSPoint(
            x: min(max(savedOrigin.x, minX), maxX),
            y: min(max(savedOrigin.y, minY), maxY)
        )
    }
}
