import AppKit
import MacPadCore

extension EditorWindowController {
    func noteFor(_ sender: Any?) -> TextDocument? {
        if let id = (sender as? NSMenuItem)?.representedObject as? UUID { return notes.first { $0.id == id } }
        return active
    }

    @objc func saveNote(_ sender: Any?) { if let active { app.save(active) { _ in } } }
    @objc func saveAs(_ sender: Any?) { if let active { app.save(active, as: true) { _ in } } }
    @objc func closeWindow(_ sender: Any?) { window?.performClose(sender) }

    @objc func closeNote(_ sender: Any?) {
        guard !app.editingLocked, !busyClosing, let note = noteFor(sender), !note.saving else { return }
        busyClosing = true
        app.lockEditing(true)
        app.resolveChanges([note]) { ok in
            guard ok else { self.busyClosing = false; self.app.lockEditing(false); return }
            let oldNotes = self.notes
            let oldActive = self.activeID
            let oldPanes = (self.primaryID, self.secondaryID, self.focusedPane)
            self.captureSelection()
            self.notes.removeAll { $0 === note }
            if self.activeID == note.id { self.activeID = self.notes.first?.id }
            if self.notes.isEmpty { self.notes.append(TextDocument()); self.activeID = self.notes[0].id }
            self.refresh()
            self.app.changed()
            self.app.flushSession { stored in
                self.busyClosing = false
                self.app.lockEditing(false)
                if stored {
                    self.textViews.removeValue(forKey: note.id)
                    self.secondaryViews.removeValue(forKey: note.id)
                    if let url = note.fileURL {
                        self.app.closedFiles.append((url, note.selection))
                        self.app.closedFiles = Array(self.app.closedFiles.suffix(20))
                    }
                    self.app.changed()
                    self.app.refreshSearchResults()
                } else {
                    let additions = self.notes.filter { candidate in !oldNotes.contains { $0.id == candidate.id } && !candidate.text.isEmpty }
                    self.notes = oldNotes + additions
                    (self.primaryID, self.secondaryID, self.focusedPane) = oldPanes
                    self.activeID = oldActive
                    self.refresh()
                    self.app.changed()
                    self.app.showError(self.app.sessionFailure ?? L("Relaci se nepodařilo uložit.", "The session could not be saved."))
                }
            }
        }
    }

    @objc func togglePin(_ sender: Any?) {
        guard let note = noteFor(sender) else { return }
        note.pinned.toggle()
        app.changed()
    }

    @objc func renameNote(_ sender: Any?) {
        guard let note = noteFor(sender), note.fileURL == nil else { return }
        if let title = askText(L("Název konceptu", "Draft name"), value: note.customTitle ?? "") {
            note.customTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            app.changed()
            app.refreshSearchResults()
        }
    }

    @objc func moveToWindow(_ sender: Any?) {
        guard let note = noteFor(sender), !note.saving else { return }
        let editor = app.makeWindow()
        move(note, to: editor)
        editor.showWindow(nil)
        if quick { window?.orderOut(nil) }
    }

    func move(_ note: TextDocument, to target: EditorWindowController, before: UUID? = nil) {
        captureSelection()
        if self === target {
            notes.removeAll { $0 === note }
            notes.insert(note, at: notes.firstIndex { $0.id == before } ?? notes.count)
        } else {
            let view = textViews.removeValue(forKey: note.id)
            let secondary = secondaryViews.removeValue(forKey: note.id)
            notes.removeAll { $0 === note }
            refresh()
            target.notes.insert(note, at: target.notes.firstIndex { $0.id == before } ?? target.notes.count)
            if let view {
                view.owner = target
                view.delegate = target
                target.textViews[note.id] = view
            }
            if let secondary {
                secondary.owner = target
                secondary.delegate = target
                target.secondaryViews[note.id] = secondary
            }
            if notes.isEmpty {
                if quick {
                    notes.append(TextDocument())
                    activeID = notes[0].id
                    refresh()
                } else {
                    app.editors.removeAll { $0 === self }
                    allowClose = true
                    window?.close()
                }
            }
        }
        target.select(note.id)
        app.changed()
        app.refreshSearchResults()
    }

    func cycleTab(backward: Bool) {
        guard !notes.isEmpty else { return }
        let ordered = notes.filter(\.pinned) + notes.filter { !$0.pinned }
        let index = ordered.firstIndex { $0.id == activeID } ?? 0
        select(ordered[(index + (backward ? ordered.count - 1 : 1)) % ordered.count].id)
    }

    @objc func find(_ sender: Any?) { performFind(.showFindInterface) }
    @objc func replace(_ sender: Any?) { performFind(.showReplaceInterface) }
    @objc func findNext(_ sender: Any?) { performFind(.nextMatch) }
    @objc func findPrevious(_ sender: Any?) { performFind(.previousMatch) }

    func performFind(_ action: NSTextFinder.Action) {
        let item = NSMenuItem()
        item.tag = action.rawValue
        textView?.performFindPanelAction(item)
    }

