import Testing
import Foundation
import Cocoa
@testable import McWhisper

@Suite("HotkeyManager")
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
}
