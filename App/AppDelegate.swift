import AppKit
import MacPadCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var editors: [EditorWindowController] = []
    var statusItem: NSStatusItem?
    var hotKey: QuickNoteShortcut?
    var registeredShortcut: (UInt32, UInt32)?
    var previousApplication: NSRunningApplication?
    weak var previousEditor: EditorWindowController?
    var closedFiles: [(URL, NSRange)] = []
    let diskQueue = DispatchQueue(label: "MacPad.disk", qos: .userInitiated)
    let readQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "MacPad.open"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    var openGeneration = 0
    var pendingOpenCount = 0
    var deferredOpenResults: [() -> Void] = []
    let sessionStore: SessionStore
    var sessionRevision: UInt64 = 0
    var sessionPending = false {
        didSet { if sessionPending { sessionRevision &+= 1 } }
    }
    var sessionFailure: String?
    private(set) var sessionWriteInFlight = false
    private var sessionWaiters: [(Bool) -> Void] = []
    var timer: Timer?
    var preferencesWindow: PreferencesWindow?
    var editingLocked = false
    var eventLock: Any?

    func lockEditing(_ locked: Bool) {
        editingLocked = locked
        editors.forEach { $0.textViews.values.forEach { $0.isEditable = !locked } }
        if let eventLock { NSEvent.removeMonitor(eventLock); self.eventLock = nil }
        if locked {
            eventLock = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown]) { [weak self] event in
                guard let self, self.editingLocked else { return event }
                return self.editors.contains { $0.window === event.window } ? nil : event
            }
        } else {
            let results = deferredOpenResults
            deferredOpenResults.removeAll()
            results.forEach { result in DispatchQueue.main.async(execute: result) }
        }
    }

    init(sessionDirectory: URL? = nil) {
        let directory = sessionDirectory
            ?? ProcessInfo.processInfo.environment["MACPAD_SESSION_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("MacPad", isDirectory: true)
        sessionStore = SessionStore(directory: directory)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try sessionStore.lock()
        } catch SessionStoreError.inUse {
            let alert = NSAlert()
            alert.messageText = "MacPad"
            alert.informativeText = L("MacPad už běží nad stejnou složkou poznámek. Přepněte se do otevřené aplikace.",
                                      "MacPad is already running with the same notes folder. Switch to the open app.")
            alert.runModal()
            exit(0)
        } catch {
            sessionFailure = error.localizedDescription
        }
        installMenus()
        Preferences.applyAppearance()
        do {
            if Preferences.restore, let session = try sessionStore.load() {
                for snapshot in session.windows {
                    let editor = makeWindow(quick: snapshot.quickNote, id: snapshot.id)
                    editor.notes = snapshot.notes.map(TextDocument.init(snapshot:))
                    editor.activeID = snapshot.activeNoteID ?? editor.notes.first?.id
                    if let frame = snapshot.frame { editor.window?.setFrame(NSRectFromString(frame), display: false) }
                    editor.refresh()
                    if snapshot.visible && !snapshot.quickNote { editor.showWindow(nil) }
                }
                if sessionStore.lastLoadWarning != nil {
                    showError(sessionStore.lastLoadRecoveredFromBackup
                        ? L("Relace byla obnovena ze záložní kopie.", "The session was recovered from its backup.")
                        : L("Záložní kopie relace není dostupná. Hlavní kopie byla načtena.", "The session backup is unavailable. The main copy was loaded."))
                }
            }
        } catch {
            sessionFailure = error.localizedDescription
            showError(L("Obnova selhala. Původní data zůstávají zachována. Nové poznámky ukládejte do souborů.",
                        "Recovery failed. Original data has been preserved. Save new notes to files.") + "\n" + error.localizedDescription)
        }
        if editors.filter({ !$0.quick }).isEmpty { newWindow(nil) }
        else if !editors.contains(where: { $0.window?.isVisible == true }) {
            editors.first(where: { !$0.quick })?.showWindow(nil)
        }
        updateStatusItem()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.sessionPending else { return }
            self.flushSession()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    var activeEditor: EditorWindowController? {
        editors.first { $0.window === NSApp.keyWindow }
            ?? editors.first { !$0.quick && $0.window?.isVisible == true }
            ?? editors.first { !$0.quick }
    }

    @discardableResult
    func makeWindow(quick: Bool = false, id: UUID = UUID()) -> EditorWindowController {
        let editor = EditorWindowController(app: self, quick: quick, id: id)
        editors.append(editor)
        return editor
    }

    @objc func newWindow(_ sender: Any?) {
        guard !editingLocked else { return }
        let editor = makeWindow()
        editor.addNote(TextDocument())
        editor.showWindow(nil)
    }

    @objc func newNote(_ sender: Any?) {
        guard !editingLocked else { return }
        guard let editor = activeEditor else { newWindow(sender); return }
        editor.addNote(TextDocument())
        editor.showWindow(nil)
    }

    @objc func openPanel(_ sender: Any?) {
        guard !editingLocked else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK { open(panel.urls) }
    }

    func application(_ application: NSApplication, open urls: [URL]) { open(urls) }

    func open(_ urls: [URL], encoding: TextEncoding? = nil, selection: NSRange? = nil) {
        guard !editingLocked else { return }
        if activeEditor == nil { newWindow(nil) }
        let destination = activeEditor
        let generation = openGeneration
        for url in urls {
            pendingOpenCount += 1
            let operation = BlockOperation()
            operation.addExecutionBlock { [weak operation] in
                guard operation?.isCancelled == false else { return }
                let result = Result { () -> (LoadedText, String) in
                    let loaded = try TextFileStore.read(url, encoding: encoding)
                    return (loaded, try TextFileStore.identity(url))
                }
                DispatchQueue.main.async {
                    let finish = { [self] in
                        guard generation == openGeneration else { return }
                        pendingOpenCount -= 1
                        switch result {
                        case .success(let (loaded, identity)):
                            installOpenedFile(url, loaded: loaded, identity: identity, destination: destination, selection: selection)
                        case .failure(let error):
                            if let codecError = error as? TextFileCodecError,
                               case .invalidData = codecError, encoding == nil {
                                let alert = NSAlert()
                                alert.messageText = L("Soubor nelze načíst jako Unicode.", "Cannot read this file as Unicode.")
                                alert.informativeText = fileErrorMessage(error)
                                alert.addButton(withTitle: L("Zkusit Windows-1250", "Try Windows-1250"))
                                alert.addButton(withTitle: L("Zrušit", "Cancel"))
                                if alert.runModal() == .alertFirstButtonReturn { open([url], encoding: .windows1250, selection: selection) }
                            } else { showError(fileErrorMessage(error)) }
                        }
                        editors.forEach { $0.updateStatus() }
                    }
                    if self.editingLocked { self.deferredOpenResults.append(finish) }
                    else { finish() }
                }
            }
            readQueue.addOperation(operation)
        }
        editors.forEach { $0.updateStatus() }
    }

    func installOpenedFile(_ url: URL, loaded: LoadedText, identity: String, destination: EditorWindowController?, selection: NSRange? = nil) {
        let canonical = url.resolvingSymlinksInPath().standardizedFileURL
        for editor in editors {
            if let note = editor.notes.first(where: { note in
                guard let path = note.fileURL else { return false }
                return path == canonical || (try? TextFileStore.identity(path)) == identity
            }) {
                editor.select(note.id)
                editor.showWindow(nil)
                return
            }
        }
        let note = TextDocument()
        note.text = loaded.text
        note.savedText = loaded.text
        note.format = loaded.format
        note.savedFormat = loaded.format
        note.stamp = loaded.stamp
        note.fileURL = canonical
        if let selection {
            let length = (loaded.text as NSString).length
            let location = min(selection.location, length)
            note.selection = NSRange(location: location, length: min(selection.length, length - location))
        }
        let editor = destination.flatMap { candidate in editors.first { $0 === candidate } } ?? activeEditor ?? makeWindow()
        editor.addNote(note, replacingEmpty: true)
        editor.showWindow(nil)
        NSDocumentController.shared.noteNewRecentDocumentURL(canonical)
    }

    @objc func cancelOpening(_ sender: Any?) {
        openGeneration += 1
        readQueue.cancelAllOperations()
        pendingOpenCount = 0
        deferredOpenResults.removeAll()
        editors.forEach { $0.updateStatus() }
    }

    func changed() {
        sessionPending = true
        editors.forEach { $0.refreshTitles() }
    }

    func refreshSearchResults() {
        editors.filter { !$0.findAll.isHidden }.forEach { $0.searchAllChanged(nil) }
    }

    func snapshot() -> SessionSnapshot {
        SessionSnapshot(windows: editors.map { $0.snapshot() })
    }

    func flushSession(_ completion: ((Bool) -> Void)? = nil) {
        guard Preferences.restore else { sessionPending = false; completion?(true); return }
        if let completion { sessionWaiters.append(completion) }
        guard !sessionWriteInFlight else { return }
        writeLatestSession()
    }

    private func writeLatestSession() {
        let value = snapshot()
        let revision = sessionRevision
        sessionPending = false
        sessionWriteInFlight = true
        diskQueue.async { [self] in
            do {
                try sessionStore.save(value)
                DispatchQueue.main.async {
                    self.sessionWriteInFlight = false
                    self.sessionFailure = nil
                    self.editors.forEach { $0.updateStatus() }
                    if Preferences.restore && self.sessionRevision != revision { self.writeLatestSession() }
                    else { self.completeSessionWaiters(true) }
                }
            } catch {
                DispatchQueue.main.async {
                    self.sessionWriteInFlight = false
                    self.sessionFailure = error.localizedDescription
                    self.editors.forEach { $0.updateStatus() }
                    self.completeSessionWaiters(false)
                }
            }
        }
    }

    private func completeSessionWaiters(_ succeeded: Bool) {
        let waiters = sessionWaiters
        sessionWaiters.removeAll()
        waiters.forEach { $0(succeeded) }
    }

    func save(_ note: TextDocument, as saveAs: Bool = false, completion: @escaping (Bool) -> Void) {
        guard !note.saving else { completion(false); return }
        var target = note.fileURL
        var expected = note.stamp ?? .missing
        if target == nil || saveAs {
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            let name = note.title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            panel.nameFieldStringValue = note.fileURL?.lastPathComponent ?? name + ".txt"
            panel.directoryURL = note.fileURL?.deletingLastPathComponent()
            guard panel.runModal() == .OK, let url = panel.url else { completion(false); return }
            target = url.resolvingSymlinksInPath().standardizedFileURL
            do { expected = try TextFileStore.stamp(target!) }
            catch { showError(error.localizedDescription); completion(false); return }
        }
        guard let url = target else { completion(false); return }
        if editors.flatMap(\.notes).contains(where: { other in
            guard other !== note, let otherURL = other.fileURL else { return false }
            if otherURL.standardizedFileURL == url { return true }
            guard let a = try? TextFileStore.identity(otherURL), let b = try? TextFileStore.identity(url) else { return false }
            return a == b
        }) {
            showError(L("Tento soubor je otevřený v jiné kartě.", "This file is open in another tab."))
            completion(false)
            return
        }
        if note.format.lineEnding == .mixed {
            let alert = NSAlert()
            alert.messageText = L("Sjednotit smíšené konce řádků?", "Normalize mixed line endings?")
            alert.addButton(withTitle: "CRLF")
            alert.addButton(withTitle: "LF")
            alert.addButton(withTitle: L("Zrušit", "Cancel"))
            switch alert.runModal() {
            case .alertFirstButtonReturn: note.format.lineEnding = .crlf
            case .alertSecondButtonReturn: note.format.lineEnding = .lf
            default: completion(false); return
            }
        }
        let text = note.text
        let format = note.format
        let stamp = expected
        note.saving = true
        diskQueue.async {
            do {
                let result = try TextFileStore.write(text, format: format, to: url, expected: stamp)
                DispatchQueue.main.async {
                    note.saving = false
                    note.fileURL = url
                    note.stamp = result
                    note.externalChange = false
                    note.savedText = text
                    note.savedFormat = format
                    if !note.isDocumentEdited { note.updateChangeCount(.changeCleared) }
                    NSDocumentController.shared.noteNewRecentDocumentURL(url)
                    self.changed()
                    completion(true)
                }
            } catch {
                DispatchQueue.main.async {
                    note.saving = false
                    if case TextFileStoreError.conflictRecovered(_, let written) = error {
                        note.fileURL = url
                        note.stamp = written
                        note.savedText = text
                        note.savedFormat = format
                        self.changed()
                    }
                    self.handleSaveError(error, note: note, completion: completion)
                }
            }
        }
    }

    func handleSaveError(_ error: Error, note: TextDocument, completion: @escaping (Bool) -> Void) {
        if case TextFileStoreError.conflictRecovered(let recovered, _) = error {
            let alert = NSAlert()
            alert.messageText = L("Při ukládání vznikla souběžná změna.", "Another program changed the file while saving.")
            alert.informativeText = L("Externí verze byla zachována zde:\n", "The external version was preserved here:\n") + recovered.path
                + L("\nVáš text zůstává otevřený. Před dalším uložením obě verze zkontrolujte.", "\nYour text remains open. Review both versions before saving again.")
            alert.addButton(withTitle: L("Otevřít zachráněnou verzi", "Open recovered version"))
            alert.addButton(withTitle: L("Zavřít upozornění", "Dismiss"))
            let shouldOpen = alert.runModal() == .alertFirstButtonReturn
            completion(false)
            if shouldOpen { open([recovered]) }
            return
        }
        let alert = NSAlert()
        alert.messageText = L("Soubor se nepodařilo uložit.", "The file could not be saved.")
        alert.informativeText = fileErrorMessage(error)
        alert.addButton(withTitle: L("Zrušit", "Cancel"))
        alert.addButton(withTitle: L("Uložit kopii…", "Save a copy…"))
        alert.addButton(withTitle: L("Znovu načíst ze souboru…", "Reload from disk…"))
        let response = alert.runModal()
        if response == .alertSecondButtonReturn { save(note, as: true, completion: completion) }
        else if response == .alertThirdButtonReturn, let url = note.fileURL {
            let confirm = NSAlert()
            confirm.messageText = L("Zahodit změny a načíst soubor?", "Discard edits and reload the file?")
            confirm.addButton(withTitle: L("Zrušit", "Cancel"))
            confirm.addButton(withTitle: L("Načíst", "Reload"))
            if confirm.runModal() == .alertSecondButtonReturn {
                do { try note.load(url, encoding: note.format.encoding); editors.forEach { $0.reload(note) }; changed(); refreshSearchResults() }
                catch { showError(error.localizedDescription) }
            }
            completion(false)
        } else { completion(false) }
    }

    func resolveChanges(_ notes: [TextDocument], index: Int = 0, allowDiscard: Bool = true, completion: @escaping (Bool) -> Void) {
        guard index < notes.count else { completion(true); return }
        let note = notes[index]
        guard !note.saving else { completion(false); return }
        if let url = note.fileURL, !FileManager.default.fileExists(atPath: url.path) { note.externalChange = true }
        guard note.isDocumentEdited else { resolveChanges(notes, index: index + 1, allowDiscard: allowDiscard, completion: completion); return }
        let alert = NSAlert()
        alert.messageText = L("Uložit změny v ", "Save changes in ") + note.title + "?"
        alert.addButton(withTitle: L("Uložit", "Save"))
        alert.addButton(withTitle: L("Zrušit", "Cancel"))
        if allowDiscard { alert.addButton(withTitle: L("Zahodit změny", "Discard changes")) }
        else { alert.informativeText = L("Obnovovací kopie nelze odstranit. Poznámku lze uložit do souboru nebo ukončení zrušit.", "Recovery copies cannot be removed. Save this note to a file or cancel quitting.") }
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            save(note) { ok in
                if ok && !note.isDocumentEdited { self.resolveChanges(notes, index: index + 1, allowDiscard: allowDiscard, completion: completion) }
                else { completion(false) }
            }
        case .alertThirdButtonReturn where allowDiscard: resolveChanges(notes, index: index + 1, allowDiscard: allowDiscard, completion: completion)
        default: completion(false)
        }
    }

    @objc func saveAll(_ sender: Any?) {
        guard !editingLocked else { return }
        let notes = editors.flatMap(\.notes).filter(\.isDocumentEdited)
        guard !notes.isEmpty, !notes.contains(where: \.saving) else { return }
        lockEditing(true)
        saveSequence(notes, index: 0)
    }

    func saveSequence(_ notes: [TextDocument], index: Int) {
        guard index < notes.count else { lockEditing(false); return }
        guard editors.contains(where: { $0.notes.contains(where: { $0 === notes[index] }) }) else {
            lockEditing(false)
            showError(L("Ukládání zastaveno: dokument už není otevřený.", "Saving stopped: the document is no longer open."))
            return
        }
        save(notes[index]) { ok in
            if ok { self.saveSequence(notes, index: index + 1) }
            else {
                self.lockEditing(false)
                self.showError(L("Ukládání zastaveno. Uloženo ", "Saving stopped. Saved ")
                    + "\(index)/\(notes.count). " + L("Ostatní změny zůstávají otevřené.", "Remaining edits are still open."))
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !editingLocked else { return .terminateCancel }
        guard pendingOpenCount == 0 else {
            showError(L("Počkejte na otevření souborů, nebo použijte Soubor → Zrušit otevírání.", "Wait for files to open, or use File → Cancel opening."))
            return .terminateCancel
        }
        guard !editors.flatMap(\.notes).contains(where: \.saving) else {
            showError(L("Počkejte na dokončení ukládání.", "Wait for saving to finish."))
            return .terminateCancel
        }
        lockEditing(true)
        if Preferences.restore {
            flushSession { ok in
                if ok { NSApp.reply(toApplicationShouldTerminate: true); return }
                let alert = NSAlert()
                alert.messageText = L("Obnovu se nepodařilo uložit.", "The session could not be saved.")
                alert.informativeText = L("Můžete zůstat v aplikaci, nebo vyřešit uložení jednotlivých poznámek a ukončit. Původní obnovovací data zůstanou zachována.", "Stay in the app, or resolve each note and quit. Original recovery data will remain untouched.")
                alert.addButton(withTitle: L("Zůstat v aplikaci", "Stay in app"))
                alert.addButton(withTitle: L("Uložit poznámky a ukončit…", "Save notes and quit…"))
                if alert.runModal() == .alertSecondButtonReturn {
                    self.resolveChanges(self.editors.flatMap(\.notes), allowDiscard: false) { self.finishQuit($0) }
                } else { self.finishQuit(false) }
            }
        } else {
            resolveChanges(editors.flatMap(\.notes)) { ok in
                guard ok else { self.finishQuit(false); return }
                self.diskQueue.async {
                    do {
                        try self.sessionStore.save(SessionSnapshot(windows: []))
                        DispatchQueue.main.async { self.finishQuit(true) }
                    } catch {
                        // Recovery is off and every note was resolved; the old files stay untouched.
                        DispatchQueue.main.async { self.showError(error.localizedDescription); self.finishQuit(true) }
                    }
                }
            }
        }
        return .terminateLater
    }

    func finishQuit(_ shouldQuit: Bool) {
        if !shouldQuit { lockEditing(false) }
        NSApp.reply(toApplicationShouldTerminate: shouldQuit)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if let editor = editors.first(where: { !$0.quick }) { editor.showWindow(nil) }
            else { newWindow(nil) }
        }
        return true
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "MacPad"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