    @objc func showSearchAll(_ sender: Any?) {
        findAll.isHidden = false
        resultsScroller.isHidden = false
        window?.makeFirstResponder(findAll)
        searchAllChanged(nil)
    }

    @objc func searchAllChanged(_ sender: Any?) {
        searchWork?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        let query = findAll.stringValue
        results.arrangedSubviews.forEach { results.removeArrangedSubview($0); $0.removeFromSuperview() }
        guard !query.isEmpty else { return }
        let documents = app.editors.flatMap { editor in editor.notes.map { ($0.id, $0.revision, $0.title, $0.text) } }
        let work = BlockOperation()
        work.addExecutionBlock { [weak self, weak work] in
            guard let work, !work.isCancelled else { return }
            var matches: [(UUID, UInt64, String, NSRange)] = []
            for (id, revision, title, text) in documents {
                guard !work.isCancelled else { return }
                // Materialize UTF-16 once instead of bridging Swift storage during each range search.
                let value = NSMutableString(string: text)
                var cursor = 0
                while cursor < value.length && matches.count < 200 {
                    guard !work.isCancelled else { return }
                    let range = value.range(of: query, options: [.caseInsensitive], range: NSRange(location: cursor, length: value.length - cursor))
                    if range.location == NSNotFound { break }
                    let line = value.lineRange(for: range)
                    let excerpt = value.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines)
                    matches.append((id, revision, title + " — " + String(excerpt.prefix(100)), range))
                    cursor = NSMaxRange(range)
                }
                if matches.count == 200 { break }
            }
            DispatchQueue.main.async {
                guard let self, !work.isCancelled, self.searchGeneration == generation, !self.findAll.isHidden else { return }
                for (id, revision, title, range) in matches {
                    let button = ResultButton(title: title, target: nil, action: nil)
                    button.bezelStyle = .inline
                    button.lineBreakMode = .byTruncatingTail
                    button.onClick = { [weak self] in
                        guard let self,
                              let owner = self.app.editors.first(where: { $0.notes.contains { $0.id == id } }),
                              let note = owner.notes.first(where: { $0.id == id }), note.revision == revision else {
                            self?.searchAllChanged(nil); return
                        }
                        owner.select(id)
                        owner.showWindow(nil)
                        owner.textView?.setSelectedRange(range)
                        owner.textView?.scrollRangeToVisible(range)
                    }
                    self.results.addArrangedSubview(button)
                }
                let label = NSTextField(labelWithString: matches.count == 200
                    ? L("Prvních 200 výsledků. Upřesněte hledání.", "First 200 results. Refine your search.")
                    : "\(matches.count) " + L("výsledků", "results"))
                self.results.addArrangedSubview(label)
            }
        }
        searchWork = work
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.15) { work.start() }
    }

    @objc func goToLine(_ sender: Any?) {
        guard let view = textView, let input = askText(L("Přejít na řádek", "Go to line"), value: "1"),
              let line = Int(input), line > 0 else { return }
        let text = view.string as NSString
        var location = 0
        for _ in 1..<line {
            let next = text.range(of: "\n", range: NSRange(location: location, length: text.length - location))
            if next.location == NSNotFound { NSSound.beep(); return }
            location = NSMaxRange(next)
        }
        view.setSelectedRange(NSRange(location: location, length: 0))
        view.scrollRangeToVisible(view.selectedRange())
    }

    @objc func toggleWrap(_ sender: Any?) {
        Preferences.wrap.toggle()
        app.editors.forEach { editor in editor.allTextViews.forEach { editor.configure($0) } }
    }
    @objc func zoomIn(_ sender: Any?) { changeSize(by: 1) }
    @objc func zoomOut(_ sender: Any?) { changeSize(by: -1) }
    @objc func zoomReset(_ sender: Any?) { Preferences.fontSize = 14; changeSize(by: 0) }
    func changeSize(by amount: CGFloat) {
        Preferences.fontSize += amount
        app.editors.forEach { editor in editor.allTextViews.forEach { editor.configure($0) }; editor.updateStatus() }
        app.editors.forEach { editor in if let note = editor.active { editor.markdownPreview?.update(note, delay: 0) } }
    }
    @objc func chooseFont(_ sender: Any?) {
        NSFontManager.shared.setSelectedFont(Preferences.font, isMultiple: false)
        NSFontManager.shared.orderFrontFontPanel(sender)
    }
    @objc func changeFont(_ sender: Any?) {
        let converted = NSFontManager.shared.convert(Preferences.font)
        UserDefaults.standard.set(converted.fontName, forKey: "fontName")
        Preferences.fontSize = converted.pointSize
        changeSize(by: 0)
    }

    @objc func toggleFocus(_ sender: Any?) {
        focusMode.toggle()
        applyFocusMode()
        window?.makeFirstResponder(textView)
    }
    @objc func toggleOnTop(_ sender: Any?) {
        window?.level = window?.level == .floating ? .normal : .floating
        updateStatus()
    }
    func escape() {
        if !findAll.isHidden {
            searchWork?.cancel()
            searchGeneration += 1
            findAll.isHidden = true
            resultsScroller.isHidden = true
            window?.makeFirstResponder(textView)
        } else if textView?.enclosingScrollView?.isFindBarVisible == true {
            performFind(.hideFindInterface)
        } else if markdownPreview != nil { toggleMarkdownPreview(nil) }
        else if splitEnabled { toggleSplitEditor(nil) }
        else if focusMode { toggleFocus(nil) }
        else if quick { window?.performClose(nil) }
    }

    @objc func printNote(_ sender: Any?) {
        guard let note = active else { return }
        printableView(for: note).printView(sender)
    }

    /// Sized to its text: a fixed 700 pt frame printed a blank second page for short notes.
    func printableView(for note: TextDocument) -> NSTextView {
        let info = NSPrintInfo.shared
        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let printable = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 1))
        printable.isRichText = false
        printable.isVerticallyResizable = true
        printable.font = Preferences.font
        printable.string = note.text
        printable.sizeToFit()
        return printable
    }

    @objc func setEncoding(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let encoding = TextEncoding(rawValue: raw), let active else { return }
        active.format = TextFormat(encoding: encoding, lineEnding: active.format.lineEnding)
        active.revision &+= 1
        app.changed()
    }
    @objc func setLineEnding(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let ending = LineEnding(rawValue: raw), let active else { return }
        active.format.lineEnding = ending
        active.revision &+= 1
        app.changed()
    }

    func askText(_ title: String, value: String) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        let field = NSTextField(string: value)
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: L("Zrušit", "Cancel"))
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    @objc func insertTimestamp(_ sender: Any?) {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        textView?.insertCommandText(formatter.string(from: Date()), name: L("Vložit datum a čas", "Insert date and time"))
    }

    func replaceRange(_ range: NSRange, with replacement: String, name: String) {
        guard let view = textView, view.shouldChangeText(in: range, replacementString: replacement) else { return }
        view.textStorage?.replaceCharacters(in: range, with: replacement)
        view.didChangeText()
        view.undoManager?.setActionName(name)
        view.setSelectedRange(NSRange(location: range.location, length: (replacement as NSString).length))
    }

    @objc func sortLines(_ sender: Any?) { transformSelectedLines(name: L("Seřadit řádky", "Sort lines")) { TextOperations.sortedLines($0, locale: Preferences.interfaceLocale) } }
    @objc func uniqueLines(_ sender: Any?) { transformSelectedLines(name: L("Odstranit duplicitní řádky", "Remove duplicate lines"), transform: TextOperations.uniqueLines) }
    func transformSelectedLines(name: String, transform: (String) -> String) {
        guard let view = textView, view.selectedRange().length > 0 else { NSSound.beep(); return }
        let text = view.string as NSString
        let selection = view.selectedRange()
        let range = text.lineRange(for: selection)
        replaceRange(range, with: transform(text.substring(with: range)), name: name)
    }

    @objc func duplicateLine(_ sender: Any?) {
        guard let view = textView else { return }
        let value = view.string as NSString
        let range = value.lineRange(for: view.selectedRange())
        let line = value.substring(with: range)
        let insertion = line.hasSuffix("\n") ? line : "\n" + line
        replaceRange(NSRange(location: NSMaxRange(range), length: 0), with: insertion, name: L("Duplikovat řádek", "Duplicate line"))
    }

    @objc func moveLineUp(_ sender: Any?) { moveLines(down: false) }
    @objc func moveLineDown(_ sender: Any?) { moveLines(down: true) }
    func moveLines(down: Bool) {
        guard let view = textView else { return }
        let value = view.string as NSString
        let selection = view.selectedRange()
        let range = value.lineRange(for: selection)
        let adjacent: NSRange
        if down {
            guard NSMaxRange(range) < value.length else { return }
            adjacent = value.lineRange(for: NSRange(location: NSMaxRange(range), length: 0))
        } else {
            guard range.location > 0 else { return }
            adjacent = value.lineRange(for: NSRange(location: range.location - 1, length: 0))
        }
        let a = value.substring(with: range)
        let b = value.substring(with: adjacent)
        func withoutFinalNewline(_ text: String) -> String { text.hasSuffix("\n") ? String(text.dropLast()) : text }
        let combined: String
        if down { combined = withoutFinalNewline(b) + "\n" + withoutFinalNewline(a) + (b.hasSuffix("\n") ? "\n" : "") }
        else { combined = withoutFinalNewline(a) + "\n" + withoutFinalNewline(b) + (a.hasSuffix("\n") ? "\n" : "") }
        replaceRange(NSUnionRange(range, adjacent), with: combined, name: L("Přesunout řádek", "Move line"))
        let movedLocation = down ? range.location + (withoutFinalNewline(b) as NSString).length + 1 : adjacent.location
        let movedLength = (withoutFinalNewline(a) as NSString).length
        view.setSelectedRange(NSRange(location: movedLocation, length: movedLength))
    }
}
