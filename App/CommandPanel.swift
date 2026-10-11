import AppKit

struct CommandChoice {
    let title: String
    let action: () -> Void
}

final class ResultButton: NSButton {
    var onClick: (() -> Void)? {
        didSet { target = self; action = #selector(invoke(_:)) }
    }
    @objc func invoke(_ sender: Any?) { onClick?() }
}

final class CommandPanel: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate, NSWindowDelegate {
    let choices: [CommandChoice]
    var filtered: [CommandChoice]
    let search = NSSearchField()
    let table = NSTableView()
    weak var editor: EditorWindowController?
    var pendingAction: (() -> Void)?

    init(title: String, choices: [CommandChoice], editor: EditorWindowController) {
        self.choices = choices
        filtered = choices
        self.editor = editor
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 340),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = title
        super.init(window: panel)
        panel.delegate = self
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stack.spacing = 8
        panel.contentView = stack
        search.placeholderString = title
        search.delegate = self
        stack.addArrangedSubview(search)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title")))
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 28
        table.target = self
        table.doubleAction = #selector(choose(_:))
        scroll.documentView = table
        stack.addArrangedSubview(scroll)
        search.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true
        scroll.widthAnchor.constraint(equalTo: search.widthAnchor).isActive = true
        let choose = NSButton(title: L("Otevřít", "Open"), target: self, action: #selector(choose(_:)))
        choose.keyEquivalent = "\r"
        stack.addArrangedSubview(choose)
        if !choices.isEmpty { table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
    }
    required init?(coder: NSCoder) { fatalError("Use init(title:choices:editor:)") }
    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        NSTextField(labelWithString: filtered[row].title)
    }
    func controlTextDidChange(_ obj: Notification) {
        let query = search.stringValue
        filtered = choices.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
        table.reloadData()
        if !filtered.isEmpty { table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)): choose(nil); return true
        case #selector(NSResponder.cancelOperation(_:)): dismiss(); return true
        case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.moveUp(_:)):
            guard !filtered.isEmpty else { return true }
            let step = commandSelector == #selector(NSResponder.moveDown(_:)) ? 1 : -1
            let row = min(max(0, table.selectedRow + step), filtered.count - 1)
            table.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            table.scrollRowToVisible(row)
            return true
        default: return false
        }
    }
    func dismiss() {
        if let window { editor?.window?.endSheet(window) }
    }
    override func cancelOperation(_ sender: Any?) { dismiss() }
    func windowShouldClose(_ sender: NSWindow) -> Bool { dismiss(); return false }
    @objc func choose(_ sender: Any?) {
        guard filtered.indices.contains(table.selectedRow) else { return }
        let choice = filtered[table.selectedRow]
        pendingAction = choice.action
        dismiss()
    }
}

extension EditorWindowController {
    func presentPanel(title: String, choices: [CommandChoice]) {
        guard let window, window.attachedSheet == nil else { return }
        // A window closed with recovery on is only hidden; a sheet on it would be invisible and block later panels.
        showWindow(nil)
        let panel = CommandPanel(title: title, choices: choices, editor: self)
        self.panel = panel
        window.beginSheet(panel.window!) { [weak self] _ in
            panel.window?.orderOut(nil)
            self?.window?.makeKeyAndOrderFront(nil)
            self?.window?.makeFirstResponder(self?.textView)
            self?.panel = nil
            panel.pendingAction?()
        }
        panel.window?.makeFirstResponder(panel.search)
    }
    @objc func switchNote(_ sender: Any?) {
        presentPanel(title: L("Přepnout kartu", "Switch tab"), choices: app.editors.flatMap { owner in
            owner.notes.map { note in CommandChoice(title: (note.pinned ? "● " : "") + note.title) { [weak owner] in
                owner?.select(note.id); owner?.showWindow(nil)
            } }
        })
    }
    @objc func showCommands(_ sender: Any?) {
        var choices: [CommandChoice] = []
        func visit(_ menu: NSMenu, prefix: String) {
            for item in menu.items {
                if let submenu = item.submenu { visit(submenu, prefix: item.title); continue }
                guard !item.isSeparatorItem, let action = item.action,
                      action != #selector(showCommands(_:)),
                      let target = NSApp.target(forAction: action, to: item.target, from: item) else { continue }
                if let validator = target as? NSMenuItemValidation, !validator.validateMenuItem(item) { continue }
                choices.append(CommandChoice(title: prefix + " › " + item.title) { NSApp.sendAction(action, to: item.target, from: item) })
            }
        }
        if let menu = NSApp.mainMenu { visit(menu, prefix: "") }
        presentPanel(title: L("Příkazy", "Commands"), choices: choices)
    }
}
