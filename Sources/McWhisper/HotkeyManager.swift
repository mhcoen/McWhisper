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

    /// Check whether a CGEvent matches the configured hotkey.
    func matches(_ event: CGEvent) -> Bool {
        let eventKeyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        guard eventKeyCode == keyCode else { return false }

        // Mask to only the modifier bits we care about (shift, control, option, command).
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
        // Swallow the event so it doesn't reach the active app.
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
        // For modifier-only keys or when the modifier is released before the key,
        // detect key-up via flags change.
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
