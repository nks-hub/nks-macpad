import AppKit

final class FileDropView: NSView {
    var openFiles: (([URL]) -> Void)?
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty else { return false }
        openFiles?(urls)
        return true
    }
}

final class TabButton: NSButton, NSDraggingSource {
    override var mouseDownCanMoveWindow: Bool { false }
    static let pasteboardType = NSPasteboard.PasteboardType("com.nkshub.macpad.tab")
    var noteID: UUID?
    weak var owner: EditorWindowController?
    var dirty = false { didSet { needsDisplay = true } }
    var pinned = false { didSet { needsDisplay = true } }
    private let closeButton = ChromeButton()
    private var tracking: NSTrackingArea?
    private var hovered = false
    override var isFlipped: Bool { true }
    override var state: NSControl.StateValue {
        didSet { updateCloseButton(); needsDisplay = true }
    }
    override var intrinsicContentSize: NSSize { NSSize(width: 200, height: 36) }
    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = false
        setButtonType(.momentaryPushIn)
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: L("Zavřít kartu", "Close tab"))
        closeButton.imageScaling = .scaleProportionallyDown
        closeButton.imagePosition = .imageOnly
        closeButton.target = self
        closeButton.action = #selector(closeTab(_:))
        closeButton.toolTip = L("Zavřít kartu", "Close tab")
        closeButton.setAccessibilityLabel(L("Zavřít kartu", "Close tab"))
        addSubview(closeButton)
        updateCloseButton()
        registerForDraggedTypes([Self.pasteboardType])
    }
    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }
    override func layout() {
        super.layout()
        closeButton.frame = NSRect(x: bounds.width - 29, y: 8, width: 21, height: 21)
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .mouseEnteredAndExited, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; updateCloseButton(); needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; updateCloseButton(); needsDisplay = true }
    private func updateCloseButton() { closeButton.isHidden = !hovered && state != .on }
    @objc private func closeTab(_ sender: Any?) {
        guard let noteID else { return }
        let item = NSMenuItem()
        item.representedObject = noteID
        owner?.closeNote(item)
    }
    override func draw(_ dirtyRect: NSRect) {
        let active = state == .on
        if active {
            let path = NSBezierPath()
            path.move(to: NSPoint(x: 0, y: bounds.height))
            path.line(to: NSPoint(x: 0, y: 9))
            path.curve(to: NSPoint(x: 9, y: 0), controlPoint1: NSPoint(x: 0, y: 3), controlPoint2: NSPoint(x: 3, y: 0))
            path.line(to: NSPoint(x: bounds.width - 9, y: 0))
            path.curve(to: NSPoint(x: bounds.width, y: 9), controlPoint1: NSPoint(x: bounds.width - 3, y: 0), controlPoint2: NSPoint(x: bounds.width, y: 3))
            path.line(to: NSPoint(x: bounds.width, y: bounds.height))
            path.close()
            NotepadColors.canvas.setFill()
            path.fill()
            if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
                NSColor.separatorColor.setStroke()
                path.lineWidth = 1
                path.stroke()
            }
        } else if hovered {
            NotepadColors.hover.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 3), xRadius: 7, yRadius: 7).fill()
        }
        let image = NSImage(systemSymbolName: pinned ? "pin.fill" : "doc.text", accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .regular))
        let tinted = image?.copy() as? NSImage
        tinted?.lockFocus()
        (active ? NSColor.controlAccentColor : NSColor.secondaryLabelColor).setFill()
        if let size = tinted?.size { NSRect(origin: .zero, size: size).fill(using: .sourceAtop) }
        tinted?.unlockFocus()
        tinted?.draw(in: NSRect(x: 12, y: 11, width: 14, height: 14))
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let text = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: active ? .medium : .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ])
        text.draw(in: NSRect(x: 35, y: 10, width: max(0, bounds.width - 78), height: 18))
        if dirty {
            NSColor.secondaryLabelColor.setFill()
            NSBezierPath(ovalIn: NSRect(x: bounds.width - (closeButton.isHidden ? 19 : 39), y: 16, width: 5, height: 5)).fill()
        }
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 7, yRadius: 7)
            ring.lineWidth = 2
            ring.stroke()
        }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let noteID else { return }
        let item = NSPasteboardItem()
        item.setString(noteID.uuidString, forType: Self.pasteboardType)
        let drag = NSDraggingItem(pasteboardWriter: item)
        drag.setDraggingFrame(bounds, contents: NSImage(size: bounds.size, flipped: false) { rect in
            self.draw(rect); return true
        })
        beginDraggingSession(with: [drag], event: event, source: self)
    }
    override func mouseDown(with event: NSEvent) {
        guard isEnabled, owner?.app.editingLocked == false else { return }
        let start = event.locationInWindow
        isHighlighted = true
        defer { isHighlighted = false; needsDisplay = true }
        while let next = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) {
            if next.type == .leftMouseUp { performClick(nil); return }
            if hypot(next.locationInWindow.x - start.x, next.locationInWindow.y - start.y) > 4 {
                mouseDragged(with: next)
                return
            }
        }
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .move }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .move }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let raw = sender.draggingPasteboard.string(forType: Self.pasteboardType), let id = UUID(uuidString: raw),
              let target = owner, let app = owner?.app,
              let source = app.editors.first(where: { $0.notes.contains { $0.id == id } }),
              let note = source.notes.first(where: { $0.id == id }), id != noteID else { return false }
        source.move(note, to: target, before: noteID)
        return true
    }
}

