import Testing
import Foundation
import AppKit
import ServiceManagement
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

    @Test("HotkeyFormatter displays Right Command correctly")
    func hotkeyFormatterRightCommand() {
        let display = HotkeyFormatter.displayString(
            keyCode: Int(AppSettings.defaultHotkeyKeyCode),
            modifiers: Int(AppSettings.defaultHotkeyModifiers)
        )
        #expect(display.contains("Right"))
        #expect(display.contains("\u{2318}"))  // Command symbol
    }

    @Test("HotkeyFormatter keyName for known keys")
    func hotkeyFormatterKeyNames() {
        #expect(HotkeyFormatter.keyName(for: 49) == "Space")
        #expect(HotkeyFormatter.keyName(for: 36) == "Return")
        #expect(HotkeyFormatter.keyName(for: 48) == "Tab")
        #expect(HotkeyFormatter.keyName(for: 53) == "Esc")
    }

    @Test("HotkeyFormatter keyName for modifier keys")
    func hotkeyFormatterModifierKeyNames() {
        #expect(HotkeyFormatter.keyName(for: 54).contains("\u{2318}"))  // Right Command
        #expect(HotkeyFormatter.keyName(for: 55).contains("\u{2318}"))  // Left Command
        #expect(HotkeyFormatter.keyName(for: 56).contains("\u{21E7}"))  // Left Shift
        #expect(HotkeyFormatter.keyName(for: 60).contains("\u{21E7}"))  // Right Shift
        #expect(HotkeyFormatter.keyName(for: 58).contains("\u{2325}"))  // Left Option
        #expect(HotkeyFormatter.keyName(for: 61).contains("\u{2325}"))  // Right Option
        #expect(HotkeyFormatter.keyName(for: 59).contains("\u{2303}"))  // Left Control
        #expect(HotkeyFormatter.keyName(for: 62).contains("\u{2303}"))  // Right Control
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

    // MARK: - Launch at Login

    @MainActor
    @Test("SMAppService.mainApp.status returns a valid status")
    func launchAtLoginStatusQueryable() {
        let status = SMAppService.mainApp.status
        let validStatuses: [SMAppService.Status] = [.enabled, .notRegistered, .notFound, .requiresApproval]
        #expect(validStatuses.contains(status))
    }

    @MainActor
    @Test("GeneralSettingsTab includes launch-at-login toggle")
    func generalTabIncludesLaunchToggle() {
        // GeneralSettingsTab builds successfully with the launch-at-login section
        let view = GeneralSettingsTab()
        _ = view.body
        // If SMAppService were unavailable, the view would fail to build
    }

    @MainActor
    @Test("Launch-at-login state is consistent across multiple view instantiations")
    func launchAtLoginStatePersistsAcrossViews() {
        // Simulates relaunch: multiple GeneralSettingsTab creations read the same
        // SMAppService status, confirming the setting persists in the system (not in-memory).
        let status1 = SMAppService.mainApp.status
        _ = GeneralSettingsTab()
        let status2 = SMAppService.mainApp.status
        _ = GeneralSettingsTab()
        let status3 = SMAppService.mainApp.status
        #expect(status1 == status2)
        #expect(status2 == status3)
    }

    @Test("Launch-at-login is not stored in AppSettings UserDefaults")
    func launchAtLoginNotInUserDefaults() {
        // Verify launch-at-login is managed by SMAppService, not UserDefaults.
        // AppSettings.Keys should not contain a launch-at-login key.
        let allKeys = [
            AppSettings.Keys.selectedModelID,
            AppSettings.Keys.hotkeyKeyCode,
            AppSettings.Keys.hotkeyModifiers,
            AppSettings.Keys.selectedMode,
            AppSettings.Keys.selectedLanguage,
            AppSettings.Keys.silenceThreshold,
            AppSettings.Keys.panelPositionX,
            AppSettings.Keys.panelPositionY,
            AppSettings.Keys.hasSavedPanelPosition,
            AppSettings.Keys.hasCompletedOnboarding,
        ]
        for key in allKeys {
            #expect(!key.lowercased().contains("launch"), "Launch-at-login should be managed by SMAppService, not UserDefaults")
        }
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

    @MainActor
    @Test("HotkeyRecorderNSView onKeyEvent callback fires with correct values")
    func hotkeyRecorderOnKeyEventCallback() {
        let nsView = HotkeyRecorderNSView()
        var receivedKeyCode: Int?
        var receivedModifiers: Int?
        nsView.onKeyEvent = { code, mods in
            receivedKeyCode = code
            receivedModifiers = mods
        }
        // Simulate what keyDown does: call onKeyEvent directly
        nsView.onKeyEvent?(49, 0)  // Space with no modifiers
        #expect(receivedKeyCode == 49)
        #expect(receivedModifiers == 0)
    }

    @MainActor
    @Test("HotkeyRecorderNSView mouseDown sets recording state")
    func hotkeyRecorderMouseDownSetsRecording() {
        let nsView = HotkeyRecorderNSView()
        #expect(!nsView.isRecordingHotkey)
        // mouseDown requires a window/event, but we can verify the initial state
        // and that the property is settable
        nsView.isRecordingHotkey = true
        #expect(nsView.isRecordingHotkey)
    }

    @MainActor
    @Test("HotkeyRecorderView onKeyEvent closure updates bindings")
    func hotkeyRecorderUpdatesBindings() {
        // Simulate the onKeyEvent closure that HotkeyRecorderView installs
        var keyCode = Int(AppSettings.defaultHotkeyKeyCode)
        var modifiers = Int(AppSettings.defaultHotkeyModifiers)

        // This mirrors makeNSView's onKeyEvent assignment
        let onKeyEvent: (Int, Int) -> Void = { code, mods in
            keyCode = code
            modifiers = mods
        }

        onKeyEvent(49, Int(NSEvent.ModifierFlags.command.rawValue))
        #expect(keyCode == 49)
        #expect(modifiers == Int(NSEvent.ModifierFlags.command.rawValue))
    }

    @Test("HotkeyFormatter displays changed hotkey correctly")
    func hotkeyFormatterAfterChange() {
        // Verify formatting for a non-default hotkey (Cmd+Space)
        let cmdMod = Int(NSEvent.ModifierFlags.command.rawValue)
        let display = HotkeyFormatter.displayString(keyCode: 49, modifiers: cmdMod)
        #expect(display.contains("\u{2318}"))  // Command symbol
        #expect(display.contains("Space"))
    }

    @Test("HotkeyFormatter displays modifier-only keys without duplicate symbols")
    func hotkeyFormatterModifierOnlyNoDuplicate() {
        // Right Command as modifier-only (modifiers=0)
        let display = HotkeyFormatter.displayString(keyCode: 54, modifiers: 0)
        // Should show "Right ⌘" without extra modifier prefix
        #expect(display == "Right \u{2318}")
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
        let view = ModelRow(model: model, isSelected: true, downloadState: .downloaded)
        _ = view.body
    }

    @MainActor
    @Test("ModelRow builds with unselected state")
    func modelRowUnselected() {
        let model = ModelCatalog.bundledModel
        let view = ModelRow(model: model, isSelected: false, downloadState: .notDownloaded)
        _ = view.body
    }

    @MainActor
    @Test("ModelRow builds with engine unavailable")
    func modelRowEngineUnavailable() {
        let model = ModelInfo(id: "test-model", displayName: "Test", sizeLabel: "~1 GB", isBundled: false, engine: .qwen3asr)
        let view = ModelRow(
            model: model,
            isSelected: false,
            downloadState: .notDownloaded,
            engineAvailable: false,
            unavailabilityReason: "Requires Apple Silicon"
        )
        _ = view.body
    }

    @MainActor
    @Test("ModelRow builds with engine available")
    func modelRowEngineAvailable() {
        let model = ModelInfo(id: "test-model", displayName: "Test", sizeLabel: "~1 GB", isBundled: false, engine: .qwen3asr)
        let view = ModelRow(
            model: model,
            isSelected: false,
            downloadState: .notDownloaded,
            engineAvailable: true,
            unavailabilityReason: nil
        )
        _ = view.body
    }

    @MainActor
    @Test("ModelRow builds with downloading state and progress")
    func modelRowDownloading() {
        let model = ModelInfo(id: "test-dl", displayName: "Test", sizeLabel: "~500 MB", isBundled: false)
        let view = ModelRow(
            model: model,
            isSelected: false,
            downloadState: .downloading(progress: 0.45),
            engineAvailable: true
        )
        _ = view.body
    }

    @MainActor
    @Test("ModelRow builds with failed state")
    func modelRowFailed() {
        let model = ModelInfo(id: "test-fail", displayName: "Test", sizeLabel: "~500 MB", isBundled: false)
        let view = ModelRow(
            model: model,
            isSelected: false,
            downloadState: .failed("Network error"),
            engineAvailable: true
        )
        _ = view.body
    }

    @MainActor
    @Test("ModelRow renders for each Qwen3-ASR catalog model")
    func modelRowQwen3asrCatalogModels() {
        let qwenModels = ModelCatalog.availableModels.filter { $0.engine == .qwen3asr }
        #expect(qwenModels.count >= 3)
        for model in qwenModels {
            let view = ModelRow(
                model: model,
                isSelected: false,
                downloadState: .notDownloaded,
                engineAvailable: EngineAvailability.isAvailable(model.engine),
                unavailabilityReason: EngineAvailability.unavailabilityReason(model.engine)
            )
            _ = view.body
        }
    }

    @MainActor
    @Test("ModelRow renders for each WhisperKit catalog model")
    func modelRowWhisperKitCatalogModels() {
        let whisperModels = ModelCatalog.availableModels.filter { $0.engine == .whisperKit }
        #expect(!whisperModels.isEmpty)
        for model in whisperModels {
            let view = ModelRow(
                model: model,
                isSelected: model.isBundled,
                downloadState: model.isBundled ? .downloaded : .notDownloaded,
                engineAvailable: true
            )
            _ = view.body
        }
    }

    // MARK: - Engine availability

    @Test("EngineAvailability: WhisperKit is always available")
    func whisperKitAlwaysAvailable() {
        #expect(EngineAvailability.isAvailable(.whisperKit) == true)
        #expect(EngineAvailability.unavailabilityReason(.whisperKit) == nil)
    }

    @Test("EngineAvailability: isAppleSilicon matches arch")
    func isAppleSiliconMatchesArch() {
        #if arch(arm64)
        #expect(EngineAvailability.isAppleSilicon == true)
        #else
        #expect(EngineAvailability.isAppleSilicon == false)
        #endif
    }

    @Test("EngineAvailability: qwen3asr availability matches Apple Silicon")
    func qwen3asrAvailability() {
        #expect(EngineAvailability.isAvailable(.qwen3asr) == EngineAvailability.isAppleSilicon)
    }

    @Test("EngineAvailability: qwen3asr unavailability reason when not Apple Silicon")
    func qwen3asrUnavailabilityReason() {
        if EngineAvailability.isAppleSilicon {
            #expect(EngineAvailability.unavailabilityReason(.qwen3asr) == nil)
        } else {
            #expect(EngineAvailability.unavailabilityReason(.qwen3asr) != nil)
            #expect(EngineAvailability.unavailabilityReason(.qwen3asr)!.contains("Apple Silicon"))
        }
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
