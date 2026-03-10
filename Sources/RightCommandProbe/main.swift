import ApplicationServices
import Cocoa
import Foundation
import IOKit.hidsystem

private let rightCommandKeyCode: Int64 = 54
private let leftCommandKeyCode: Int64 = 55
private let genericCommandMask = CGEventFlags.maskCommand.rawValue
private let rightCommandMask = UInt64(NX_DEVICERCMDKEYMASK)
private let leftCommandMask = UInt64(NX_DEVICELCMDKEYMASK)

private final class Probe {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var rightCommandIsDown = false

    func run() throws {
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            throw ProbeError.accessibilityNotGranted
        }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: eventCallback,
            userInfo: selfPtr
        ) else {
            throw ProbeError.eventTapCreationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source

        installSignalHandler()
        printHeader()
        CFRunLoopRun()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        CFRunLoopStop(CFRunLoopGetCurrent())
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            print("[probe] tap re-enabled after \(type.rawValue)")
            return
        case .flagsChanged, .keyDown, .keyUp:
            break
        default:
            return
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags.rawValue
        let rightDevice = (flags & rightCommandMask) != 0
        let leftDevice = (flags & leftCommandMask) != 0
        let genericCommand = (flags & genericCommandMask) != 0

        if type == .flagsChanged || keyCode == rightCommandKeyCode || keyCode == leftCommandKeyCode {
            print(
                "[probe] type=\(name(for: type)) keyCode=\(keyCode) flags=\(flags) " +
                "genericCmd=\(genericCommand) leftCmd=\(leftDevice) rightCmd=\(rightDevice)"
            )
        }

        if keyCode == rightCommandKeyCode && rightDevice && !rightCommandIsDown {
            rightCommandIsDown = true
            print("[probe] RIGHT_COMMAND_DOWN")
        } else if rightCommandIsDown && !rightDevice {
            rightCommandIsDown = false
            print("[probe] RIGHT_COMMAND_UP via keyCode=\(keyCode) flags=\(flags)")
        }
    }

    private func printHeader() {
        print("RightCommandProbe")
        print("Press and hold Right Command, then release it.")
        print("The probe logs raw HID events and inferred RIGHT_COMMAND_DOWN / RIGHT_COMMAND_UP.")
        print("Press Control-C to exit.")
    }

    private func installSignalHandler() {
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        source.setEventHandler { [weak self] in
            print("\n[probe] stopping")
            self?.stop()
            exit(0)
        }
        source.resume()
        SignalHolder.shared.source = source
    }

    private func name(for type: CGEventType) -> String {
        switch type {
        case .keyDown:
            return "keyDown"
        case .keyUp:
            return "keyUp"
        case .flagsChanged:
            return "flagsChanged"
        case .tapDisabledByTimeout:
            return "tapDisabledByTimeout"
        case .tapDisabledByUserInput:
            return "tapDisabledByUserInput"
        default:
            return "type\(type.rawValue)"
        }
    }
}

private enum ProbeError: LocalizedError {
    case accessibilityNotGranted
    case eventTapCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission is required. Approve the prompt, then run the probe again."
        case .eventTapCreationFailed:
            return "Failed to create the HID event tap."
        }
    }
}

private enum SignalHolder {
    static var shared = Box()

    final class Box {
        var source: DispatchSourceSignal?
    }
}

private func eventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let probe = Unmanaged<Probe>.fromOpaque(userInfo).takeUnretainedValue()
    probe.handle(type: type, event: event)
    return Unmanaged.passUnretained(event)
}

do {
    try Probe().run()
} catch {
    fputs("RightCommandProbe error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
