import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    private lazy var panelController = PanelController(state: state) { [weak self] in
        self?.openSettings()
    }
    private var hotKeyService: HotKeyService?
    private var settingsObserver: NSObjectProtocol?
    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateOtherInstances()
        NSApp.setActivationPolicy(.accessory)
        installStatusItem()
        hotKeyService = HotKeyService { [weak self] in self?.openPanel() }
        registerHotKey()
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .tweakySettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.registerHotKey() }
        }
        openPanel()
    }

    func openPanel() {
        state.prepareForPresentation()
        panelController.show()
    }

    @objc func openSettings() {
        if let window = settingsWindowController?.window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView().environmentObject(state)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Tweaky Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 590))
        window.center()
        window.isReleasedWhenClosed = false
        settingsWindowController = NSWindowController(window: window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "text.badge.sparkles", accessibilityDescription: "Tweaky")
        item.button?.toolTip = "Tweaky"

        let menu = NSMenu()
        menu.addItem(withTitle: "Open Tweaky", action: #selector(openPanelFromMenu), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tweaky", action: #selector(quit), keyEquivalent: "q")
        for menuItem in menu.items { menuItem.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func openPanelFromMenu() {
        openPanel()
    }

    private func terminateOtherInstances() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let currentPID = ProcessInfo.processInfo.processIdentifier
        for application in NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            where application.processIdentifier != currentPID {
            application.terminate()
        }
    }

    private func registerHotKey() {
        hotKeyService?.start(shortcut: state.settingsStore.settings.shortcut)
    }
}
