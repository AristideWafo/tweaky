import AppKit
import SwiftUI

/// Borderless panels refuse key status by default; Tweaky needs it for text input and click-outside dismissal.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class PanelController {
    private let panel: NSPanel
    private let state: AppState
    private var resignObserver: NSObjectProtocol?

    init(state: AppState, openSettings: @escaping () -> Void) {
        self.state = state
        panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 260),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = true

        let hosting = NSHostingController(rootView: TweakyPanel(
            state: state,
            dismiss: { [weak self] in self?.hide() },
            openSettings: { [weak self] in
                self?.hide()
                openSettings()
            }
        ))
        // The panel follows the SwiftUI content size, so it grows with text up to the view's max height.
        hosting.sizingOptions = [.preferredContentSize]
        panel.contentViewController = hosting

        // Spotlight-like: clicking anywhere outside Tweaky closes it.
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
    }

    func show() {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        guard panel.isVisible else { return }
        state.cancel()
        panel.orderOut(nil)
    }
}
