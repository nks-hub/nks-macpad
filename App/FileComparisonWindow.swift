import AppKit
import MacPadCore

struct FileComparison {
    let url: URL
    let revision: UInt64
    let format: TextFormat
    let disk: LoadedText
    let lines: LineComparison

    func matches(_ note: TextDocument) -> Bool {
        note.fileURL == url && note.revision == revision && note.format == format
    }
}

final class FileComparisonWindow: NSWindowController, NSWindowDelegate {
    private weak var app: AppDelegate?
    let note: TextDocument
    private(set) var comparison: FileComparison?
    private(set) var stale = true
    private var loading = false
    private var checking = false
    private var generation = 0
    private var timer: Timer?
    let status = NSTextField(wrappingLabelWithString: "")
    let localText = NSTextView()
    let diskText = NSTextView()
    private let localLabel = NSTextField(wrappingLabelWithString: "")
    private let diskLabel = NSTextField(wrappingLabelWithString: "")
    private let overwrite = NSButton()
    private let reload = NSButton()
    private let refreshButton = NSButton()
    private let copy = NSButton()

    init(app: AppDelegate, note: TextDocument) {
        self.app = app
        self.note = note
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 620),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = L("Porovnání: ", "Compare: ") + note.title
        window.minSize = NSSize(width: 720, height: 400)
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        window.delegate = self
        buildView()
    }

    required init?(coder: NSCoder) { fatalError("Use init(app:note:)") }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        refresh(nil)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.checkCurrent() }
    }

    private func buildView() {
        guard let root = window?.contentView else { return }
        let columns = NSStackView(views: [column(localLabel, text: localText), column(diskLabel, text: diskText)])
        columns.orientation = .horizontal
        columns.distribution = .fillEqually
        columns.alignment = .top
        columns.spacing = 12
        configure(refreshButton, title: L("Obnovit porovnání", "Refresh comparison"), action: #selector(refresh(_:)))
        configure(copy, title: L("Uložit kopii…", "Save a copy…"), action: #selector(saveCopy(_:)))
        configure(reload, title: L("Načíst diskovou verzi…", "Reload disk version…"), action: #selector(confirmReload(_:)))
        configure(overwrite, title: L("Přepsat diskovou verzi…", "Overwrite disk version…"), action: #selector(confirmOverwrite(_:)))
        let buttons = NSStackView(views: [refreshButton, copy])
        buttons.spacing = 8
        let actions = NSStackView(views: [reload, overwrite])
        actions.spacing = 8
        let layout = NSStackView(views: [status, columns, buttons, actions])
        layout.orientation = .vertical
        layout.alignment = .leading
        layout.spacing = 12
        layout.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(layout)
        columns.arrangedSubviews.forEach { $0.heightAnchor.constraint(equalTo: columns.heightAnchor).isActive = true }
        NSLayoutConstraint.activate([
            layout.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            layout.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            layout.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            layout.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            columns.widthAnchor.constraint(equalTo: layout.widthAnchor),
            status.widthAnchor.constraint(equalTo: layout.widthAnchor)
        ])
        updateButtons()
    }

    private func column(_ label: NSTextField, text: NSTextView) -> NSView {
        text.isEditable = false
        text.isRichText = false
        text.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        text.textColor = .textColor
        text.backgroundColor = .textBackgroundColor
        text.textContainerInset = NSSize(width: 8, height: 8)
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.layoutManager?.allowsNonContiguousLayout = true
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.documentView = text
        let stack = NSStackView(views: [label, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        label.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        text.setAccessibilityLabel(text === localText ? L("Vaše verze; mínus označuje rozdílné řádky", "Your version; minus marks changed lines")
                                                    : L("Disková verze; plus označuje rozdílné řádky", "Disk version; plus marks changed lines"))
        return stack
    }

    private func configure(_ button: NSButton, title: String, action: Selector) {
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
    }

    private var available: Bool {
        guard let app, !app.editingLocked, !note.saving else { return false }
        return app.editors.contains { $0.notes.contains { $0 === note } }
    }

    private func updateButtons() {
        refreshButton.isEnabled = available && !loading
        copy.isEnabled = available && !loading
        reload.isEnabled = available && !loading && !stale && comparison != nil
        overwrite.isEnabled = reload.isEnabled
    }

    @objc func refresh(_ sender: Any?) {
        guard available, let url = note.fileURL else { invalidate(); return }
        generation += 1
        let generation = self.generation
        let revision = note.revision
        let text = note.text
        let format = note.format
        let diskEncoding = note.savedFormat?.encoding ?? format.encoding
        loading = true
        stale = true
        status.stringValue = L("Načítání a porovnávání…", "Loading and comparing…")
        updateButtons()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { () -> FileComparison in
                let disk = try TextFileStore.read(url, encoding: diskEncoding)
                return FileComparison(url: url, revision: revision, format: format,
                                      disk: disk, lines: LineComparison(local: text, disk: disk.text))
            }
            DispatchQueue.main.async {
                guard let self, self.generation == generation else { return }
                self.loading = false
                switch result {
                case .success(let value):
                    self.comparison = value
                    self.localText.string = value.lines.annotatedLocal()
                    self.diskText.string = value.lines.annotatedDisk()
                    self.localLabel.stringValue = L("Vaše verze", "Your version") + " · r\(revision) · " + self.describe(format)
                    let stamp: String
                    if case .existing(let hash) = value.disk.stamp { stamp = String(hash.prefix(12)) } else { stamp = "" }
                    self.diskLabel.stringValue = L("Disková verze", "Disk version") + " · \(stamp) · " + self.describe(value.disk.format)
                    self.stale = !value.matches(self.note) || !self.available
                    self.status.stringValue = self.stale ? self.staleMessage : L("Rozdílné řádky: ", "Changed lines: ")
                        + "−\(value.lines.localChanges.count) / +\(value.lines.diskChanges.count). "
                        + L("Obě verze jsou pouze ke čtení.", "Both versions are read-only.")
                    self.checkCurrent()
                case .failure(let error):
                    self.comparison = nil
                    self.stale = true
                    self.status.stringValue = errorMessage(error)
                }
                self.updateButtons()
            }
        }
    }

    private func describe(_ format: TextFormat) -> String {
        "\(format.encoding.rawValue) · \(format.lineEnding.rawValue.uppercased()) · BOM \(format.hasBOM ? L("ano", "yes") : L("ne", "no"))"
    }

    private var staleMessage: String {
        L("Porovnání už není aktuální. Před načtením nebo přepsáním ho obnovte.", "This comparison is out of date. Refresh it before reloading or overwriting.")
    }

    private func invalidate() {
        stale = true
        status.stringValue = staleMessage
        updateButtons()
    }

    func checkCurrent() {
        guard let value = comparison, !loading else { return }
        guard available, value.matches(note) else { invalidate(); return }
        guard !checking else { return }
        checking = true
        let generation = self.generation
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let current = try? TextFileStore.stamp(value.url)
            DispatchQueue.main.async {
                guard let self else { return }
                self.checking = false
                guard generation == self.generation else { return }
                if current != value.disk.stamp || !value.matches(self.note) || !self.available { self.invalidate() }
            }
        }
    }

    @objc private func saveCopy(_ sender: Any?) {
        guard available else { invalidate(); return }
        app?.save(note, as: true) { [weak self] _ in self?.checkCurrent() }
    }

    @objc private func confirmReload(_ sender: Any?) { confirm(overwriting: false) }
    @objc private func confirmOverwrite(_ sender: Any?) { confirm(overwriting: true) }

    private func confirm(overwriting: Bool) {
        guard available, !stale, let value = comparison, value.matches(note) else { invalidate(); return }
        let alert = NSAlert()
        alert.messageText = overwriting ? L("Přepsat zobrazenou diskovou verzi?", "Overwrite the displayed disk version?")
                                       : L("Zahodit vaše změny a načíst zobrazenou verzi?", "Discard your edits and load the displayed version?")
        alert.addButton(withTitle: L("Zrušit", "Cancel"))
        alert.addButton(withTitle: overwriting ? L("Přepsat", "Overwrite") : L("Načíst", "Reload"))
        if alert.runModal() == .alertSecondButtonReturn { apply(overwriting: overwriting) { _ in } }
    }

    func apply(overwriting: Bool, completion: @escaping (Bool) -> Void) {
        guard available, !stale, let value = comparison, value.matches(note) else { invalidate(); completion(false); return }
        loading = true
        updateButtons()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let current = try? TextFileStore.stamp(value.url)
            DispatchQueue.main.async {
                guard let self else { completion(false); return }
                self.loading = false
                guard let app = self.app, self.available, value.matches(self.note), current == value.disk.stamp else {
                    self.invalidate(); completion(false); return
                }
                if overwriting {
                    app.save(self.note, expectedStamp: value.disk.stamp) { ok in
                        if ok { self.close() } else { self.checkCurrent() }
                        completion(ok)
                    }
                } else {
                    self.note.text = value.disk.text
                    self.note.savedText = value.disk.text
                    self.note.format = value.disk.format
                    self.note.savedFormat = value.disk.format
                    self.note.stamp = value.disk.stamp
                    self.note.externalChange = false
                    self.note.revision &+= 1
                    self.note.undoManager?.removeAllActions()
                    self.note.updateChangeCount(.changeCleared)
                    app.editors.forEach { $0.reload(self.note) }
                    app.changed()
                    app.refreshSearchResults()
                    self.close()
                    completion(true)
                }
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
        generation += 1
    }
}

extension EditorWindowController {
    @objc func compareWithDisk(_ sender: Any?) {
        guard let note = active, note.fileURL != nil, !note.saving, !app.editingLocked else { return }
        showComparison(note)
    }

    func showComparison(_ note: TextDocument) {
        comparisonWindow?.close()
        comparisonWindow = FileComparisonWindow(app: app, note: note)
        comparisonWindow?.showWindow(nil)
    }
}
