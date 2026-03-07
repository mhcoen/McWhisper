import Testing
import Foundation
import AppKit
@testable import McWhisper

@Suite("SettingsView")
struct SettingsViewTests {

    // MARK: - Tab structure

    @MainActor
    @Test("SettingsView builds with tabs")
    func settingsViewBuilds() {
        let view = SettingsView()
        _ = view.body
    }

    @Test("SettingsTab has all three cases")
    func settingsTabCases() {
        let tabs: [SettingsTab] = [.general, .models, .modes]
        #expect(tabs.count == 3)
        #expect(Set(tabs).count == 3)
    }

    // MARK: - General tab

    @MainActor
    @Test("GeneralSettingsTab builds")
    func generalTabBuilds() {
        let view = GeneralSettingsTab()
        _ = view.body
    }

    @Test("HotkeyFormatter displays Option+Space correctly")
    func hotkeyFormatterOptionSpace() {
        let display = HotkeyFormatter.displayString(
            keyCode: Int(AppSettings.defaultHotkeyKeyCode),
            modifiers: Int(AppSettings.defaultHotkeyModifiers)
        )
        #expect(display.contains("Space"))
        #expect(display.contains("\u{2325}"))  // Option symbol
    }

    @Test("HotkeyFormatter keyName for known keys")
    func hotkeyFormatterKeyNames() {
        #expect(HotkeyFormatter.keyName(for: 49) == "Space")
        #expect(HotkeyFormatter.keyName(for: 36) == "Return")
        #expect(HotkeyFormatter.keyName(for: 48) == "Tab")
        #expect(HotkeyFormatter.keyName(for: 53) == "Esc")
    }

    @Test("HotkeyFormatter includes modifier symbols")
    func hotkeyFormatterModifiers() {
        let cmdShift = Int(NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.shift.rawValue)
        let display = HotkeyFormatter.displayString(keyCode: 49, modifiers: cmdShift)
        #expect(display.contains("\u{21E7}"))  // Shift
        #expect(display.contains("\u{2318}"))  // Command
    }

    @Test("HotkeyFormatter with no modifiers")
    func hotkeyFormatterNoModifiers() {
        let display = HotkeyFormatter.displayString(keyCode: 49, modifiers: 0)
        #expect(display == "Space")
    }

    // MARK: - Hotkey Recorder

    @MainActor
    @Test("HotkeyRecorderView can be constructed")
    func hotkeyRecorderViewConstructs() {
        var keyCode = Int(AppSettings.defaultHotkeyKeyCode)
        var modifiers = Int(AppSettings.defaultHotkeyModifiers)
        let view = HotkeyRecorderView(
            keyCode: .init(get: { keyCode }, set: { keyCode = $0 }),
            modifiers: .init(get: { modifiers }, set: { modifiers = $0 })
        )
        let coordinator = view.makeCoordinator()
        _ = coordinator
    }

    @MainActor
    @Test("HotkeyRecorderNSView initial state")
    func hotkeyRecorderNSViewInitialState() {
        let nsView = HotkeyRecorderNSView()
        #expect(nsView.isRecordingHotkey == false)
        #expect(nsView.acceptsFirstResponder == true)
        #expect(nsView.displayText == "")
    }

    @MainActor
    @Test("HotkeyRecorderNSView intrinsic content size")
    func hotkeyRecorderNSViewIntrinsicSize() {
        let nsView = HotkeyRecorderNSView()
        let size = nsView.intrinsicContentSize
        #expect(size.width == HotkeyRecorderNSView.viewWidth)
        #expect(size.height == HotkeyRecorderNSView.viewHeight)
    }

    @MainActor
    @Test("HotkeyRecorderNSView view dimensions are positive")
    func hotkeyRecorderNSViewDimensions() {
        #expect(HotkeyRecorderNSView.viewWidth > 0)
        #expect(HotkeyRecorderNSView.viewHeight > 0)
    }

    // MARK: - Models tab

    @MainActor
    @Test("ModelsSettingsTab builds")
    func modelsTabBuilds() {
        let view = ModelsSettingsTab()
        _ = view.body
    }

    @MainActor
    @Test("ModelRow builds with selected state")
    func modelRowSelected() {
        let model = ModelCatalog.bundledModel
        let view = ModelRow(model: model, isSelected: true)
        _ = view.body
    }

    @MainActor
    @Test("ModelRow builds with unselected state")
    func modelRowUnselected() {
        let model = ModelCatalog.bundledModel
        let view = ModelRow(model: model, isSelected: false)
        _ = view.body
    }

    // MARK: - Modes tab

    @MainActor
    @Test("ModesSettingsTab builds")
    func modesTabBuilds() {
        let view = ModesSettingsTab()
        _ = view.body
    }

    @MainActor
    @Test("ModeRow builds with selected state")
    func modeRowSelected() {
        let view = ModeRow(mode: .voice, isSelected: true, onSelect: {})
        _ = view.body
    }

    @MainActor
    @Test("ModeRow builds with unselected state")
    func modeRowUnselected() {
        let view = ModeRow(mode: .voice, isSelected: false, onSelect: {})
        _ = view.body
    }

    @MainActor
    @Test("ModeRow builds for custom mode")
    func modeRowCustom() {
        let mode = TranscriptionMode.custom(name: "Test", prompt: "Do a thing")
        let view = ModeRow(mode: mode, isSelected: false, onSelect: {})
        _ = view.body
    }

    @MainActor
    @Test("ModeEditSheet builds for new mode")
    func modeEditSheetNew() {
        var name = ""
        var prompt = ""
        let view = ModeEditSheet(
            name: .init(get: { name }, set: { name = $0 }),
            prompt: .init(get: { prompt }, set: { prompt = $0 }),
            isEditing: false,
            onSave: {},
            onCancel: {}
        )
        _ = view.body
    }

    @MainActor
    @Test("ModeEditSheet builds for editing mode")
    func modeEditSheetEditing() {
        var name = "My Mode"
        var prompt = "Summarize"
        let view = ModeEditSheet(
            name: .init(get: { name }, set: { name = $0 }),
            prompt: .init(get: { prompt }, set: { prompt = $0 }),
            isEditing: true,
            onSave: {},
            onCancel: {}
        )
        _ = view.body
    }
}
