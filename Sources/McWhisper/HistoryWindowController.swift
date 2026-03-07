import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController {
    static let shared = HistoryWindowController()

    private var window: NSWindow?

    func show(historyStore: HistoryStore) {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let view = HistoryView(historyStore: historyStore)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(x: 0, y: 0, width: 480, height: 400)

        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Recording History"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = window
    }
}

struct HistoryView: View {
    let historyStore: HistoryStore

    var body: some View {
        VStack {
            if historyStore.records.isEmpty {
                Text("No recordings yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(historyStore.records.reversed()) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.processedText.isEmpty ? record.rawText : record.processedText)
                            .lineLimit(3)
                        HStack {
                            Text(record.date, style: .date)
                            Text(record.date, style: .time)
                            Text("·")
                            Text(record.mode.displayName)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(minWidth: 300, minHeight: 200)
    }
}
