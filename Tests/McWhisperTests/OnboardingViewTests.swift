import Testing
@testable import McWhisper

@Suite("OnboardingView")
struct OnboardingViewTests {
    @Test("OnboardingStep has four cases")
    func stepCount() {
        #expect(OnboardingStep.allCases.count == 4)
    }

    @Test("OnboardingStep raw values are sequential")
    func stepOrder() {
        #expect(OnboardingStep.welcome.rawValue == 0)
        #expect(OnboardingStep.microphone.rawValue == 1)
        #expect(OnboardingStep.accessibility.rawValue == 2)
        #expect(OnboardingStep.ready.rawValue == 3)
    }

    @Test("OnboardingView builds")
    func viewBuilds() {
        let view = OnboardingView(onComplete: {})
        _ = view.body
    }

    @Test("WelcomeStepView builds")
    func welcomeBuilds() {
        let view = WelcomeStepView()
        _ = view.body
    }

    @Test("MicrophoneStepView builds with granted false")
    func micNotGranted() {
        let view = MicrophoneStepView(granted: false)
        _ = view.body
    }

    @Test("MicrophoneStepView builds with granted true")
    func micGranted() {
        let view = MicrophoneStepView(granted: true)
        _ = view.body
    }

    @Test("AccessibilityStepView builds with granted false")
    func accessNotGranted() {
        let view = AccessibilityStepView(granted: false)
        _ = view.body
    }

    @Test("AccessibilityStepView builds with granted true")
    func accessGranted() {
        let view = AccessibilityStepView(granted: true)
        _ = view.body
    }

    @Test("ReadyStepView builds")
    func readyBuilds() {
        let view = ReadyStepView()
        _ = view.body
    }

    @MainActor
    @Test("OnboardingWindowController is a singleton")
    func singleton() {
        let a = OnboardingWindowController.shared
        let b = OnboardingWindowController.shared
        #expect(a === b)
    }

    @MainActor
    @Test("OnboardingWindowController is not visible initially")
    func initiallyHidden() {
        #expect(!OnboardingWindowController.shared.isVisible)
    }

    @Test("hasCompletedOnboarding key exists")
    func onboardingKey() {
        #expect(AppSettings.Keys.hasCompletedOnboarding == "hasCompletedOnboarding")
    }
}
