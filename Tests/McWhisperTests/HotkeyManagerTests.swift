import Testing
import Foundation
import Cocoa
import IOKit.hidsystem
@testable import McWhisper

@Suite("HotkeyManager", .serialized)
struct HotkeyManagerTests {

    @Test("Initial state: isKeyDown is false")
    func initialState() {
        let manager = HotkeyManager()
        #expect(!manager.isKeyDown)
    }

    @Test("Initial state: callbacks are nil")
    func initialCallbacks() {
        let manager = HotkeyManager()
        #expect(manager.onKeyDown == nil)
        #expect(manager.onKeyUp == nil)
    }

    @Test("keyCode reads from AppSettings")
    func keyCodeFromSettings() {
        let manager = HotkeyManager()
        #expect(manager.keyCode == AppSettings.hotkeyKeyCode)
    }

    @Test("modifiers reads from AppSettings")
    func modifiersFromSettings() {
        let manager = HotkeyManager()
        #expect(manager.modifiers == AppSettings.hotkeyModifiers)
    }

    @Test("Default hotkey is Right Command")
    func defaultHotkey() {
        let manager = HotkeyManager()
        // Right Command = keycode 54
        #expect(manager.keyCode == 54)
        #expect(manager.modifiers == 0)
    }

    @Test("Default hotkey is a modifier-only key")
    func defaultIsModifierOnly() {
        let manager = HotkeyManager()
        #expect(manager.isModifierOnlyKey)
    }

    @Test("HotkeyManagerError cases are distinct")
    func errorEquality() {
        #expect(HotkeyManagerError.accessibilityNotGranted == HotkeyManagerError.accessibilityNotGranted)
        #expect(HotkeyManagerError.eventTapCreationFailed == HotkeyManagerError.eventTapCreationFailed)
        #expect(HotkeyManagerError.accessibilityNotGranted != HotkeyManagerError.eventTapCreationFailed)
    }

    @Test("stop() resets isKeyDown to false")
    func stopResetsState() {
        let manager = HotkeyManager()
        manager.stop()
        #expect(!manager.isKeyDown)
    }

    @Test("stop() is safe to call multiple times")
    func doubleStop() {
        let manager = HotkeyManager()
        manager.stop()
        manager.stop()
        #expect(!manager.isKeyDown)
    }

    @Test("Conforms to ObservableObject")
    func observableConformance() {
        let manager = HotkeyManager()
        _ = manager.objectWillChange
    }

    @Test("Callbacks can be set and cleared")
    func callbackSetClear() {
        let manager = HotkeyManager()
        var called = false
        manager.onKeyDown = { called = true }
        manager.onKeyDown?()
        #expect(called)

        manager.onKeyDown = nil
        #expect(manager.onKeyDown == nil)
    }

    // MARK: - Dynamic hotkey change

    @Suite("Hotkey Settings Changes", .serialized)
    struct HotkeySettingsChangeTests {
        @Test("keyCode reflects AppSettings changes dynamically")
        func keyCodeReflectsSettingsChange() {
            let manager = HotkeyManager()
            let original = AppSettings.hotkeyKeyCode
            defer { AppSettings.hotkeyKeyCode = original }

            AppSettings.hotkeyKeyCode = 56
            #expect(manager.keyCode == 56)

            AppSettings.hotkeyKeyCode = 49
            #expect(manager.keyCode == 49)
        }

        @Test("modifiers reflects AppSettings changes dynamically")
        func modifiersReflectsSettingsChange() {
            let manager = HotkeyManager()
            let original = AppSettings.hotkeyModifiers
            defer { AppSettings.hotkeyModifiers = original }

            let cmdMod = Int(NSEvent.ModifierFlags.command.rawValue)
            AppSettings.hotkeyModifiers = cmdMod
            #expect(manager.modifiers == cmdMod)
        }

        @Test("isModifierOnlyKey updates when hotkey changes to regular key")
        func isModifierOnlyKeyUpdatesOnChange() {
            let manager = HotkeyManager()
            let originalKeyCode = AppSettings.hotkeyKeyCode
            defer { AppSettings.hotkeyKeyCode = originalKeyCode }

            #expect(manager.isModifierOnlyKey)

            AppSettings.hotkeyKeyCode = 49
            #expect(!manager.isModifierOnlyKey)

            AppSettings.hotkeyKeyCode = 58
            #expect(manager.isModifierOnlyKey)
        }

        @Test("matches checks keycode from current settings")
        func matchesUsesCurrentSettings() {
            let manager = HotkeyManager()
            let originalKeyCode = AppSettings.hotkeyKeyCode
            let originalMods = AppSettings.hotkeyModifiers
            defer {
                AppSettings.hotkeyKeyCode = originalKeyCode
                AppSettings.hotkeyModifiers = originalMods
            }

            AppSettings.hotkeyKeyCode = 54
            AppSettings.hotkeyModifiers = 0
            #expect(manager.keyCode == 54)
            #expect(manager.isModifierOnlyKey)

            AppSettings.hotkeyKeyCode = 56
            #expect(manager.keyCode == 56)
            #expect(manager.isModifierOnlyKey)
        }

        @Test("Right Command press detection uses side-specific flags")
        func rightCommandUsesSideSpecificFlags() {
            let manager = HotkeyManager()
            let originalKeyCode = AppSettings.hotkeyKeyCode
            defer { AppSettings.hotkeyKeyCode = originalKeyCode }

            AppSettings.hotkeyKeyCode = 54

            let genericCommand = UInt64(NSEvent.ModifierFlags.command.rawValue)
            let leftCommand = genericCommand | UInt64(NX_DEVICELCMDKEYMASK)
            let rightCommand = genericCommand | UInt64(NX_DEVICERCMDKEYMASK)

            #expect(!manager.isModifierPressed(rawFlags: genericCommand))
            #expect(!manager.isModifierPressed(rawFlags: leftCommand))
            #expect(manager.isModifierPressed(rawFlags: rightCommand))
        }

        @Test("Left Control uses side-specific flags")
        func leftControlUsesSideSpecificFlags() {
            let manager = HotkeyManager()
            let originalKeyCode = AppSettings.hotkeyKeyCode
            defer { AppSettings.hotkeyKeyCode = originalKeyCode }

            AppSettings.hotkeyKeyCode = 59

            let genericControl = UInt64(NSEvent.ModifierFlags.control.rawValue)
            let leftControl = genericControl | UInt64(NX_DEVICELCTLKEYMASK)
            let rightControl = genericControl | UInt64(NX_DEVICERCTLKEYMASK)

            #expect(manager.isModifierPressed(rawFlags: leftControl))
            #expect(!manager.isModifierPressed(rawFlags: rightControl))
        }
    }
}
