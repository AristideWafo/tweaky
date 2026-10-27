import ApplicationServices

final class SelectionReader {
    private var sourceElement: AXUIElement?

    func readSelectedText() -> CaptureResult? {
        guard AXIsProcessTrusted() else { return nil }
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return nil }
        let focusedElement = unsafeDowncast(element, to: AXUIElement.self)
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selected) == .success,
              let text = selected as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        sourceElement = focusedElement
        return CaptureResult(text: text, source: .accessibility)
    }

    func replaceSelection(with text: String) -> Bool {
        guard let sourceElement else { return false }
        return AXUIElementSetAttributeValue(sourceElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
    }
}
