import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private let panel: NSPanel

    init(state: AppState, openSettings: @escaping () -> Void) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 420),
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
        panel.contentView = NSHostingView(rootView: TweakyPanel(
            state: state,
            dismiss: { [weak panel] in panel?.orderOut(nil) },
            openSettings: openSettings
        ))
    }

    func show() {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
