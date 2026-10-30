import Carbon.HIToolbox

@MainActor
final class HotKeyService: @unchecked Sendable {
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handler: @MainActor @Sendable () -> Void
    /// Every service's Carbon handler sees every Tweaky hotkey; the id tells them apart.
    private let identifier: UInt32

    init(identifier: UInt32 = 1, handler: @escaping @MainActor @Sendable () -> Void) {
        self.identifier = identifier
        self.handler = handler
    }

    func start(shortcut: GlobalShortcut) {
        stop()
        var specification = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<HotKeyService>.fromOpaque(context).takeUnretainedValue()
            var pressed = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed
            )
            // Not ours: let the next handler (the other Tweaky hotkey) take it.
            guard pressed.id == service.identifier else { return OSStatus(eventNotHandledErr) }
            Task { @MainActor in service.invoke() }
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(), callback, 1, &specification,
            Unmanaged.passUnretained(self).toOpaque(), &eventHandler
        )

        let keyCode: UInt32
        let modifiers: UInt32
        switch shortcut {
        case .optionSpace:
            keyCode = UInt32(kVK_Space)
            modifiers = UInt32(optionKey)
        case .optionShiftSpace:
            keyCode = UInt32(kVK_Space)
            modifiers = UInt32(optionKey | shiftKey)
        case .commandShiftT:
            keyCode = UInt32(kVK_ANSI_T)
            modifiers = UInt32(cmdKey | shiftKey)
        }
        let hotKeyID = EventHotKeyID(signature: fourCharacterCode("QTXT"), id: identifier)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKey)
    }

    func stop() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        hotKey = nil
        eventHandler = nil
    }

    private func invoke() { handler() }

    private func fourCharacterCode(_ value: String) -> OSType {
        value.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
