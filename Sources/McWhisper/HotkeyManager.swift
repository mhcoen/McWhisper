import Cocoa
import Combine
import IOKit.hidsystem

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
    private var tapRunLoop: CFRunLoop?
    private var tapThread: Thread?
    private let setupSemaphore = DispatchSemaphore(value: 0)
    private let stateLock = NSLock()
    private var startupError: HotkeyManagerError?

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

    /// Start listening for the configured hotkey via a HID-level CGEventTap.
    /// Throws if Accessibility permission is not granted or the event tap cannot be created.
    func start() throws {
        guard HotkeyManager.hasAccessibilityPermission else {
            throw HotkeyManagerError.accessibilityNotGranted
        }

        stop()
        startupError = nil

        let thread = Thread { [weak self] in
            self?.runEventTapLoop()
        }
        thread.name = "McWhisper.HotkeyTap"
        tapThread = thread
        thread.start()

        setupSemaphore.wait()
        if let startupError {
            stop()
            throw startupError
        }
    }

    /// Stop listening for hotkey events.
    func stop() {
        if let tapRunLoop {
            let tap = eventTap
            let source = runLoopSource
            CFRunLoopPerformBlock(tapRunLoop, CFRunLoopMode.commonModes.rawValue) {
                if let tap {
                    CGEvent.tapEnable(tap: tap, enable: false)
                }
                if let source {
                    CFRunLoopRemoveSource(tapRunLoop, source, .commonModes)
                }
            }
            CFRunLoopWakeUp(tapRunLoop)
            CFRunLoopStop(tapRunLoop)
        }
        eventTap = nil
        runLoopSource = nil
        tapRunLoop = nil
        tapThread = nil
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
            return true
        }

        let relevantMask: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        let eventMods = event.flags.intersection(relevantMask).rawValue
        return eventMods == UInt64(modifiers)
    }

    func isModifierPressed(rawFlags: UInt64) -> Bool {
        if let sideSpecificMask = sideSpecificModifierMaskRawValue {
            return rawFlags & sideSpecificMask != 0
        }

        guard let modifierFlag = modifierFlag else { return false }
        return rawFlags & modifierFlag.rawValue != 0
    }

    private var modifierFlag: CGEventFlags? {
        switch keyCode {
        case 54, 55:
            return .maskCommand
        case 56, 60:
            return .maskShift
        case 58, 61:
            return .maskAlternate
        case 59, 62:
            return .maskControl
        case 57:
            return .maskAlphaShift
        case 63:
            return .maskSecondaryFn
        default:
            return nil
        }
    }

    private var sideSpecificModifierMaskRawValue: UInt64? {
        switch keyCode {
        case 54:
            return UInt64(NX_DEVICERCMDKEYMASK)
        case 55:
            return UInt64(NX_DEVICELCMDKEYMASK)
        case 56:
            return UInt64(NX_DEVICELSHIFTKEYMASK)
        case 60:
            return UInt64(NX_DEVICERSHIFTKEYMASK)
        case 58:
            return UInt64(NX_DEVICELALTKEYMASK)
        case 61:
            return UInt64(NX_DEVICERALTKEYMASK)
        case 59:
            return UInt64(NX_DEVICELCTLKEYMASK)
        case 62:
            return UInt64(NX_DEVICERCTLKEYMASK)
        default:
            return nil
        }
    }

    @discardableResult
    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Bool {
        if isModifierOnlyKey {
            return handleModifierOnlyEvent(type: type, event: event)
        }
        return handleRegularEvent(type: type, event: event)
    }

    @discardableResult
    private func handleModifierOnlyEvent(type: CGEventType, event: CGEvent) -> Bool {
        guard type == .flagsChanged else {
            return false
        }
        let eventKeyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let isPressed = isModifierPressed(rawFlags: event.flags.rawValue)
        if eventKeyCode == keyCode && isPressed && !isKeyDown {
            print("[McWhisper] hotkey down keyCode=\(eventKeyCode) flags=\(event.flags.rawValue)")
            isKeyDown = true
            print("[McWhisper] invoke onKeyDown callbackNil=\(onKeyDown == nil)")
            onKeyDown?()
            return true
        }

        if !isPressed && isKeyDown {
            print("[McWhisper] hotkey up keyCode=\(eventKeyCode) flags=\(event.flags.rawValue)")
            isKeyDown = false
            print("[McWhisper] invoke onKeyUp callbackNil=\(onKeyUp == nil)")
            onKeyUp?()
            return true
        }

        return false
    }

    @discardableResult
    private func handleRegularEvent(type: CGEventType, event: CGEvent) -> Bool {
        switch type {
        case .keyDown:
            guard matches(event), !isKeyDown else { return false }
            isKeyDown = true
            print("[McWhisper] invoke onKeyDown callbackNil=\(onKeyDown == nil)")
            onKeyDown?()
            return true

        case .keyUp:
            guard matches(event), isKeyDown else { return false }
            isKeyDown = false
            print("[McWhisper] invoke onKeyUp callbackNil=\(onKeyUp == nil)")
            onKeyUp?()
            return true

        case .flagsChanged:
            let relevantMask: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
            let currentMods = event.flags.intersection(relevantMask).rawValue
            guard isKeyDown, currentMods != UInt64(modifiers) else { return false }
            isKeyDown = false
            print("[McWhisper] invoke onKeyUp callbackNil=\(onKeyUp == nil)")
            onKeyUp?()
            return true

        default:
            return false
        }
    }

    private func runEventTapLoop() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: isModifierOnlyKey ? .listenOnly : .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: selfPtr
        ) else {
            stateLock.withLock {
                startupError = .eventTapCreationFailed
            }
            setupSemaphore.signal()
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let runLoop = CFRunLoopGetCurrent()

        stateLock.withLock {
            eventTap = tap
            runLoopSource = source
            tapRunLoop = runLoop
        }

        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        setupSemaphore.signal()
        CFRunLoopRun()
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        if let tap = manager.eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    default:
        break
    }

    let consumed = manager.handleEvent(type: type, event: event)
    if manager.isModifierOnlyKey {
        return Unmanaged.passUnretained(event)
    }
    return consumed ? nil : Unmanaged.passUnretained(event)
}
