import SwiftUI

struct MenuBarView: View {
    @ObservedObject var coordinator: RecordingCoordinator
    @AppStorage(AppSettings.Keys.selectedMode) private var selectedMode: String = AppSettings.defaultMode

    var body: some View {
        StatusView(coordinator: coordinator)

        Divider()

        ModeSelectorView(selectedMode: $selectedMode)

        Divider()

        Button("Recording History…") {
            HistoryWindowController.shared.show(
                historyStore: coordinator.historyStore,
                onRetranscribe: { [weak coordinator] record in
                    coordinator?.retranscribe(record: record)
                }
            )
        }

        Button("Settings…") {
            SettingsWindowController.shared.show(hotkeyManager: coordinator.hotkeyManager)
        }

        Divider()

        Button("Quit McWhisper") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

struct ModeSelectorView: View {
    @Binding var selectedMode: String

    var body: some View {
        let modes = TranscriptionMode.allModes()
        ForEach(modes, id: \.id) { mode in
            Button {
                selectedMode = mode.id
            } label: {
                HStack {
                    Text(mode.displayName)
                    Spacer()
                    if selectedMode == mode.id {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}
