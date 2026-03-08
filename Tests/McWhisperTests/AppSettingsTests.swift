import Testing
@testable import McWhisper

@Suite("AppSettings")
struct AppSettingsTests {
    @Test("Default model ID is openai_whisper-base")
    func defaultModelID() {
        #expect(AppSettings.defaultModelID == "openai_whisper-base")
    }

    @Test("Default hotkey is Right Command")
    func defaultHotkey() {
        #expect(AppSettings.defaultHotkeyKeyCode == 54)
        #expect(AppSettings.defaultHotkeyModifiers == 0)
    }

    @Test("Default mode is voice")
    func defaultMode() {
        #expect(AppSettings.defaultMode == "voice")
    }

    @Test("Default language is auto")
    func defaultLanguage() {
        #expect(AppSettings.defaultLanguage == "auto")
    }

    @Test("Default silence threshold is 0.015")
    func defaultSilenceThreshold() {
        #expect(AppSettings.defaultSilenceThreshold == 0.015)
    }

    @Test("UserDefaults keys are distinct")
    func keysAreDistinct() {
        let keys = [
            AppSettings.Keys.selectedModelID,
            AppSettings.Keys.hotkeyKeyCode,
            AppSettings.Keys.hotkeyModifiers,
            AppSettings.Keys.selectedMode,
            AppSettings.Keys.selectedLanguage,
            AppSettings.Keys.silenceThreshold,
            AppSettings.Keys.panelPositionX,
            AppSettings.Keys.panelPositionY,
            AppSettings.Keys.hasSavedPanelPosition,
            AppSettings.Keys.hasCompletedOnboarding,
        ]
        #expect(Set(keys).count == keys.count)
    }

    @Test("Reset restores defaults")
    func resetToDefaults() {
        AppSettings.selectedModelID = "custom-model"
        AppSettings.selectedMode = "email"
        AppSettings.selectedLanguage = "en"
        AppSettings.hotkeyKeyCode = 12
        AppSettings.hotkeyModifiers = 0
        AppSettings.silenceThreshold = 0.05

        AppSettings.resetToDefaults()

        #expect(AppSettings.selectedModelID == AppSettings.defaultModelID)
        #expect(AppSettings.selectedMode == AppSettings.defaultMode)
        #expect(AppSettings.selectedLanguage == AppSettings.defaultLanguage)
        #expect(AppSettings.hotkeyKeyCode == Int(AppSettings.defaultHotkeyKeyCode))
        #expect(AppSettings.hotkeyModifiers == Int(AppSettings.defaultHotkeyModifiers))
        #expect(AppSettings.silenceThreshold == Double(AppSettings.defaultSilenceThreshold))
    }
}
