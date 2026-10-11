import AppKit
import MacPadCore

extension AppDelegate: NSMenuItemValidation {
    func installMenus() {
        let bar = NSMenu()
        NSApp.mainMenu = bar
        func section(_ title: String) -> NSMenu {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title)
            item.submenu = menu
            bar.addItem(item)
            return menu
        }
        func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "",
                 _ modifiers: NSEvent.ModifierFlags = .command, target: AnyObject? = nil) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.target = target
            menu.addItem(item)
        }
        let appMenu = section("MacPad")
        add(appMenu, L("O aplikaci MacPad", "About MacPad"), #selector(NSApplication.orderFrontStandardAboutPanel(_:)), target: NSApp)
        add(appMenu, L("Nastavení…", "Settings…"), #selector(showPreferences(_:)), ",", target: self)
        appMenu.addItem(.separator())
        add(appMenu, L("Skrýt MacPad", "Hide MacPad"), #selector(NSApplication.hide(_:)), "h", target: NSApp)
        add(appMenu, L("Ukončit MacPad", "Quit MacPad"), #selector(NSApplication.terminate(_:)), "q", target: NSApp)

        let file = section(L("Soubor", "File"))
        add(file, L("Nová karta", "New tab"), #selector(newNote(_:)), "n", target: self)
        add(file, L("Další karta", "Another tab"), #selector(newNote(_:)), "t", target: self)
        add(file, L("Nové okno", "New window"), #selector(newWindow(_:)), "n", [.command, .shift], target: self)
        add(file, L("Rychlá poznámka", "Quick note"), #selector(quickNote(_:)), target: self)
        add(file, L("Otevřít…", "Open…"), #selector(openPanel(_:)), "o", target: self)
        add(file, L("Zrušit otevírání", "Cancel opening"), #selector(cancelOpening(_:)), ".", target: self)
        add(file, L("Nedávné soubory…", "Recent files…"), #selector(showRecent(_:)), target: self)
        add(file, L("Znovu otevřít zavřenou kartu", "Reopen closed tab"), #selector(reopenClosed(_:)), "t", [.command, .shift], target: self)
        add(file, L("Vymazat seznamy souborů", "Clear file lists"), #selector(clearRecent(_:)), target: self)
        file.addItem(.separator())
        add(file, L("Uložit", "Save"), #selector(EditorWindowController.saveNote(_:)), "s")
        add(file, L("Uložit jako…", "Save as…"), #selector(EditorWindowController.saveAs(_:)), "s", [.command, .shift])
        add(file, L("Uložit vše", "Save all"), #selector(saveAll(_:)), "s", [.command, .option], target: self)
        add(file, L("Porovnat se souborem na disku…", "Compare with file on disk…"), #selector(EditorWindowController.compareWithDisk(_:)))
        add(file, L("Historie uložených verzí…", "Saved version history…"), #selector(EditorWindowController.showHistory(_:)))
        add(file, L("Vymazat historii souboru…", "Delete file history…"), #selector(EditorWindowController.clearFileHistory(_:)))
        add(file, L("Zavřít kartu", "Close tab"), #selector(closeCurrent(_:)), "w", target: self)
        add(file, L("Zavřít okno", "Close window"), #selector(NSWindow.performClose(_:)), "w", [.command, .shift])
        file.addItem(.separator())
        add(file, L("Tisk…", "Print…"), #selector(EditorWindowController.printNote(_:)), "p")

        let edit = section(L("Úpravy", "Edit"))
        add(edit, L("Zpět", "Undo"), Selector(("undo:")), "z")
        add(edit, L("Znovu", "Redo"), Selector(("redo:")), "z", [.command, .shift])
        edit.addItem(.separator())
        add(edit, L("Vyjmout", "Cut"), #selector(NSText.cut(_:)), "x")
        add(edit, L("Kopírovat", "Copy"), #selector(NSText.copy(_:)), "c")
        add(edit, L("Vložit", "Paste"), #selector(NSTextView.pasteAsPlainText(_:)), "v")
        add(edit, L("Vybrat vše", "Select all"), #selector(NSText.selectAll(_:)), "a")
        edit.addItem(.separator())
        add(edit, L("Hledat…", "Find…"), #selector(EditorWindowController.find(_:)), "f")
        add(edit, L("Nahradit…", "Replace…"), #selector(EditorWindowController.replace(_:)), "f", [.command, .option])
        add(edit, L("Další výskyt", "Find next"), #selector(EditorWindowController.findNext(_:)), "g")
        add(edit, L("Předchozí výskyt", "Find previous"), #selector(EditorWindowController.findPrevious(_:)), "g", [.command, .shift])
        add(edit, L("Hledat ve všech kartách…", "Search all tabs…"), #selector(EditorWindowController.showSearchAll(_:)), "f", [.command, .shift])
        add(edit, L("Přejít na řádek…", "Go to line…"), #selector(EditorWindowController.goToLine(_:)))

        let text = section(L("Text", "Text"))
        add(text, L("Vložit datum a čas", "Insert date and time"), #selector(EditorWindowController.insertTimestamp(_:)))
        add(text, L("Duplikovat řádek", "Duplicate line"), #selector(EditorWindowController.duplicateLine(_:)), "d", [.command, .shift])
        add(text, L("Přesunout řádek nahoru", "Move line up"), #selector(EditorWindowController.moveLineUp(_:)))
        add(text, L("Přesunout řádek dolů", "Move line down"), #selector(EditorWindowController.moveLineDown(_:)))
        add(text, L("Seřadit označené řádky", "Sort selected lines"), #selector(EditorWindowController.sortLines(_:)))
        add(text, L("Odstranit duplicitní řádky", "Remove duplicate lines"), #selector(EditorWindowController.uniqueLines(_:)))
        let encoding = NSMenuItem(title: L("Kódování při uložení", "Save encoding"), action: nil, keyEquivalent: "")
        encoding.submenu = NSMenu()
        for value in TextEncoding.allCases {
            let item = NSMenuItem(title: value.rawValue, action: #selector(EditorWindowController.setEncoding(_:)), keyEquivalent: "")
            item.representedObject = value.rawValue
            encoding.submenu?.addItem(item)
        }
        text.addItem(encoding)
        let endings = NSMenuItem(title: L("Konce řádků", "Line endings"), action: nil, keyEquivalent: "")
        endings.submenu = NSMenu()
        for value in LineEnding.allCases where value != .mixed {
            let item = NSMenuItem(title: value.rawValue.uppercased(), action: #selector(EditorWindowController.setLineEnding(_:)), keyEquivalent: "")
            item.representedObject = value.rawValue
            endings.submenu?.addItem(item)
        }
        text.addItem(endings)

        let view = section(L("Zobrazení", "View"))
        add(view, L("Přepnout kartu…", "Switch tab…"), #selector(EditorWindowController.switchNote(_:)), "k")
        add(view, L("Příkazy…", "Commands…"), #selector(EditorWindowController.showCommands(_:)), "p", [.command, .shift])
        add(view, L("Připnout / odepnout kartu", "Pin / unpin tab"), #selector(EditorWindowController.togglePin(_:)))
        add(view, L("Pojmenovat koncept…", "Name draft…"), #selector(EditorWindowController.renameNote(_:)))
        add(view, L("Přesunout kartu do nového okna", "Move tab to new window"), #selector(EditorWindowController.moveToWindow(_:)))
        add(view, L("Rozdělit editor", "Split editor"), #selector(EditorWindowController.toggleSplitEditor(_:)))
        add(view, L("Přejít do druhého panelu", "Switch editor pane"), #selector(EditorWindowController.switchEditorPane(_:)))
        view.addItem(.separator())
        add(view, L("Zalamovat řádky", "Word wrap"), #selector(EditorWindowController.toggleWrap(_:)))
        add(view, L("Čísla řádků", "Line numbers"), #selector(EditorWindowController.toggleLineNumbers(_:)))
        add(view, L("Náhled Markdownu", "Markdown preview"), #selector(EditorWindowController.toggleMarkdownPreview(_:)))
        add(view, L("Přiblížit", "Zoom in"), #selector(EditorWindowController.zoomIn(_:)), "+")
        add(view, L("Oddálit", "Zoom out"), #selector(EditorWindowController.zoomOut(_:)), "-")
        add(view, L("Skutečná velikost", "Actual size"), #selector(EditorWindowController.zoomReset(_:)), "0")
        add(view, L("Písmo…", "Font…"), #selector(EditorWindowController.chooseFont(_:)))
        add(view, L("Režim soustředění", "Focus mode"), #selector(EditorWindowController.toggleFocus(_:)))
        add(view, L("Okno navrchu", "Always on top"), #selector(EditorWindowController.toggleOnTop(_:)))
        let windows = section(L("Okno", "Window"))
        NSApp.windowsMenu = windows
        add(windows, L("Minimalizovat", "Minimize"), #selector(NSWindow.performMiniaturize(_:)), "m")
        add(windows, L("Celá obrazovka", "Full screen"), #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control])
    }

    @objc func reopenClosed(_ sender: Any?) {
        guard let (url, selection) = closedFiles.popLast() else { return }
        open([url], selection: selection)
    }
    @objc func clearRecent(_ sender: Any?) {
        closedFiles.removeAll()
        NSDocumentController.shared.clearRecentDocuments(sender)
    }
    private var windowForCloseCommand: NSWindow? {
        guard NSApp.modalWindow == nil, let window = NSApp.keyWindow,
              window.sheetParent == nil, window.attachedSheet == nil else { return nil }
        return window
    }

    @objc func closeCurrent(_ sender: Any?) {
        guard let window = windowForCloseCommand else { return }
        if let editor = editors.first(where: { $0.window === window }) {
            editor.closeNote(sender)
        } else {
            window.performClose(sender)
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(closeCurrent(_:)) else { return true }
        guard let window = windowForCloseCommand else { return false }
        if let editor = editors.first(where: { $0.window === window }) {
            menuItem.title = L("Zavřít kartu", "Close tab")
            return editor.validateMenuItem(menuItem)
        }
        menuItem.title = L("Zavřít", "Close")
        return window.styleMask.contains(.closable)
    }

    @objc func showRecent(_ sender: Any?) {
        if activeEditor == nil { newWindow(nil) }
        let urls = NSDocumentController.shared.recentDocumentURLs
        activeEditor?.presentPanel(title: L("Nedávné soubory", "Recent files"), choices: urls.map { url in
            CommandChoice(title: url.lastPathComponent + " — " + url.deletingLastPathComponent().lastPathComponent) { [weak self] in self?.open([url]) }
        })
    }
    @objc func showPreferences(_ sender: Any?) {
        preferencesWindow = PreferencesWindow(app: self)
        preferencesWindow?.showWindow(nil)
    }
}

extension EditorWindowController: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if app.editingLocked { return false }
        switch menuItem.action {
        case #selector(toggleWrap(_:)): menuItem.state = Preferences.wrap ? .on : .off
        case #selector(toggleLineNumbers(_:)): menuItem.state = UserDefaults.standard.bool(forKey: "lineNumbers") ? .on : .off
        case #selector(toggleMarkdownPreview(_:)): menuItem.state = markdownPreview != nil ? .on : .off
        case #selector(toggleSplitEditor(_:)): menuItem.state = splitEnabled ? .on : .off
        case #selector(switchEditorPane(_:)): return splitEnabled
        case #selector(toggleFocus(_:)): menuItem.state = focusMode ? .on : .off
        case #selector(toggleOnTop(_:)): menuItem.state = window?.level == .floating ? .on : .off
        case #selector(togglePin(_:)): menuItem.state = noteFor(menuItem)?.pinned == true ? .on : .off
        case #selector(renameNote(_:)): return noteFor(menuItem)?.fileURL == nil && noteFor(menuItem) != nil
        case #selector(compareWithDisk(_:)): return active?.fileURL != nil && active?.saving == false
        case #selector(showHistory(_:)), #selector(clearFileHistory(_:)): return active?.fileURL != nil
        case #selector(sortLines(_:)), #selector(uniqueLines(_:)): return (textView?.selectedRange().length ?? 0) > 0
        case #selector(saveNote(_:)), #selector(saveAs(_:)), #selector(closeNote(_:)), #selector(AppDelegate.closeCurrent(_:)):
            return active != nil && active?.saving == false && !busyClosing
        case #selector(setEncoding(_:)): menuItem.state = active?.format.encoding.rawValue == menuItem.representedObject as? String ? .on : .off
        case #selector(setLineEnding(_:)): menuItem.state = active?.format.lineEnding.rawValue == menuItem.representedObject as? String ? .on : .off
        default: break
        }
        return active != nil
    }
}
