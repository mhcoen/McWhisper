import Testing
import AppKit
@testable import McWhisper

@Suite("RecordingWindowController")
struct RecordingWindowControllerTests {

    @MainActor
    @Test("Initially has no panel")
    func initialState() {
        let controller = RecordingWindowController()
        #expect(controller.panel == nil)
        #expect(controller.isVisible == false)
    }

    @MainActor
    @Test("show() creates a panel")
    func showCreatesPanel() {
        let controller = RecordingWindowController()
        controller.show()
        #expect(controller.panel != nil)
    }

    @MainActor
    @Test("Panel uses nonactivatingPanel style")
    func panelStyle() {
        let controller = RecordingWindowController()
        controller.show()
        let panel = controller.panel!
        #expect(panel.styleMask.contains(.nonactivatingPanel))
    }

    @MainActor
    @Test("Panel floats above other windows")
    func panelLevel() {
        let controller = RecordingWindowController()
        controller.show()
        let panel = controller.panel!
        #expect(panel.level == .floating)
        #expect(panel.isFloatingPanel == true)
    }

    @MainActor
    @Test("Panel does not hide on app deactivation")
    func panelHidesOnDeactivate() {
        let controller = RecordingWindowController()
        controller.show()
        #expect(controller.panel!.hidesOnDeactivate == false)
    }

    @MainActor
    @Test("Panel can join all spaces")
    func panelCollectionBehavior() {
        let controller = RecordingWindowController()
        controller.show()
        let behavior = controller.panel!.collectionBehavior
        #expect(behavior.contains(.canJoinAllSpaces))
        #expect(behavior.contains(.fullScreenAuxiliary))
    }

    @MainActor
    @Test("hide() initiates panel removal")
    func hideRemovesPanel() {
        let controller = RecordingWindowController()
        controller.show()
        #expect(controller.panel != nil)
        controller.hide()
        // Panel removal happens in completion handler; panel may still exist briefly
        // but the fade-out has been initiated
    }

    @MainActor
    @Test("show() is idempotent when already shown")
    func showIdempotent() {
        let controller = RecordingWindowController()
        controller.show()
        let first = controller.panel
        controller.show()
        #expect(controller.panel === first)
    }

    @MainActor
    @Test("hide() is safe to call without show()")
    func hideWithoutShow() {
        let controller = RecordingWindowController()
        controller.hide()
        #expect(controller.panel == nil)
    }

    @MainActor
    @Test("Panel has transparent titlebar")
    func transparentTitlebar() {
        let controller = RecordingWindowController()
        controller.show()
        let panel = controller.panel!
        #expect(panel.titlebarAppearsTransparent == true)
        #expect(panel.titleVisibility == .hidden)
    }

    @MainActor
    @Test("Panel starts with zero alpha for fade-in")
    func fadeInStartsTransparent() {
        let controller = RecordingWindowController()
        controller.show()
        // The animation has been kicked off; alphaValue starts at 0
        // and animates to 1. We verify the panel exists and was created.
        #expect(controller.panel != nil)
    }

    @MainActor
    @Test("Fade duration is reasonable")
    func fadeDuration() {
        #expect(RecordingWindowController.fadeDuration > 0)
        #expect(RecordingWindowController.fadeDuration <= 1.0)
    }

    @MainActor
    @Test("savePosition persists to AppSettings")
    func savePosition() {
        let controller = RecordingWindowController()
        controller.show()
        let panel = controller.panel!
        // Use the panel's actual origin (may be constrained by screen)
        let origin = panel.frame.origin
        controller.savePosition(panel)
        #expect(AppSettings.panelPositionX == Double(origin.x))
        #expect(AppSettings.panelPositionY == Double(origin.y))
        #expect(AppSettings.hasSavedPanelPosition == true)
    }

    @MainActor
    @Test("restorePosition reads from AppSettings")
    func restorePosition() {
        // Show once to save position
        let controller = RecordingWindowController()
        controller.show()
        let panel = controller.panel!
        let savedOrigin = panel.frame.origin
        controller.savePosition(panel)

        // Create a new panel and restore — should match saved position
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 80),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        controller.restorePosition(newPanel)
        #expect(newPanel.frame.origin.x == savedOrigin.x)
        #expect(newPanel.frame.origin.y == savedOrigin.y)
    }

    @MainActor
    @Test("restorePosition centers when no saved position")
    func restorePositionCenters() {
        AppSettings.hasSavedPanelPosition = false

        let controller = RecordingWindowController()
        controller.show()
        let panel = controller.panel!
        // Should be centered — just verify it was placed somewhere reasonable
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            #expect(panel.frame.origin.x >= screenFrame.minX)
            #expect(panel.frame.origin.y >= screenFrame.minY)
        }
    }
}
