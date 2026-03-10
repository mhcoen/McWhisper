import Testing
@testable import McWhisper

@Suite("AppLaunchOptions")
struct AppLaunchOptionsTests {
    @Test("Flag constant value")
    func flagConstant() {
        #expect(AppLaunchOptions.appshotRecordingPanelFlag == "--appshot-recording-panel")
    }

    @Test("Environment key constant value")
    func environmentKeyConstant() {
        #expect(AppLaunchOptions.appshotRecordingPanelEnvironmentKey == "MCWHISPER_APPSHOT_RECORDING_PANEL")
    }

    @Test("showsAppShotRecordingPanel returns Bool")
    func showsAppShotRecordingPanelReturnsBool() {
        // In test context neither the flag nor the env var should be set
        let result = AppLaunchOptions.showsAppShotRecordingPanel
        #expect(result == false)
    }
}