final class EditorTextView: NSTextView, NSTextStorageDelegate {
    weak var owner: EditorWindowController?
    weak var note: TextDocument?
    override var undoManager: UndoManager? { note?.undoManager }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        guard isEditable else { return }
        let text = (insertString as? NSAttributedString)?.string ?? (insertString as? String)
        guard let text else { super.insertText(insertString, replacementRange: replacementRange); return }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        super.insertText(normalized, replacementRange: replacementRange)
    }

    override func paste(_ sender: Any?) { pasteAsPlainText(sender) }
    override func pasteAsPlainText(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        insertCommandText(text, name: L("Vložit", "Paste"))
    }

    /// insertText counts as typing, so without breaks the command would share one undo step with the typing around it.
    func insertCommandText(_ text: String, name: String) {
        breakUndoCoalescing()
        insertText(text, replacementRange: selectedRange())
        breakUndoCoalescing()
        undoManager?.setActionName(name)
    }

    override func changeFont(_ sender: Any?) { owner?.changeFont(sender) }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            owner?.app.open(urls)
            return true
        }
        return super.performDragOperation(sender)
    }

    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        if editedMask.contains(.editedCharacters) {
            owner?.synchronize(self, editedRange: editedRange, changeInLength: delta)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.control, .shift, .option, .command])
        // The window offers key equivalents to every view, including editors behind a focused search field.
        if window?.firstResponder === self, modifiers == .control || modifiers == [.control, .shift] {
            if hasMarkedText() { return super.performKeyEquivalent(with: event) }
            let shifted = modifiers.contains(.shift)
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "a": selectAll(nil)
            case "c": copy(nil)
            case "x": cut(nil)
            case "v": pasteAsPlainText(nil)
            case "z": shifted ? undoManager?.redo() : undoManager?.undo()
            case "y": undoManager?.redo()
            case "n", "t": owner?.newNote(nil)
            case "o": owner?.app.openPanel(nil)
            case "s": shifted ? owner?.saveAs(nil) : owner?.saveNote(nil)
            case "w": owner?.closeNote(nil)
            case "f": owner?.find(nil)
            case "h": owner?.replace(nil)
            case "g": owner?.goToLine(nil)
            case "\t", "\u{19}": owner?.cycleTab(backward: shifted)
            default: return super.performKeyEquivalent(with: event)
            }
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if (event.keyCode == 115 || event.keyCode == 119), !flags.contains(.option), !flags.contains(.command), !hasMarkedText() {
            let beginning = event.keyCode == 115
            if flags.contains(.control) {
                if flags.contains(.shift) { beginning ? moveToBeginningOfDocumentAndModifySelection(nil) : moveToEndOfDocumentAndModifySelection(nil) }
                else { beginning ? moveToBeginningOfDocument(nil) : moveToEndOfDocument(nil) }
            } else {
                if flags.contains(.shift) { beginning ? moveToBeginningOfLineAndModifySelection(nil) : moveToEndOfLineAndModifySelection(nil) }
                else { beginning ? moveToBeginningOfLine(nil) : moveToEndOfLine(nil) }
            }
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) { owner?.escape() }
}
