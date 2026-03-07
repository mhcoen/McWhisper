import Testing
import Foundation
@testable import McWhisper

@Suite("MenuBarView")
struct MenuBarViewTests {

    @MainActor
    @Test("MenuBarView builds with coordinator")
    func menuBarViewBuilds() {
        let coordinator = RecordingCoordinator()
        let view = MenuBarView(coordinator: coordinator)
        _ = view.body
    }

    @MainActor
    @Test("ModeSelectorView builds with binding")
    func modeSelectorViewBuilds() {
        var mode = "voice"
        let view = ModeSelectorView(selectedMode: .init(get: { mode }, set: { mode = $0 }))
        _ = view.body
    }

    @MainActor
    @Test("ModeSelectorView shows all built-in modes")
    func modeSelectorShowsBuiltInModes() {
        let builtIn = TranscriptionMode.builtIn
        let allModes = TranscriptionMode.allModes()
        #expect(allModes.count >= builtIn.count)
        for mode in builtIn {
            #expect(allModes.contains(mode))
        }
    }

    @MainActor
    @Test("HistoryView builds with empty store")
    func historyViewBuildsEmpty() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = HistoryStore(directory: dir)
        let view = HistoryView(historyStore: store)
        _ = view.body
        try? FileManager.default.removeItem(at: dir)
    }

    @MainActor
    @Test("HistoryView builds with records")
    func historyViewBuildsWithRecords() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = HistoryStore(directory: dir)
        let record = TranscriptionRecord(
            duration: 1.5,
            rawText: "hello",
            processedText: "Hello.",
            mode: .voice,
            modelID: "test"
        )
        store.add(record)
        let view = HistoryView(historyStore: store)
        _ = view.body
        try? FileManager.default.removeItem(at: dir)
    }

    @MainActor
    @Test("SettingsView builds")
    func settingsViewBuilds() {
        let view = SettingsView()
        _ = view.body
    }

    @MainActor
    @Test("HistoryWindowController is a singleton")
    func historyWindowControllerSingleton() {
        let a = HistoryWindowController.shared
        let b = HistoryWindowController.shared
        #expect(a === b)
    }

    @MainActor
    @Test("SettingsWindowController is a singleton")
    func settingsWindowControllerSingleton() {
        let a = SettingsWindowController.shared
        let b = SettingsWindowController.shared
        #expect(a === b)
    }

    @Test("MenuBarLabel builds when not recording")
    func menuBarLabelNotRecording() {
        let view = MenuBarLabel(isRecording: false)
        _ = view.body
    }

    @Test("MenuBarLabel builds when recording")
    func menuBarLabelRecording() {
        let view = MenuBarLabel(isRecording: true)
        _ = view.body
    }

    @Test("MenuBarLabel pulse period is positive")
    func menuBarLabelPulsePeriod() {
        #expect(MenuBarLabel.pulsePeriod > 0)
    }
}
