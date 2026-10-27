import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    private lazy var panelController = PanelController(state: state)
    private var hotKeyService: HotKeyService?
    private var settingsObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        hotKeyService = HotKeyService { [weak self] in self?.openPanel() }
        registerHotKey()
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .tweakySettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.registerHotKey() }
        }
    }

    func openPanel() {
        state.prepareForPresentation()
        panelController.show()
    }

    private func registerHotKey() {
        hotKeyService?.start(shortcut: state.settingsStore.settings.shortcut)
    }
}
