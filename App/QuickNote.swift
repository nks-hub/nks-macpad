import AppKit
import Carbon

final class QuickNoteShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    let action: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) throws {
        self.action = action
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let shortcut = Unmanaged<QuickNoteShortcut>.fromOpaque(userData).takeUnretainedValue()
            shortcut.action()
            return noErr
        }, 1, &event, context, &handler)
        guard result == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(result)) }
        let registered = RegisterEventHotKey(keyCode, modifiers, EventHotKeyID(signature: 0x4D504144, id: 1),
                                             GetApplicationEventTarget(), 0, &hotKey)
        if registered != noErr {
            if let handler { RemoveEventHandler(handler); self.handler = nil }
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(registered))
        }
    }
    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}

final class ShortcutRecorder: NSButton {
    var recorded: ((NSEvent) -> Void)?
    var displayTitle = ""
    override var acceptsFirstResponder: Bool { true }
    @objc func beginRecording(_ sender: Any?) {
        title = L("Stiskněte zkratku…", "Press a shortcut…")
        window?.makeFirstResponder(self)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { title = displayTitle; window?.makeFirstResponder(nil); return }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.intersection([.command, .control, .option]).isEmpty else { NSSound.beep(); return }
        recorded?(event)
        window?.makeFirstResponder(nil)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if window?.firstResponder === self { keyDown(with: event); return true }
        return super.performKeyEquivalent(with: event)
    }
}

extension AppDelegate {
    func updateStatusItem() {
        if UserDefaults.standard.bool(forKey: "menuBar") {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                statusItem?.button?.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: L("Rychlá poznámka", "Quick note"))
                statusItem?.button?.target = self
                statusItem?.button?.action = #selector(quickNote(_:))
            }
        } else if let statusItem { NSStatusBar.system.removeStatusItem(statusItem); self.statusItem = nil }
        if let code = UserDefaults.standard.object(forKey: "quickKey") as? Int {
            _ = registerShortcut(keyCode: UInt32(clamping: code), modifiers: UInt32(clamping: UserDefaults.standard.integer(forKey: "quickModifiers")))
        } else {
            hotKey = nil
            registeredShortcut = nil
        }
    }

    @discardableResult
    func registerShortcut(keyCode: UInt32, modifiers: UInt32) -> Bool {
        if let registeredShortcut, registeredShortcut.0 == keyCode, registeredShortcut.1 == modifiers { return true }
        do {
            let shortcut = try QuickNoteShortcut(keyCode: keyCode, modifiers: modifiers) { [weak self] in self?.quickNote(nil) }
            hotKey = shortcut
            registeredShortcut = (keyCode, modifiers)
            return true
        } catch {
            showError(L("Zkratku nelze zaregistrovat. Původní zkratka zůstává zachována. Zvolte jinou kombinaci.",
                        "Cannot register this shortcut. Your previous shortcut is unchanged. Choose another combination."))
            return false
        }
    }

    @objc func quickNote(_ sender: Any?) {
        guard !editingLocked else { return }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApplication = NSWorkspace.shared.frontmostApplication
        }
        let editor = editors.first(where: \.quick) ?? makeWindow(quick: true)
        if editor.notes.isEmpty { editor.addNote(TextDocument()) }
        NSApp.activate(ignoringOtherApps: true)
        editor.showWindow(nil)
        editor.window?.makeFirstResponder(editor.textView)
        changed()
    }
}
