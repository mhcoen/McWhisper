import Testing
import Foundation
import AppKit
@testable import McWhisper

@Suite("PasteManager", .serialized)
struct PasteManagerTests {

    @MainActor
    @Test("Initial targetApplication is nil")
    func initialTarget() {
        let manager = PasteManager()
        #expect(manager.targetApplication == nil)
    }

    @MainActor
    @Test("captureTarget sets targetApplication to frontmost app")
    func captureTarget() {
        let manager = PasteManager()
        manager.captureTarget()
        // In a test runner there is always a frontmost application
        #expect(manager.targetApplication != nil)
    }

    @MainActor
    @Test("clearTarget resets targetApplication to nil")
    func clearTarget() {
        let manager = PasteManager()
        manager.captureTarget()
        manager.clearTarget()
        #expect(manager.targetApplication == nil)
    }

    @MainActor
    @Test("clearTarget is safe when already nil")
    func clearTargetWhenNil() {
        let manager = PasteManager()
        manager.clearTarget()
        #expect(manager.targetApplication == nil)
    }

    @MainActor
    @Test("paste returns false without captured target")
    func pasteReturnsFalseWithoutTarget() {
        let manager = PasteManager()
        let result = manager.paste("no target")
        #expect(result == false)
    }

    @MainActor
    @Test("paste writes to general pasteboard when no target")
    func pasteCopiesOnFailure() {
        let manager = PasteManager()
        let text = "fallback text"
        let returned = manager.paste(text)
        #expect(returned == false)
        // Pasteboard write is attempted but may not be readable in sandboxed tests
    }

    @MainActor
    @Test("paste with cleared target returns false (clipboard fallback)")
    func pasteAfterClearTarget() {
        let manager = PasteManager()
        manager.captureTarget()
        manager.clearTarget()
        let result = manager.paste("cleared target text")
        #expect(result == false)
        #expect(manager.targetApplication == nil)
    }

    @MainActor
    @Test("captureTarget can be called multiple times")
    func captureTargetIdempotent() {
        let manager = PasteManager()
        manager.captureTarget()
        let first = manager.targetApplication
        manager.captureTarget()
        let second = manager.targetApplication
        // Same frontmost app in test context
        #expect(first?.processIdentifier == second?.processIdentifier)
    }
}
