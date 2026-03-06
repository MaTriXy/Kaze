import SwiftUI
import AppKit
import Carbon

// MARK: - Onboarding View

struct OnboardingView: View {
    @State private var currentStep = 0
    @State private var hotkeyShortcut = HotkeyShortcut.default
    @State private var isRecordingHotkey = false
    @State private var hotkeyMonitor: Any?
    @State private var recordedModifiersUnion: HotkeyShortcut.Modifiers = []
    @AppStorage(AppPreferenceKey.transcriptionEngine) private var engineRaw = TranscriptionEngine.dictation.rawValue
    @AppStorage(AppPreferenceKey.hotkeyMode) private var hotkeyModeRaw = HotkeyMode.holdToTalk.rawValue

    var onComplete: () -> Void

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            Group {
                switch currentStep {
                case 0: welcomeStep
                case 1: hotkeyStep
                case 2: engineStep
                case 3: doneStep
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.25), value: currentStep)

            Divider()

            // Navigation bar
            HStack {
                // Step indicators
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { step in
                        Circle()
                            .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                if currentStep > 0 && currentStep < totalSteps - 1 {
                    Button("Back") {
                        stopHotkeyRecording()
                        currentStep -= 1
                    }
                    .controlSize(.regular)
                }

                if currentStep < totalSteps - 1 {
                    Button("Continue") {
                        stopHotkeyRecording()
                        if currentStep == 1 {
                            // Save hotkey before advancing
                            hotkeyShortcut.saveToDefaults()
                        }
                        currentStep += 1
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .controlSize(.regular)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        hotkeyShortcut.saveToDefaults()
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        onComplete()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .controlSize(.regular)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
        }
        .frame(width: 480, height: 500)
        .onDisappear {
            stopHotkeyRecording()
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Spacer()

            if let icon = NSImage(named: "kaze-icon") {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
            } else {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
            }

            Text("Welcome to Kaze")
                .font(.title.bold())

            Text("Speech-to-text that runs entirely on your Mac.\nNo cloud, no subscription, no data leaves your device.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Step 2: Hotkey Setup

    private var hotkeyStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "keyboard")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Set Your Hotkey")
                .font(.title2.bold())

            Text("Choose how you want to trigger Kaze.")
                .font(.body)
                .foregroundStyle(.secondary)

            // Mode picker
            VStack(alignment: .leading, spacing: 8) {
                Picker("Mode", selection: $hotkeyModeRaw) {
                    ForEach(HotkeyMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 200)

                let selectedMode = HotkeyMode(rawValue: hotkeyModeRaw) ?? .holdToTalk
                Text(selectedMode.description)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 4)

            // Hotkey display + record
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    ForEach(hotkeyShortcut.displayTokens, id: \.self) { token in
                        OnboardingKeyCapView(token)
                    }
                }

                Button(isRecordingHotkey ? "Press keys..." : "Change") {
                    if isRecordingHotkey {
                        stopHotkeyRecording()
                    } else {
                        startHotkeyRecording()
                    }
                }
                .controlSize(.small)

                Button("Reset") {
                    hotkeyShortcut = .default
                    stopHotkeyRecording()
                }
                .controlSize(.small)
            }

            if isRecordingHotkey {
                Text("Press a key combination with at least one modifier. Press Esc to cancel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
    }

    // MARK: - Step 3: Engine Selection

    private var engineStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Choose an Engine")
                .font(.title2.bold())

            Text("You can change this later in Settings.\nAI engines require a one-time model download.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                ForEach(TranscriptionEngine.allCases) { engine in
                    Button {
                        engineRaw = engine.rawValue
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: engineIcon(engine))
                                .frame(width: 20)
                                .foregroundStyle(engineRaw == engine.rawValue ? .white : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(engine.title)
                                    .font(.system(size: 13, weight: .medium))
                                Text(engine.description)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .opacity(0.8)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if engineRaw == engine.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(engineRaw == engine.rawValue ? Color.accentColor : Color.clear)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(engineRaw == engine.rawValue ? .white : .primary)
                }
            }
            .padding(.horizontal, 60)

            Spacer()
        }
    }

    // MARK: - Step 4: Done

    private var doneStep: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title2.bold())

            let shortcutDisplay = hotkeyShortcut.displayString
            let modeDisplay = (HotkeyMode(rawValue: hotkeyModeRaw) ?? .holdToTalk).title.lowercased()

            Text("Press **\(shortcutDisplay)** (\(modeDisplay)) to start dictating.\nKaze lives in your menu bar.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Helpers

    private func engineIcon(_ engine: TranscriptionEngine) -> String {
        switch engine {
        case .dictation: return "mic.fill"
        case .whisper: return "waveform"
        case .parakeet: return "bird"
        case .qwen: return "brain.head.profile"
        }
    }

    // MARK: - Hotkey Recording (mirrors ContentView logic)

    private func startHotkeyRecording() {
        stopHotkeyRecording()
        isRecordingHotkey = true
        recordedModifiersUnion = []

        hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if !isRecordingHotkey { return event }

            if event.type == .flagsChanged {
                let modifiers = HotkeyShortcut.Modifiers(from: event.modifierFlags)
                if !modifiers.isEmpty {
                    recordedModifiersUnion.formUnion(modifiers)
                    return nil
                }
                if !recordedModifiersUnion.isEmpty {
                    hotkeyShortcut = HotkeyShortcut(modifiers: recordedModifiersUnion, keyCode: nil)
                    stopHotkeyRecording()
                    return nil
                }
                return nil
            }

            if event.keyCode == 53 { // Escape
                stopHotkeyRecording()
                return nil
            }

            let modifiers = HotkeyShortcut.Modifiers(from: event.modifierFlags)
            guard !modifiers.isEmpty else {
                NSSound.beep()
                return nil
            }

            hotkeyShortcut = HotkeyShortcut(modifiers: modifiers, keyCode: Int(event.keyCode))
            stopHotkeyRecording()
            return nil
        }
    }

    private func stopHotkeyRecording() {
        isRecordingHotkey = false
        recordedModifiersUnion = []
        if let hotkeyMonitor {
            NSEvent.removeMonitor(hotkeyMonitor)
            self.hotkeyMonitor = nil
        }
    }
}

// MARK: - Onboarding Key Cap View

private struct OnboardingKeyCapView: View {
    let key: String

    init(_ key: String) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .font(.system(size: 14, weight: .medium))
            .frame(minWidth: 26, minHeight: 24)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }
}
