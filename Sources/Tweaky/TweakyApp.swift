import SwiftUI

@main
struct TweakyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.state)
                .frame(width: 600, height: 590)
        }
    }
}
