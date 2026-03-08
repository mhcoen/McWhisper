import Cocoa
import Combine

enum HotkeyManagerError: Error, Equatable {
    case accessibilityNotGranted
    case eventTapCreationFailed
}

final class HotkeyManager: ObservableObject {
    @Published fileprivate(set) var isKeyDown: Bool = false

    var keyCode: Int { AppSettings.hotkeyKeyCode }
    var modifiers: Int { AppSettings.hotkeyModifiers }

    /// Called on the main thread when the hotkey is pressed.
    var onKeyDown: (() -> Void)?
    /// Called on the main thread when the hotkey is released.
    var onKeyUp: (() -> Void)?

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    deinit {
        stop()
    }

    /// Returns true if the app has Accessibility permission.
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant Accessibility permission via the system dialog.
    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Start listening for the configured hotkey via a CGEventTap.
    /// Throws if Accessibility permission is not granted or the event tap cannot be created.
    func start() throws {
        guard HotkeyManager.hasAccessibilityPermission else {
            throw HotkeyManagerError.accessibilityNotGranted
        }

        // Tear down any existing tap before creating a new one.
        stop()

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        // Store self as an Unmanaged pointer for the C callback.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: selfPtr
        ) else {
            throw HotkeyManagerError.eventTapCreationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
    }

    /// Stop listening for hotkey events.
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isKeyDown = false
    }

    /// Whether the configured hotkey is a modifier-only key (Command, Option, etc.).
    var isModifierOnlyKey: Bool {
        // Keycodes for modifier keys: 54=Right Cmd, 55=Left Cmd,
        // 56=Left Shift, 60=Right Shift, 58=Left Option, 61=Right Option,
        // 59=Left Control, 62=Right Control, 57=Caps Lock, 63=Fn
        let modifierKeyCodes: Set<Int> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        return modifierKeyCodes.contains(keyCode)
    }

    /// Check whether a CGEvent matches the configured hotkey.
    func matches(_ event: CGEvent) -> Bool {
        let eventKeyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard eventKeyCode == keyCode else { return false }

        if isModifierOnlyKey {
            // For modifier-only keys, just check keycode match (already done above).
            return true
        }

        // For regular keys, also check that the required modifier flags are held.
        let relevantMask: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        let eventMods = event.flags.intersection(relevantMask).rawValue
        return eventMods == UInt64(modifiers)
    }
}

/// C-function callback for the CGEventTap.
private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        // Re-enable the tap if the system disables it.
        if let tap = manager.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    default:
        break
    }

    if manager.isModifierOnlyKey {
        // Modifier-only hotkey: detect press/release via flagsChanged only.
        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }
        let eventKeyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard eventKeyCode == manager.keyCode else {
            return Unmanaged.passUnretained(event)
        }

        // Determine if the modifier is now pressed or released by checking
        // whether the corresponding flag is set.
        let modifierFlag: CGEventFlags
        switch manager.keyCode {
        case 54, 55: modifierFlag = .maskCommand
        case 56, 60: modifierFlag = .maskShift
        case 58, 61: modifierFlag = .maskAlternate
        case 59, 62: modifierFlag = .maskControl
        default: return Unmanaged.passUnretained(event)
        }

        let flagIsSet = event.flags.contains(modifierFlag)

        if flagIsSet && !manager.isKeyDown {
            DispatchQueue.main.async {
                manager.isKeyDown = true
                manager.onKeyDown?()
            }
        } else if !flagIsSet && manager.isKeyDown {
            DispatchQueue.main.async {
                manager.isKeyDown = false
                manager.onKeyUp?()
            }
        }
        return Unmanaged.passUnretained(event)
    }

    // Regular key hotkey: detect via keyDown/keyUp events.
    guard manager.matches(event) else {
        return Unmanaged.passUnretained(event)
    }

    switch type {
    case .keyDown:
        if !manager.isKeyDown {
            DispatchQueue.main.async {
                manager.isKeyDown = true
                manager.onKeyDown?()
            }
        }
        return nil

    case .keyUp:
        if manager.isKeyDown {
            DispatchQueue.main.async {
                manager.isKeyDown = false
                manager.onKeyUp?()
            }
        }
        return nil

    case .flagsChanged:
        // Regular key: detect modifier release while key was held.
        let relevantMask: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        let currentMods = event.flags.intersection(relevantMask).rawValue
        let expectedMods = UInt64(manager.modifiers)

        if manager.isKeyDown && currentMods != expectedMods {
            DispatchQueue.main.async {
                manager.isKeyDown = false
                manager.onKeyUp?()
            }
        }
        return Unmanaged.passUnretained(event)

    default:
        return Unmanaged.passUnretained(event)
    }
}
