import AppKit

enum EditorPane { case primary, secondary }

final class EditorPaneView: NSView {
    private weak var owner: EditorWindowController?
    private let pane: EditorPane
    private let focusButton = NSButton()
    let documents = NSPopUpButton()
    private var titles: [String] = []

    init(owner: EditorWindowController, pane: EditorPane, scroll: NSScrollView) {
        self.owner = owner
        self.pane = pane
        super.init(frame: .zero)
        focusButton.bezelStyle = .inline
        focusButton.lineBreakMode = .byTruncatingTail
        focusButton.target = self
        focusButton.action = #selector(focus(_:))
        documents.controlSize = .small
        documents.target = self
        documents.action = #selector(choose(_:))
        documents.setAccessibilityLabel(pane == .primary ? L("Dokument v levém panelu", "Document in left pane")
                                                        : L("Dokument v pravém panelu", "Document in right pane"))
        let stack = NSStackView(views: [focusButton, documents, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4), stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            focusButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            documents.widthAnchor.constraint(equalTo: stack.widthAnchor), scroll.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        update()
    }

    required init?(coder: NSCoder) { fatalError("Use init(owner:pane:scroll:)") }

    func update() {
        guard let owner else { return }
        let active = owner.focusedPane == pane
        focusButton.isEnabled = !owner.app.editingLocked
        documents.isEnabled = !owner.app.editingLocked
        focusButton.title = (pane == .primary ? L("Levý panel", "Left pane") : L("Pravý panel", "Right pane"))
            + (active ? L(" · aktivní", " · active") : "")
        focusButton.contentTintColor = active ? .controlAccentColor : .secondaryLabelColor
        let notes = owner.notes.filter(\.pinned) + owner.notes.filter { !$0.pinned }
        let currentTitles = notes.map { $0.id.uuidString + $0.title }
        if titles != currentTitles {
            titles = currentTitles
            documents.removeAllItems()
            for note in notes {
                let item = NSMenuItem(title: note.title, action: nil, keyEquivalent: "")
                item.representedObject = note.id
                documents.menu?.addItem(item)
            }
        }
        let id = pane == .primary ? owner.primaryID : owner.secondaryID
        documents.selectItem(at: notes.firstIndex { $0.id == id } ?? -1)
    }

    @objc private func focus(_ sender: Any?) { owner?.focusPane(pane) }
    @objc private func choose(_ sender: Any?) {
        guard let owner, !owner.app.editingLocked, let id = documents.selectedItem?.representedObject as? UUID else { return }
        owner.focusPane(pane)
        owner.select(id)
    }
}

extension EditorWindowController {
    @objc func toggleSplitEditor(_ sender: Any?) {
        guard !app.editingLocked else { return }
        captureSelection()
        let id = activeID
        textView?.breakUndoCoalescing()
        splitEnabled.toggle()
        primaryID = id
        secondaryID = id
        focusedPane = .primary
        refresh()
    }

    @objc func switchEditorPane(_ sender: Any?) { focusPane(focusedPane == .primary ? .secondary : .primary) }

    func editorDidFocus(_ view: EditorTextView) {
        guard !restoringViewState, view.window === window, splitEnabled,
              view.note?.id == (view.pane == .primary ? primaryID : secondaryID) else { return }
        focusPane(view.pane, makeFirstResponder: false)
    }

    func focusPane(_ pane: EditorPane, makeFirstResponder: Bool = true) {
        guard splitEnabled, !app.editingLocked else { return }
        if focusedPane != pane {
            captureSelection()
            textView?.breakUndoCoalescing()
            focusedPane = pane
            captureSelection()
            app.sessionPending = true
            refreshTitles()
            if let active { markdownPreview?.update(active, delay: 0) }
        }
        if makeFirstResponder { window?.makeFirstResponder(textView) }
    }

    func editorView(for note: TextDocument, pane: EditorPane) -> EditorTextView {
        if let existing = (pane == .primary ? textViews : secondaryViews)[note.id] { return existing }
        let view: EditorTextView
        if pane == .secondary {
            let primary = editorView(for: note, pane: .primary)
            let manager = NSLayoutManager()
            let container = NSTextContainer(containerSize: NSSize(width: 400, height: CGFloat.greatestFiniteMagnitude))
            primary.textStorage?.addLayoutManager(manager)
            manager.addTextContainer(container)
            view = EditorTextView(frame: .zero, textContainer: container)
        } else { view = EditorTextView(frame: .zero) }
        view.owner = self
        view.note = note
        view.pane = pane
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = true
        view.isEditable = !app.editingLocked
        view.usesFindBar = true
        view.isIncrementalSearchingEnabled = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.isContinuousSpellCheckingEnabled = false
        view.isAutomaticLinkDetectionEnabled = false
        view.textContainerInset = NSSize(width: 18, height: 18)
        view.layoutManager?.allowsNonContiguousLayout = true
        view.autoresizingMask = [.width]
        view.isVerticallyResizable = true
        view.minSize = NSSize(width: 0, height: 0)
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        if pane == .primary {
            view.string = note.text
            // One delegate synchronizes the document, regardless of which layout manager is editing it.
            view.textStorage?.delegate = view
            textViews[note.id] = view
        } else { secondaryViews[note.id] = view }
        view.setSelectedRange(note.selection)
        view.delegate = self
        view.setAccessibilityIdentifier(pane == .primary ? "note-editor" : "secondary-note-editor")
        return view
    }

    func editorScroll(for view: EditorTextView) -> NSScrollView {
        let scroll = view.enclosingScrollView ?? NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.clipsToBounds = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.backgroundColor = NotepadColors.canvas
        scroll.documentView = view
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }

    func restoreEditorPosition(_ view: EditorTextView, selection: NSRange, scrollY: Double) {
        guard let scroll = view.enclosingScrollView else { return }
        if let container = view.textContainer {
            let viewport = NSRect(origin: NSPoint(x: 0, y: scrollY), size: scroll.contentSize)
            view.layoutManager?.ensureLayout(forBoundingRect: viewport, in: container)
        }
        let length = (view.string as NSString).length
        let location = min(selection.location, length)
        view.setSelectedRange(NSRange(location: location, length: min(selection.length, length - location)))
        scroll.contentView.scroll(to: NSPoint(x: -scroll.contentView.contentInsets.left, y: scrollY))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
}
