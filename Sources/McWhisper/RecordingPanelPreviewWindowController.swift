import AppKit
import SwiftUI

@MainActor
final class RecordingPanelPreviewWindowController {
    static let shared = RecordingPanelPreviewWindowController()

    private var window: NSWindow?

    func show() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let contentView = NSHostingView(rootView: RecordingPanelPreviewView())
        contentView.frame = NSRect(x: 0, y: 0, width: 320, height: 140)

        let window = NSWindow(
            contentRect: contentView.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "McWhisper Recording Panel"
        window.contentView = contentView
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = window
    }
}

struct RecordingPanelPreviewView: View {
    private static let sampleLevels: [Float] = [
        0.08, 0.12, 0.22, 0.35, 0.48, 0.62, 0.78, 0.71, 0.55, 0.39,
        0.24, 0.14, 0.08, 0.11, 0.19, 0.33, 0.52, 0.69, 0.83, 0.74,
        0.58, 0.42, 0.27, 0.16, 0.09, 0.13, 0.21, 0.29, 0.18, 0.1
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WaveformView(levels: Self.sampleLevels)
                .frame(height: 32)
            Text("Recording from the panel preview for appshot.")
                .font(.system(.body, design: .rounded))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
    }
}
