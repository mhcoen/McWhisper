import Foundation

enum AppLaunchOptions {
    static let appshotRecordingPanelFlag = "--appshot-recording-panel"
    static let appshotRecordingPanelEnvironmentKey = "MCWHISPER_APPSHOT_RECORDING_PANEL"

    static var showsAppShotRecordingPanel: Bool {
        CommandLine.arguments.contains(appshotRecordingPanelFlag)
            || ProcessInfo.processInfo.environment[appshotRecordingPanelEnvironmentKey] == "1"
    }
}
