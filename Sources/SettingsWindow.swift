import AppKit
import SwiftUI

extension Notification.Name {
    static let wallflowerVolumeChanged = Notification.Name("WallflowerVolumeChanged")
    static let wallflowerRateChanged = Notification.Name("WallflowerRateChanged")
    static let wallflowerPauseOnBatteryChanged = Notification.Name("WallflowerPauseOnBatteryChanged")
}

struct SettingsView: View {
    @AppStorage("pauseOnBattery") private var pauseOnBattery: Bool = true
    @AppStorage("volume") private var volume: Double = 0.0
    @AppStorage("playbackRate") private var playbackRate: Double = 1.0
    @AppStorage("startAtLogin") private var startAtLogin: Bool = false

    var body: some View {
        TabView {
            GeneralSettingsView(
                pauseOnBattery: $pauseOnBattery,
                startAtLogin: $startAtLogin
            )
            .tabItem { Text("General") }

            PlaybackSettingsView(
                volume: $volume,
                playbackRate: $playbackRate
            )
            .tabItem { Text("Playback") }
        }
        .frame(width: 400, height: 250)
        .padding()
    }
}

struct GeneralSettingsView: View {
    @Binding var pauseOnBattery: Bool
    @Binding var startAtLogin: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Pause wallpapers on battery power", isOn: $pauseOnBattery)
                .onChange(of: pauseOnBattery) { newValue in
                    NotificationCenter.default.post(
                        name: .wallflowerPauseOnBatteryChanged,
                        object: nil,
                        userInfo: ["value": newValue]
                    )
                }

            Toggle("Start Wallflower at login", isOn: $startAtLogin)
                .onChange(of: startAtLogin) { newValue in
                    if newValue {
                        NSWorkspace.shared.open(
                            URL(fileURLWithPath: "/System/Library/PreferencePanes/Accounts.prefPane")
                        )
                    }
                }
            Spacer()
        }
        .padding(.top)
    }
}

struct PlaybackSettingsView: View {
    @Binding var volume: Double
    @Binding var playbackRate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Volume:")
                Slider(value: $volume, in: 0...1) {
                    Text("Volume")
                }
                .onChange(of: volume) { newValue in
                    NotificationCenter.default.post(
                        name: .wallflowerVolumeChanged,
                        object: nil,
                        userInfo: ["volume": Float(newValue)]
                    )
                }
                Text("\(Int(volume * 100))%")
                    .frame(width: 40, alignment: .trailing)
            }

            HStack {
                Text("Speed:")
                Slider(value: $playbackRate, in: 0.25...4) {
                    Text("Speed")
                }
                .onChange(of: playbackRate) { newValue in
                    NotificationCenter.default.post(
                        name: .wallflowerRateChanged,
                        object: nil,
                        userInfo: ["rate": Float(newValue)]
                    )
                }
                Text(String(format: "%.2fx", playbackRate))
                    .frame(width: 50, alignment: .trailing)
            }
            Spacer()
        }
        .padding(.top)
    }
}

@MainActor
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var settingsWindow: NSWindow?

    var window: NSWindow? { settingsWindow }

    func show() {
        if settingsWindow == nil {
            let hosting = NSHostingController(
                rootView: SettingsView()
            )
            let window = NSWindow(contentViewController: hosting)
            window.title = "Wallflower Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 420, height: 300))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
