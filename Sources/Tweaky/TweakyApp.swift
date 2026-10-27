import SwiftUI

@main
struct TweakyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        MenuBarExtra("Tweaky", systemImage: "text.badge.sparkles") {
            Button("Open Tweaky") { appDelegate.openPanel() }
            Divider()
            SettingsLink()
            Divider()
            Button("Quit Tweaky") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.state)
                .frame(width: 600, height: 590)
        }
    }
}
