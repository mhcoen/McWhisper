import Testing
import Foundation
@testable import McWhisper

@Suite("PasteManager")
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
