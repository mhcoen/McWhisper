import SwiftUI

@main
struct McWhisperApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @StateObject private var coordinator = RecordingCoordinator()

    init() {
        // SPM SwiftUI workaround: must briefly be .regular so the window is created.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Switch to .accessory to hide from Dock (menu bar app).
        DispatchQueue.main.async {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }

    var body: some Scene {
        MenuBarExtra("McWhisper", systemImage: "waveform") {
            MenuBarView(coordinator: coordinator)
        }
    }
}

struct StatusView: View {
    @ObservedObject var coordinator: RecordingCoordinator

    var body: some View {
        Group {
            switch coordinator.state {
            case .idle:
                Text("Ready (Option+Space)")
                    .foregroundStyle(.secondary)
            case .recording:
                Text("Recording...")
                    .foregroundStyle(.red)
            case .transcribing:
                if coordinator.partialText.isEmpty {
                    Text("Transcribing...")
                        .foregroundStyle(.orange)
                } else {
                    Text(coordinator.partialText)
                        .lineLimit(3)
                }
            case .error(let message):
                Text(message)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .task {
            coordinator.start()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            let granted = await MicrophonePermission.request()
            if !granted {
                showMicDeniedAlert()
            }
        }

        if !HotkeyManager.hasAccessibilityPermission {
            showAccessibilityAlert()
        }
    }

    @MainActor
    private func showMicDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Access Required"
        alert.informativeText = "McWhisper needs microphone access to transcribe audio. Please grant access in System Settings > Privacy & Security > Microphone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Dismiss")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "McWhisper needs Accessibility access for the global push-to-talk hotkey. Please grant access in System Settings > Privacy & Security > Accessibility."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Dismiss")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
