import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    private lazy var panelController = PanelController(state: state) { [weak self] in
        self?.openSettings()
    }
    private var hotKeyService: HotKeyService?
    private var instantHotKeyService: HotKeyService?
    private var instantTask: Task<Void, Never>?
    private var settingsObserver: NSObjectProtocol?
    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateOtherInstances()
        BrandFont.register()
        NSApp.setActivationPolicy(.accessory)
        installStatusItem()
        hotKeyService = HotKeyService { [weak self] in self?.openPanel() }
        instantHotKeyService = HotKeyService(identifier: 2) { [weak self] in self?.instantTweak() }
        registerHotKey()
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .tweakySettingsChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.registerHotKey() }
        }
        openPanel()
    }

    func openPanel() {
        Task {
            // Capture first: showing the panel would move focus away from the selected text.
            await state.prepareForPresentation()
            panelController.show()
        }
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
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.setContentSize(NSSize(width: 540, height: 640))
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
        // Fallback covers `swift run`, where the bundle has no MenuBarIcon resource.
        let icon = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: "Tweaky")
        icon?.isTemplate = true
        icon?.size = NSSize(width: 18, height: 18)
        item.button?.image = icon
        item.button?.toolTip = "Tweaky is running"

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
        let settings = state.settingsStore.settings
        hotKeyService?.start(shortcut: settings.shortcut)
        // The panel shortcut wins when both are set to the same keys.
        if settings.instantShortcutEnabled, settings.instantShortcut != settings.shortcut {
            instantHotKeyService?.start(shortcut: settings.instantShortcut)
        } else {
            instantHotKeyService?.stop()
        }
    }

    /// Corrects the selection in place; the menu-bar icon pulses while the provider works.
    private func instantTweak() {
        guard instantTask == nil else { return }
        let button = statusItem?.button
        let pulse = Task { @MainActor in
            while !Task.isCancelled {
                NSAnimationContext.runAnimationGroup({ $0.duration = 0.4; button?.animator().alphaValue = 0.3 }, completionHandler: nil)
                try? await Task.sleep(for: .milliseconds(450))
                NSAnimationContext.runAnimationGroup({ $0.duration = 0.4; button?.animator().alphaValue = 1 }, completionHandler: nil)
                try? await Task.sleep(for: .milliseconds(450))
            }
        }
        instantTask = Task {
            let outcome = await state.instantCorrect()
            pulse.cancel()
            button?.alphaValue = 1
            instantTask = nil
            switch outcome {
            case .replaced: break
            case .unchanged: Notifier.post("No corrections needed.")
            case .noSelection: Notifier.post("Select some text first, then press the shortcut again.")
            case .copied(let message), .failed(let message): Notifier.post(message)
            }
        }
    }
}
