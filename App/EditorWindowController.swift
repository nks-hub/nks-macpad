import AppKit
import MacPadCore

final class EditorWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, NSSearchFieldDelegate {
    unowned let app: AppDelegate
    let id: UUID
    var quick: Bool
    var notes: [TextDocument] = []
    var activeID: UUID?
    var textViews: [UUID: EditorTextView] = [:]
    let tabs = NSStackView()
    let tabScroller = NSScrollView()
    let body = NSView()
    let statusBar = NotepadStatusBar()
    var status: NSTextField { statusBar.position }
    let titlebar = NotepadTitlebar()
    let menuRow = ChromeSurface()
    let addTabButton = ChromeButton()
    let tabListButton = ChromeButton()
    let findAll = NSSearchField()
    let resultsScroller = NSScrollView()
    let results = SearchResultsStack()
    let layout = NSStackView()
    var focusMode = false
    var allowClose = false
    var panel: CommandPanel?
    var searchWork: DispatchWorkItem?
    var searchGeneration = 0
    var busyClosing = false
    private var tabsWidth: NSLayoutConstraint?
    private var restoringViewState = false
    private var displayedTabs: [TabPresentation] = []
    private var metricsNoteID: UUID?
    private var metricsRevision: UInt64?
    private var lineStarts = [0]
    private var characterCount = 0

    private struct TabPresentation: Equatable {
        let id: UUID
        let title: String
        let path: String?
        let pinned: Bool
        let dirty: Bool
        let selected: Bool
    }

