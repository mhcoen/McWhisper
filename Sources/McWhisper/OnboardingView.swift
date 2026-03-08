import SwiftUI
import AVFoundation

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case microphone
    case accessibility
    case ready
}

struct OnboardingView: View {
    @State private var step: OnboardingStep = .welcome
    @State private var micGranted: Bool = false
    @State private var accessibilityGranted: Bool = false

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)

            Divider()

            HStack {
                if step != .welcome {
                    Button("Back") {
                        withAnimation {
                            step = OnboardingStep(rawValue: step.rawValue - 1) ?? .welcome
                        }
                    }
                }
                Spacer()
                if step == .ready {
                    Button("Get Started") {
                        AppSettings.hasCompletedOnboarding = true
                        onComplete()
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Continue") {
                        advanceStep()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
        .frame(width: 480, height: 340)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            WelcomeStepView()
        case .microphone:
            MicrophoneStepView(granted: micGranted)
        case .accessibility:
            AccessibilityStepView(granted: accessibilityGranted)
        case .ready:
            ReadyStepView()
        }
    }

    private func advanceStep() {
        switch step {
        case .welcome:
            withAnimation { step = .microphone }
        case .microphone:
            Task {
                micGranted = await MicrophonePermission.request()
                withAnimation { step = .accessibility }
            }
        case .accessibility:
            accessibilityGranted = HotkeyManager.hasAccessibilityPermission
            if !accessibilityGranted {
                HotkeyManager.requestAccessibilityPermission()
            }
            withAnimation { step = .ready }
        case .ready:
            break
        }
    }
}

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Welcome to McWhisper")
                .font(.title)
                .fontWeight(.semibold)
            Text("Local speech-to-text for macOS. Hold your hotkey, speak, and the transcription is pasted into the active app.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer().frame(height: 8)
            HStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.green)
                Text("All processing happens on your device. No data leaves your Mac.")
            }
            .font(.callout)
        }
    }
}

struct MicrophoneStepView: View {
    var granted: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.circle")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Microphone Access")
                .font(.title2)
                .fontWeight(.semibold)
            Text("McWhisper needs microphone access to capture your speech for transcription.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if granted {
                Label("Microphone access granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

struct AccessibilityStepView: View {
    var granted: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.circle")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Accessibility Access")
                .font(.title2)
                .fontWeight(.semibold)
            Text("McWhisper needs Accessibility access for the global push-to-talk hotkey and to paste transcriptions into your apps.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if granted {
                Label("Accessibility access granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

struct ReadyStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("You're All Set")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Hold your hotkey to record, release to transcribe and paste. Look for the waveform icon in your menu bar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }
}
