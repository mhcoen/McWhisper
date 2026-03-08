import SwiftUI

struct AppSettings {
    static let defaultModelID = "openai_whisper-base"
    static let defaultHotkeyKeyCode: UInt16 = 54  // Right Command
    static let defaultHotkeyModifiers: UInt32 = 0  // No additional modifiers
    static let defaultMode = "voice"
    static let defaultLanguage = "auto"
    static let defaultSilenceThreshold: Float = 0.015

    enum Keys {
        static let selectedModelID = "selectedModelID"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let selectedMode = "selectedMode"
        static let selectedLanguage = "selectedLanguage"
        static let silenceThreshold = "silenceThreshold"
        static let panelPositionX = "panelPositionX"
        static let panelPositionY = "panelPositionY"
        static let hasSavedPanelPosition = "hasSavedPanelPosition"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    @AppStorage(Keys.selectedModelID) static var selectedModelID: String = defaultModelID
    @AppStorage(Keys.hotkeyKeyCode) static var hotkeyKeyCode: Int = Int(defaultHotkeyKeyCode)
    @AppStorage(Keys.hotkeyModifiers) static var hotkeyModifiers: Int = Int(defaultHotkeyModifiers)
    @AppStorage(Keys.selectedMode) static var selectedMode: String = defaultMode
    @AppStorage(Keys.selectedLanguage) static var selectedLanguage: String = defaultLanguage
    @AppStorage(Keys.silenceThreshold) static var silenceThreshold: Double = Double(defaultSilenceThreshold)
    @AppStorage(Keys.panelPositionX) static var panelPositionX: Double = 0
    @AppStorage(Keys.panelPositionY) static var panelPositionY: Double = 0
    @AppStorage(Keys.hasSavedPanelPosition) static var hasSavedPanelPosition: Bool = false
    @AppStorage(Keys.hasCompletedOnboarding) static var hasCompletedOnboarding: Bool = false

    static func resetToDefaults() {
        selectedModelID = defaultModelID
        hotkeyKeyCode = Int(defaultHotkeyKeyCode)
        hotkeyModifiers = Int(defaultHotkeyModifiers)
        selectedMode = defaultMode
        selectedLanguage = defaultLanguage
        silenceThreshold = Double(defaultSilenceThreshold)
    }
}
