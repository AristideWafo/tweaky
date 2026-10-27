import Carbon.HIToolbox

@MainActor
final class HotKeyService: @unchecked Sendable {
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handler: @MainActor @Sendable () -> Void

    init(handler: @escaping @MainActor @Sendable () -> Void) { self.handler = handler }

    func start(shortcut: GlobalShortcut) {
        stop()
        var specification = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<HotKeyService>.fromOpaque(context).takeUnretainedValue()
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
        case .commandShiftT:
            keyCode = UInt32(kVK_ANSI_T)
            modifiers = UInt32(cmdKey | shiftKey)
        }
        let identifier = EventHotKeyID(signature: fourCharacterCode("QTXT"), id: 1)
        RegisterEventHotKey(keyCode, modifiers, identifier, GetApplicationEventTarget(), 0, &hotKey)
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
