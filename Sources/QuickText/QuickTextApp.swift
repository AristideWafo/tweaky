import SwiftUI

@main
struct QuickTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        MenuBarExtra("QuickText", systemImage: "text.badge.sparkles") {
            Button("Open QuickText") { appDelegate.openPanel() }
            Divider()
            SettingsLink()
            Divider()
            Button("Quit QuickText") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(appDelegate.state)
                .frame(width: 600, height: 590)
        }
    }
}
