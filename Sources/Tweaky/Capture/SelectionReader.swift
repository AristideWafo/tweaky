import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
final class SelectionReader {
    private var sourceApp: NSRunningApplication?
    /// The text field the selection was read from; only set when Accessibility exposed it.
    private var sourceElement: AXUIElement?

    /// Reads the selection of the frontmost app. Must run before Tweaky takes focus.
    func readSelectedText() async -> CaptureResult? {
        sourceElement = nil
        let frontmost = NSWorkspace.shared.frontmostApplication
        guard frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        sourceApp = frontmost
        guard AXIsProcessTrusted() else { return nil }
        if let element = focusedElement(), let text = selectedText(of: element) {
            sourceElement = element
            return CaptureResult(text: text, source: .accessibility)
        }
        // Browsers (Gmail), Electron apps (WhatsApp, Slack) and terminals don't expose
        // their selection through Accessibility, so fall back to copying it.
        guard let text = await copySelection() else { return nil }
        return CaptureResult(text: text, source: .copiedSelection)
    }

    /// Replaces the original selection: a direct Accessibility write when the field supports it (instant, clipboard
    /// untouched), otherwise Command-V in the source app with the user's clipboard restored afterwards.
    /// `requireSameFocus` refuses when the user has since moved to another app or field.
    func replaceSelection(with text: String, requireSameFocus: Bool = false) async -> Bool {
        guard let sourceApp, !sourceApp.isTerminated, AXIsProcessTrusted() else { return false }
        if requireSameFocus, !focusIsUnchanged(app: sourceApp) { return false }
        if let sourceElement, write(text, to: sourceElement) {
            sourceApp.activate()
            return true
        }
        return await paste(text, into: sourceApp)
    }

    private func focusIsUnchanged(app: NSRunningApplication) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else { return false }
        // A copied selection has no element to compare; the app check is all we have.
        guard let sourceElement else { return true }
        return focusedElement().map { CFEqual($0, sourceElement) } ?? false
    }

    private func focusedElement() -> AXUIElement? {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused else { return nil }
        return unsafeDowncast(focused, to: AXUIElement.self)
    }

    private func selectedText(of element: AXUIElement) -> String? {
        guard let text = attribute(kAXSelectedTextAttribute, of: element),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    private func attribute(_ name: String, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func write(_ text: String, to element: AXUIElement) -> Bool {
        let before = attribute(kAXValueAttribute, of: element)
        guard AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success else {
            return false
        }
        // Some apps report success without changing anything. Trust the write only if the value changed;
        // when the value is unreadable, trust the success code rather than risk pasting the text twice.
        guard let before else { return true }
        return attribute(kAXValueAttribute, of: element) != before
    }

    private func paste(_ text: String, into app: NSRunningApplication) async -> Bool {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        // nspasteboard.org convention: clipboard managers (Maccy, Raycast, Paste) skip transient items.
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
        let written = pasteboard.changeCount

        app.activate()
        // Wait until the app is really frontmost rather than sleeping a fixed time; it may already be.
        let deadline = ContinuousClock.now + .seconds(1)
        while NSWorkspace.shared.frontmostApplication?.processIdentifier != app.processIdentifier, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
            restore(saved, to: pasteboard)
            return false
        }
        try? await Task.sleep(for: .milliseconds(50))
        postCommand(key: CGKeyCode(kVK_ANSI_V))
        // There is no "paste finished" signal and Electron apps read the pasteboard late, so restore after a grace
        // period, and only if nothing else (like the user copying) has written to it since.
        try? await Task.sleep(for: .milliseconds(500))
        if pasteboard.changeCount == written { restore(saved, to: pasteboard) }
        return true
    }

    private func copySelection() async -> String? {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)
        let before = pasteboard.changeCount
        postCommand(key: CGKeyCode(kVK_ANSI_C))
        let deadline = ContinuousClock.now + .milliseconds(400)
        while pasteboard.changeCount == before, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
        guard pasteboard.changeCount != before else { return nil }
        let text = pasteboard.string(forType: .string)
        // Put the user's clipboard back; the copy was only a way to read the selection.
        restore(saved, to: pasteboard)
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    private func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    private func restore(_ items: [NSPasteboardItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
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
