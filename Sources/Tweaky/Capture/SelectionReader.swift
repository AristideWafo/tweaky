import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
final class SelectionReader {
    private var sourceApp: NSRunningApplication?

    /// Reads the selection of the frontmost app. Must run before Tweaky takes focus.
    func readSelectedText() async -> CaptureResult? {
        let frontmost = NSWorkspace.shared.frontmostApplication
        guard frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        sourceApp = frontmost
        guard AXIsProcessTrusted() else { return nil }
        // Browsers (Gmail), Electron apps (WhatsApp, Slack) and terminals don't expose
        // their selection through Accessibility, so fall back to copying it.
        if let text = accessibilitySelection() { return CaptureResult(text: text, source: .accessibility) }
        guard let text = await copySelection() else { return nil }
        return CaptureResult(text: text, source: .accessibility)
    }

    /// Pastes over the original selection by returning to the source app and sending Command-V.
    /// The result stays on the clipboard afterwards.
    func replaceSelection(with text: String) async -> Bool {
        guard let sourceApp, !sourceApp.isTerminated, AXIsProcessTrusted() else { return false }
        ClipboardService.copy(text)
        sourceApp.activate()
        try? await Task.sleep(for: .milliseconds(250))
        postCommand(key: CGKeyCode(kVK_ANSI_V))
        return true
    }

    private func accessibilitySelection() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return nil }
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(unsafeDowncast(element, to: AXUIElement.self), kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    private func copySelection() async -> String? {
        let pasteboard = NSPasteboard.general
        let saved = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
        let before = pasteboard.changeCount
        postCommand(key: CGKeyCode(kVK_ANSI_C))
        let deadline = ContinuousClock.now + .milliseconds(400)
        while pasteboard.changeCount == before, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        guard pasteboard.changeCount != before else { return nil }
        let text = pasteboard.string(forType: .string)
        // Put the user's clipboard back; the copy was only a way to read the selection.
        pasteboard.clearContents()
        pasteboard.writeObjects(saved)
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    private func postCommand(key: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown)
            // Explicit flags so modifiers still held from Tweaky's hotkey (Option) don't turn ⌘C into ⌥⌘C.
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }
}