    init(app: AppDelegate, quick: Bool = false, id: UUID = UUID()) {
        self.app = app
        self.id = id
        self.quick = quick
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: quick ? 480 : 960, height: quick ? 340 : 680),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.minSize = NSSize(width: 420, height: 260)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.backgroundColor = NotepadColors.canvas
        window.center()
        super.init(window: window)
        window.delegate = self
        buildView()
    }

    required init?(coder: NSCoder) { fatalError("Use init(app:)") }
    var active: TextDocument? { notes.first { $0.id == activeID } }
    var textView: EditorTextView? { activeID.flatMap { textViews[$0] } }

    func buildView() {
        guard let window else { return }
        layout.orientation = .vertical
        layout.alignment = .centerX
        layout.spacing = 0
        layout.translatesAutoresizingMaskIntoConstraints = false
        let root = FileDropView()
        root.openFiles = { [weak app] urls in app?.open(urls) }
        window.contentView = root
        root.addSubview(layout)
        NSLayoutConstraint.activate([
            layout.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            layout.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            layout.topAnchor.constraint(equalTo: root.topAnchor),
            layout.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        buildTitlebar()
        buildMenuRow()

        findAll.placeholderString = L("Hledat ve všech otevřených poznámkách", "Search all open notes")
        findAll.target = self
        findAll.action = #selector(searchAllChanged(_:))
        findAll.delegate = self
        findAll.sendsSearchStringImmediately = true
        findAll.controlSize = .large
        findAll.font = .systemFont(ofSize: 13)
        findAll.setAccessibilityIdentifier("search-all")
        findAll.translatesAutoresizingMaskIntoConstraints = false
        layout.addArrangedSubview(findAll)
        findAll.heightAnchor.constraint(equalToConstant: 36).isActive = true
        findAll.widthAnchor.constraint(equalTo: layout.widthAnchor, constant: -24).isActive = true
        findAll.isHidden = true
        results.orientation = .vertical
        results.alignment = .leading
        results.spacing = 2
        results.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        results.translatesAutoresizingMaskIntoConstraints = false
        resultsScroller.documentView = results
        resultsScroller.clipsToBounds = true
        resultsScroller.hasVerticalScroller = true
        resultsScroller.autohidesScrollers = true
        resultsScroller.drawsBackground = true
        resultsScroller.backgroundColor = NotepadColors.canvas
        resultsScroller.borderType = .noBorder
        resultsScroller.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            results.leadingAnchor.constraint(equalTo: resultsScroller.contentView.leadingAnchor),
            results.topAnchor.constraint(equalTo: resultsScroller.contentView.topAnchor),
            results.widthAnchor.constraint(equalTo: resultsScroller.contentView.widthAnchor),
            results.heightAnchor.constraint(greaterThanOrEqualToConstant: 1),
            resultsScroller.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            resultsScroller.heightAnchor.constraint(lessThanOrEqualToConstant: 132)
        ])
        let preferredResultsHeight = resultsScroller.heightAnchor.constraint(equalToConstant: 132)
        preferredResultsHeight.priority = .defaultHigh
        preferredResultsHeight.isActive = true
        layout.addArrangedSubview(resultsScroller)
        resultsScroller.isHidden = true
        layout.addArrangedSubview(body)
        body.clipsToBounds = true
        body.translatesAutoresizingMaskIntoConstraints = false
        body.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        body.setContentHuggingPriority(.defaultLow, for: .vertical)
        layout.addArrangedSubview(statusBar)
        statusBar.heightAnchor.constraint(equalToConstant: 32).isActive = true
        for view in [titlebar, menuRow, resultsScroller, body, statusBar] {
            view.translatesAutoresizingMaskIntoConstraints = false
            view.widthAnchor.constraint(equalTo: layout.widthAnchor).isActive = true
        }
    }

    private func buildTitlebar() {
        layout.addArrangedSubview(titlebar)
        titlebar.translatesAutoresizingMaskIntoConstraints = false
        titlebar.heightAnchor.constraint(equalToConstant: 44).isActive = true
        tabs.orientation = .horizontal
        tabs.spacing = 2
        tabs.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 2)
        tabScroller.documentView = tabs
        tabScroller.clipsToBounds = true
        tabScroller.hasHorizontalScroller = true
        tabScroller.autohidesScrollers = true
        tabScroller.scrollerStyle = .overlay
        tabScroller.drawsBackground = false
        tabScroller.translatesAutoresizingMaskIntoConstraints = false
        tabScroller.borderType = .noBorder
        tabs.translatesAutoresizingMaskIntoConstraints = false
        titlebar.addSubview(tabScroller)
        let controls = NSStackView(views: [addTabButton, tabListButton])
        controls.spacing = 2
        controls.translatesAutoresizingMaskIntoConstraints = false
        titlebar.addSubview(controls)
        for (button, symbol, label, selector) in [
            (addTabButton, "plus", L("Nová karta", "New tab"), #selector(newNote(_:))),
            (tabListButton, "chevron.down", L("Seznam karet", "Tab list"), #selector(switchNote(_:)))
        ] {
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.target = self
            button.action = selector
            button.toolTip = label
            button.setAccessibilityLabel(label)
            button.widthAnchor.constraint(equalToConstant: 28).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        }
        addTabButton.setAccessibilityIdentifier("new-tab")
        tabsWidth = tabs.widthAnchor.constraint(equalToConstant: 200)
        NSLayoutConstraint.activate([
            tabScroller.leadingAnchor.constraint(equalTo: titlebar.leadingAnchor, constant: 84),
            tabScroller.topAnchor.constraint(equalTo: titlebar.topAnchor, constant: 8),
            tabScroller.bottomAnchor.constraint(equalTo: titlebar.bottomAnchor),
            tabScroller.trailingAnchor.constraint(equalTo: controls.leadingAnchor, constant: -6),
            controls.trailingAnchor.constraint(equalTo: titlebar.trailingAnchor, constant: -10),
            controls.centerYAnchor.constraint(equalTo: tabScroller.centerYAnchor),
            tabs.leadingAnchor.constraint(equalTo: tabScroller.contentView.leadingAnchor),
            tabs.topAnchor.constraint(equalTo: tabScroller.contentView.topAnchor),
            tabs.heightAnchor.constraint(equalToConstant: 36), tabsWidth!
        ])
    }

    private func buildMenuRow() {
        menuRow.bottomBorder = true
        layout.addArrangedSubview(menuRow)
        menuRow.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let row = NSStackView()
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false
        menuRow.addSubview(row)
        for (title, sectionAction) in [
            (L("Soubor", "File"), #selector(AppDelegate.openPanel(_:))),
            (L("Úpravy", "Edit"), #selector(NSText.cut(_:))),
            (L("Zobrazení", "View"), #selector(toggleWrap(_:)))
        ] {
            let button = ChromeMenuButton()
            button.title = title
            button.menuProvider = {
                guard let source = NSApp.mainMenu?.items.compactMap(\.submenu).first(where: { menu in
                    menu.items.contains { $0.action == sectionAction }
                }),
                      let copy = source.copy() as? NSMenu else { return nil }
                if sectionAction == #selector(NSText.cut(_:)),
                   let text = NSApp.mainMenu?.items.first(where: { $0.title == "Text" })?.copy() as? NSMenuItem {
                    copy.addItem(.separator())
                    copy.addItem(text)
                }
                return copy
            }
            button.widthAnchor.constraint(equalToConstant: max(58, button.intrinsicContentSize.width + 22)).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
            row.addArrangedSubview(button)
        }
        let settings = ChromeButton()
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: L("Nastavení", "Settings"))
        settings.imagePosition = .imageOnly
        settings.imageScaling = .scaleProportionallyDown
        settings.target = app
        settings.action = #selector(AppDelegate.showPreferences(_:))
        settings.toolTip = L("Nastavení", "Settings")
        settings.setAccessibilityIdentifier("settings")
        settings.translatesAutoresizingMaskIntoConstraints = false
        menuRow.addSubview(settings)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: menuRow.leadingAnchor, constant: 10),
            row.centerYAnchor.constraint(equalTo: menuRow.centerYAnchor),
            settings.trailingAnchor.constraint(equalTo: menuRow.trailingAnchor, constant: -12),
            settings.centerYAnchor.constraint(equalTo: menuRow.centerYAnchor),
            settings.widthAnchor.constraint(equalToConstant: 28),
            settings.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    func applyFocusMode() {
        tabScroller.isHidden = focusMode
        addTabButton.isHidden = focusMode
        tabListButton.isHidden = focusMode
        menuRow.isHidden = focusMode
        statusBar.isHidden = focusMode
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if control === findAll, commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            escape()
            return true
        }
        return false
    }

    func addNote(_ note: TextDocument, replacingEmpty: Bool = false) {
        if replacingEmpty, let current = active, current.fileURL == nil, current.text.isEmpty,
           current.customTitle == nil, !current.pinned {
            notes.removeAll { $0 === current }
            textViews.removeValue(forKey: current.id)
        }
        notes.append(note)
        select(note.id)
        app.changed()
        app.refreshSearchResults()
    }

    func select(_ id: UUID) {
        captureSelection()
        activeID = id
        refresh()
        checkExternalChanges()
    }

    func captureSelection() {
        guard !restoringViewState, let note = active, let view = textView else { return }
        let range = view.selectedRange()
        let length = (view.string as NSString).length
        let location = min(range.location, length)
        note.selection = NSRange(location: location, length: min(range.length, length - location))
        note.scrollY = max(0, Double(view.enclosingScrollView?.contentView.bounds.minY ?? 0))
    }

    func refresh() {
        restoringViewState = true
        defer { restoringViewState = false }
        if active == nil { activeID = notes.first?.id }
        body.subviews.forEach { $0.removeFromSuperview() }
        if let note = active {
            let selection = note.selection
            let scrollY = note.scrollY
            let view: EditorTextView
            if let existing = textViews[note.id] { view = existing }
            else {
                view = EditorTextView(frame: .zero)
                view.owner = self
                view.note = note
                view.delegate = self
                view.isRichText = false
                view.importsGraphics = false
                view.allowsUndo = true
                view.usesFindBar = true
                view.isIncrementalSearchingEnabled = false
                view.isAutomaticQuoteSubstitutionEnabled = false
                view.isAutomaticDashSubstitutionEnabled = false
                view.isAutomaticTextReplacementEnabled = false
                view.isAutomaticSpellingCorrectionEnabled = false
                view.isContinuousSpellCheckingEnabled = false
                view.isAutomaticLinkDetectionEnabled = false
                view.textContainerInset = NSSize(width: 18, height: 18)
                view.autoresizingMask = [.width]
                view.isVerticallyResizable = true
                view.minSize = NSSize(width: 0, height: 0)
                view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                view.string = note.text
                view.textStorage?.delegate = view
                view.setAccessibilityIdentifier("note-editor")
                textViews[note.id] = view
            }
            let scroll = view.enclosingScrollView ?? NSScrollView()
            scroll.hasVerticalScroller = true
            scroll.clipsToBounds = true
            scroll.autohidesScrollers = true
            scroll.borderType = .noBorder
            scroll.backgroundColor = NotepadColors.canvas
            scroll.documentView = view
            scroll.translatesAutoresizingMaskIntoConstraints = false
            body.addSubview(scroll)
            NSLayoutConstraint.activate([
                scroll.leadingAnchor.constraint(equalTo: body.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: body.trailingAnchor),
                scroll.topAnchor.constraint(equalTo: body.topAnchor),
                scroll.bottomAnchor.constraint(equalTo: body.bottomAnchor)
            ])
            configure(view)
            window?.contentView?.layoutSubtreeIfNeeded()
            if let container = view.textContainer { view.layoutManager?.ensureLayout(for: container) }
            view.setSelectedRange(selection)
            window?.makeFirstResponder(view)
            scroll.contentView.scroll(to: NSPoint(x: 0, y: scrollY))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        refreshTitles()
    }

    func configure(_ view: EditorTextView) {
        view.font = Preferences.font
        view.textColor = .textColor
        view.backgroundColor = .textBackgroundColor
        view.insertionPointColor = .textColor
        if let scroll = view.enclosingScrollView {
            if scroll.verticalRulerView == nil { scroll.verticalRulerView = LineNumbers(scrollView: scroll, editor: view) }
            scroll.hasVerticalRuler = true
            scroll.rulersVisible = UserDefaults.standard.bool(forKey: "lineNumbers")
        }
        view.isHorizontallyResizable = !Preferences.wrap
        view.enclosingScrollView?.hasHorizontalScroller = !Preferences.wrap
        view.textContainer?.widthTracksTextView = Preferences.wrap
        view.textContainer?.containerSize = NSSize(width: Preferences.wrap ? max(body.bounds.width, 400) : .greatestFiniteMagnitude,
                                                   height: .greatestFiniteMagnitude)
    }

    func refreshTitles() {
        let ordered = notes.filter(\.pinned) + notes.filter { !$0.pinned }
        let presentation = ordered.map { note in
            TabPresentation(id: note.id, title: note.title, path: note.fileURL?.path,
                            pinned: note.pinned, dirty: note.isDocumentEdited, selected: note.id == activeID)
        }
        guard presentation != displayedTabs else { updateStatus(); return }
        displayedTabs = presentation
        tabs.arrangedSubviews.forEach { tabs.removeArrangedSubview($0); $0.removeFromSuperview() }
        var totalWidth: CGFloat = 0
        for note in ordered {
            let button = TabButton(title: note.title, target: self, action: #selector(tabSelected(_:)))
            button.noteID = note.id
            button.owner = self
            button.dirty = note.isDocumentEdited
            button.pinned = note.pinned
            button.state = note.id == activeID ? .on : .off
            button.toolTip = note.fileURL?.path ?? note.title
            button.setAccessibilityLabel(note.title + (note.isDocumentEdited ? L(", neuložené změny", ", unsaved changes") : ""))
            button.setAccessibilityIdentifier("tab-" + note.id.uuidString)
            let titleWidth = (note.title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12)]).width
            let width = min(230, max(170, titleWidth + 82))
            button.widthAnchor.constraint(equalToConstant: width).isActive = true
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
            totalWidth += width + 2
            button.lineBreakMode = .byTruncatingTail
            let menu = NSMenu()
            for (title, selector) in [(L("Připnout / odepnout", "Pin / unpin"), #selector(togglePin(_:))),
                                      (L("Pojmenovat koncept…", "Name draft…"), #selector(renameNote(_:))),
                                      (L("Do nového okna", "Move to new window"), #selector(moveToWindow(_:))),
                                      (L("Zavřít kartu", "Close tab"), #selector(closeNote(_:)))] {
                let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
                item.target = self
                item.representedObject = note.id
                menu.addItem(item)
            }
            button.menu = menu
            tabs.addArrangedSubview(button)
        }
        tabsWidth?.constant = max(2, totalWidth)
        tabs.layoutSubtreeIfNeeded()
        if let selected = tabs.arrangedSubviews.compactMap({ $0 as? TabButton }).first(where: { $0.noteID == activeID }) {
            selected.scrollToVisible(selected.bounds)
        }
        window?.title = (active?.title ?? "MacPad") + " — MacPad"
        window?.isDocumentEdited = active?.isDocumentEdited ?? false
        updateStatus()
    }

    func updateStatus() {
        guard let note = active else { status.stringValue = ""; return }
        statusBar.hasWarning = app.sessionFailure != nil || note.externalChange
        if let failure = app.sessionFailure {
            status.stringValue = L("Koncept není bezpečně zachován: ", "Draft recovery failed: ") + failure
            status.textColor = .systemRed
            return
        }
        if app.pendingOpenCount > 0 {
            status.stringValue = L("Otevírání souborů…", "Opening files…")
            status.toolTip = L("Zrušit: ⌘. nebo nabídka Soubor", "Cancel: ⌘. or the File menu")
            return
        }
        status.textColor = .secondaryLabelColor
        let value = note.text as NSString
        let selection = textView?.selectedRange() ?? note.selection
        if metricsNoteID != note.id || metricsRevision != note.revision {
            lineStarts = [0]
            for (offset, unit) in note.text.utf16.enumerated() where unit == 10 { lineStarts.append(offset + 1) }
            characterCount = note.text.count
            metricsNoteID = note.id
            metricsRevision = note.revision
        }
        let location = min(selection.location, value.length)
        var lower = 0
        var upper = lineStarts.count
        while lower < upper {
            let middle = (lower + upper) / 2
            if lineStarts[middle] <= location { lower = middle + 1 } else { upper = middle }
        }
        let lineIndex = max(0, lower - 1)
        let line = lineIndex + 1
        let column = value.substring(with: NSRange(location: lineStarts[lineIndex], length: location - lineStarts[lineIndex])).count + 1
        let count = selection.length > 0
            ? value.substring(with: NSRange(location: min(selection.location, value.length), length: min(selection.length, max(0, value.length - selection.location)))).count
            : characterCount
        let selected = selection.length > 0 ? L(" vybráno", " selected") : L(" znaků", " characters")
        status.stringValue = (note.externalChange ? L("Soubor změněn nebo nedostupný. ", "File changed or unavailable. ") : "")
            + "\(L("Ř.", "Ln")) \(line), \(L("sl.", "Col")) \(column)"
        statusBar.count.stringValue = "\(count)\(selected)"
        statusBar.zoom.stringValue = "\(Int(Preferences.fontSize / 14 * 100)) %"
        switch note.format.encoding {
        case .utf8: statusBar.encoding.stringValue = "UTF-8"
        case .utf8BOM: statusBar.encoding.stringValue = "UTF-8 BOM"
        case .utf16LE: statusBar.encoding.stringValue = "UTF-16 LE"
        case .utf16BE: statusBar.encoding.stringValue = "UTF-16 BE"
        case .windows1250: statusBar.encoding.stringValue = "Windows-1250"
        }
        statusBar.lineEnding.stringValue = note.format.lineEnding.rawValue.uppercased()
        status.toolTip = status.stringValue + " · " + statusBar.count.stringValue
        statusBar.encoding.toolTip = L("Kódování souboru", "File encoding")
        statusBar.lineEnding.toolTip = L("Konce řádků", "Line endings")
        statusBar.zoom.toolTip = L("Velikost textu", "Text size")
    }

    func textDidChange(_ notification: Notification) {
        guard let view = notification.object as? EditorTextView else { return }
        synchronize(view)
        captureSelection()
        updateStatus()
    }

    func synchronize(_ view: EditorTextView) {
        guard let note = view.note, !note.text.utf8.elementsEqual(view.string.utf8) else { return }
        note.changed(to: view.string)
        view.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        app.changed()
        app.refreshSearchResults()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !restoringViewState else { return }
        captureSelection()
        updateStatus()
        app.sessionPending = true
    }

    func undoManager(for view: NSTextView) -> UndoManager? { (view as? EditorTextView)?.note?.undoManager }

    func reload(_ note: TextDocument) {
        textViews[note.id]?.string = note.text
        if activeID == note.id { refresh() }
    }

    func snapshot() -> WindowSnapshot {
        captureSelection()
        return WindowSnapshot(id: id, notes: notes.map { $0.snapshot() }, activeNoteID: activeID,
                              frame: window.map { NSStringFromRect($0.frame) }, quickNote: quick,
                              visible: window?.isVisible ?? false)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if allowClose { return true }
        guard !app.editingLocked, !busyClosing, !notes.contains(where: \.saving) else { return false }
        busyClosing = true
        app.lockEditing(true)
        if Preferences.restore {
            app.flushSession { ok in
                self.busyClosing = false
                self.app.lockEditing(false)
                if ok {
                    sender.orderOut(nil)
                    self.app.changed()
                    if self.quick { self.app.restoreQuickNoteFocus() }
                } else { self.app.showError(self.app.sessionFailure ?? "Session write failed") }
            }
        } else {
            app.resolveChanges(notes) { ok in
                self.busyClosing = false
                self.app.lockEditing(false)
                if ok {
                    self.notes.removeAll()
                    self.app.editors.removeAll { $0 === self }
                    self.app.refreshSearchResults()
                    self.allowClose = true
                    sender.close()
                }
            }
        }
        return false
    }

    func windowDidResize(_ notification: Notification) { app.sessionPending = true }
    func windowDidMove(_ notification: Notification) { app.sessionPending = true }
    func windowDidBecomeKey(_ notification: Notification) { checkExternalChanges() }

    @objc func tabSelected(_ sender: TabButton) { if let id = sender.noteID { select(id) } }
    @objc func newNote(_ sender: Any?) { addNote(TextDocument()) }
}
