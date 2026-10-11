import AppKit
import MacPadCore

final class PreferencesWindow: NSWindowController {
    unowned let app: AppDelegate
    let restore = NSButton(checkboxWithTitle: L("Obnovovat rozepsané poznámky", "Restore drafts on launch"), target: nil, action: nil)
    let sections = NSSegmentedControl(labels: [L("Editor", "Editor"), L("Vzhled", "Appearance"), L("Obnova a zkratky", "Recovery and shortcuts"), L("Historie", "History")],
                                     trackingMode: .selectOne, target: nil, action: nil)
    let pages = NSStackView()
    let fontLabel = NSTextField(labelWithString: "")
    let languageHint = NSTextField(wrappingLabelWithString: "")
    var recorder: ShortcutRecorder?

    init(app: AppDelegate) {
        self.app = app
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 410),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L("Nastavení", "Settings")
        window.titlebarAppearsTransparent = true
        window.center()
        super.init(window: window)
        let root = NSView()
        window.contentView = root
        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 22
        content.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: root.topAnchor, constant: 22),
            content.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -24),
            content.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -22)
        ])
        sections.target = self
        sections.action = #selector(changeSection(_:))
        sections.selectedSegment = 0
        sections.segmentStyle = .rounded
        content.addArrangedSubview(sections)
        pages.orientation = .vertical
        pages.alignment = .leading
        content.addArrangedSubview(pages)
        sections.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        pages.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        buildEditorPage()
        buildAppearancePage()
        buildRecoveryPage()
        buildHistoryPage()
        changeSection(sections)
    }

    required init?(coder: NSCoder) { fatalError("Use init(app:)") }

    private func page() -> NSStackView {
        let page = NSStackView()
        page.orientation = .vertical
        page.alignment = .leading
        page.spacing = 16
        pages.addArrangedSubview(page)
        page.widthAnchor.constraint(equalTo: pages.widthAnchor).isActive = true
        return page
    }

    private func row(_ title: String, control: NSView) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13)
        let row = NSStackView(views: [label, NSView(), control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 14
        control.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    private func addRow(_ row: NSView, to page: NSStackView) {
        page.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: page.widthAnchor).isActive = true
    }

    private func buildEditorPage() {
        let page = page()
        fontLabel.stringValue = Preferences.fontLabel
        let font = NSButton(title: L("Změnit…", "Change…"), target: self, action: #selector(chooseFont(_:)))
        font.bezelStyle = .rounded
        addRow(row(L("Písmo", "Font"), control: NSStackView(views: [fontLabel, font])), to: page)
        let wrap = NSButton(checkboxWithTitle: L("Zalamovat dlouhé řádky", "Wrap long lines"), target: self, action: #selector(changeWrap(_:)))
        wrap.state = Preferences.wrap ? .on : .off
        page.addArrangedSubview(wrap)
        let lines = NSButton(checkboxWithTitle: L("Zobrazovat čísla řádků", "Show line numbers"), target: self, action: #selector(changeLines(_:)))
        lines.state = UserDefaults.standard.bool(forKey: "lineNumbers") ? .on : .off
        page.addArrangedSubview(lines)
        let detail = NSTextField(wrappingLabelWithString: L("Vkládání zachová čistý text. Velikost písma můžete měnit také příkazy Přiblížit a Oddálit.",
                                                          "Pasting keeps plain text. You can also resize the font using Zoom in and Zoom out."))
        detail.textColor = .secondaryLabelColor
        addRow(detail, to: page)
    }

    private func buildAppearancePage() {
        let page = page()
        let appearance = NSPopUpButton()
        appearance.addItems(withTitles: [L("Podle systému", "Follow system"), L("Světlý", "Light"), L("Tmavý", "Dark")])
        appearance.selectItem(at: ["system", "light", "dark"].firstIndex(of: UserDefaults.standard.string(forKey: "appearance") ?? "system") ?? 0)
        appearance.target = self
        appearance.action = #selector(changeAppearance(_:))
        addRow(row(L("Barevné schéma", "Color scheme"), control: appearance), to: page)
        let language = NSPopUpButton()
        language.addItems(withTitles: [L("Jazyk systému", "System language"), "Čeština", "English"])
        language.selectItem(at: ["system", "cs", "en"].firstIndex(of: UserDefaults.standard.string(forKey: "language") ?? "system") ?? 0)
        language.target = self
        language.action = #selector(changeLanguage(_:))
        addRow(row(L("Jazyk rozhraní", "Interface language"), control: language), to: page)
        languageHint.textColor = .secondaryLabelColor
        addRow(languageHint, to: page)
    }

    private func buildRecoveryPage() {
        let page = page()
        restore.target = self
        restore.action = #selector(changeRestore(_:))
        restore.state = Preferences.restore ? .on : .off
        page.addArrangedSubview(restore)
        let detail = NSTextField(wrappingLabelWithString: L("Rozepsané poznámky zůstanou v tomto Macu. Původní soubory se mění jen příkazem Uložit.",
                                                          "Drafts stay on this Mac. Original files change only when you save them."))
        detail.textColor = .secondaryLabelColor
        addRow(detail, to: page)
        let menuBar = NSButton(checkboxWithTitle: L("Rychlá poznámka v horní liště", "Quick note in menu bar"), target: self, action: #selector(changeMenuBar(_:)))
        menuBar.state = UserDefaults.standard.bool(forKey: "menuBar") ? .on : .off
        page.addArrangedSubview(menuBar)
        let recorder = ShortcutRecorder(title: UserDefaults.standard.string(forKey: "quickLabel") ?? L("Nastavit zkratku…", "Set shortcut…"), target: nil, action: nil)
        self.recorder = recorder
        recorder.displayTitle = recorder.title
        recorder.target = recorder
        recorder.action = #selector(ShortcutRecorder.beginRecording(_:))
        recorder.bezelStyle = .rounded
        recorder.recorded = { [weak self, weak recorder] event in
            guard let self else { return }
            let flags = event.modifierFlags
            let label = (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "")
                + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "")
                + (event.charactersIgnoringModifiers?.uppercased() ?? String(event.keyCode))
            let modifiers = QuickNoteShortcut.carbonModifiers(flags)
            if self.app.registerShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers) {
                UserDefaults.standard.set(Int(event.keyCode), forKey: "quickKey")
                UserDefaults.standard.set(Int(modifiers), forKey: "quickModifiers")
                UserDefaults.standard.set(label, forKey: "quickLabel")
                recorder?.displayTitle = label
            }
            recorder?.title = recorder?.displayTitle ?? ""
        }
        let clear = NSButton(title: L("Zrušit", "Clear"), target: self, action: #selector(clearShortcut(_:)))
        clear.bezelStyle = .rounded
        addRow(row(L("Globální zkratka", "Global shortcut"), control: NSStackView(views: [recorder, clear])), to: page)
    }

    private func buildHistoryPage() {
        let page = page()
        let enabled = NSButton(checkboxWithTitle: L("Uchovávat předchozí uložené verze souborů", "Keep previous saved file versions"), target: self, action: #selector(changeHistory(_:)))
        enabled.state = Preferences.history ? .on : .off
        page.addArrangedSubview(enabled)
        let detail = NSTextField(wrappingLabelWithString: L("Nejvýše 20 verzí na soubor, 30 dní a celkem 100 MiB. Historie je uložená místně bez šifrování. Vypnutí další archivace nemaže existující historii. Obnovení vytvoří nový koncept; nepřepíše soubor ani rozepsané změny.", "Up to 20 versions per file, 30 days and 100 MiB in total. History is stored locally without encryption. Turning it off keeps existing history. Restoring creates a new draft; it does not overwrite files or unsaved edits."))
        detail.textColor = .secondaryLabelColor
        addRow(detail, to: page)
        let clear = NSButton(title: L("Vymazat všechnu historii…", "Delete all history…"), target: app, action: #selector(AppDelegate.clearAllHistory(_:)))
        clear.bezelStyle = .rounded
        page.addArrangedSubview(clear)
    }

    @objc func changeHistory(_ sender: NSButton) { Preferences.history = sender.state == .on }

    @objc func changeSection(_ sender: NSSegmentedControl) {
        for (index, page) in pages.arrangedSubviews.enumerated() { page.isHidden = index != sender.selectedSegment }
    }
    @objc func changeAppearance(_ sender: NSPopUpButton) {
        UserDefaults.standard.set(["system", "light", "dark"][sender.indexOfSelectedItem], forKey: "appearance")
        Preferences.applyAppearance()
    }
    @objc func changeLanguage(_ sender: NSPopUpButton) {
        let value = ["system", "cs", "en"][sender.indexOfSelectedItem]
        if value == "system" { UserDefaults.standard.removeObject(forKey: "language") }
        else { UserDefaults.standard.set(value, forKey: "language") }
        app.installMenus()
        app.editors.forEach { $0.refreshTitles() }
        languageHint.stringValue = L("Jazyk celého rozhraní se změní po novém spuštění.", "The full interface language will change after restarting.")
    }
    @objc func changeWrap(_ sender: NSButton) {
        Preferences.wrap = sender.state == .on
        app.editors.forEach { editor in editor.allTextViews.forEach { editor.configure($0) } }
    }
    @objc func changeLines(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "lineNumbers")
        app.editors.forEach { editor in editor.allTextViews.forEach { editor.configure($0) } }
    }
    @objc func chooseFont(_ sender: Any?) { app.activeEditor?.chooseFont(sender) }
    @objc func changeFont(_ sender: Any?) {
        app.activeEditor?.changeFont(sender)
        fontLabel.stringValue = Preferences.fontLabel
    }
    @objc func changeMenuBar(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "menuBar")
        app.updateStatusItem()
    }
    @objc func clearShortcut(_ sender: Any?) {
        for key in ["quickKey", "quickModifiers", "quickLabel"] { UserDefaults.standard.removeObject(forKey: key) }
        app.updateStatusItem()
        recorder?.displayTitle = L("Nastavit zkratku…", "Set shortcut…")
        recorder?.title = recorder?.displayTitle ?? ""
    }
    @objc func changeRestore(_ sender: NSButton) {
        if sender.state == .on { Preferences.restore = true; app.changed(); return }
        if app.editors.flatMap(\.notes).contains(where: { $0.isDocumentEdited || $0.saving }) {
            sender.state = .on
            app.showError(L("Před vypnutím obnovy uložte nebo zavřete změněné poznámky.", "Save or close edited notes before disabling recovery."))
            return
        }
        sender.isEnabled = false
        Preferences.restore = false
        app.diskQueue.async {
            do {
                try self.app.sessionStore.save(SessionSnapshot(windows: []))
                DispatchQueue.main.async { Preferences.restore = false; sender.isEnabled = true }
            } catch {
                DispatchQueue.main.async { Preferences.restore = true; sender.state = .on; sender.isEnabled = true; self.app.showError(errorMessage(error)) }
            }
        }
    }
}
