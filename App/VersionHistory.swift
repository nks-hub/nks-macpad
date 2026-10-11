import AppKit
import MacPadCore

extension AppDelegate {
    @objc func clearAllHistory(_ sender: Any?) {
        guard !editingLocked else { return }
        let alert = NSAlert()
        alert.messageText = L("Vymazat celou historii uložených souborů?", "Delete all saved file history?")
        alert.informativeText = L("Aktuální soubory a rozepsané poznámky zůstanou zachované.", "Current files and drafts will be kept.")
        alert.addButton(withTitle: L("Zrušit", "Cancel"))
        alert.addButton(withTitle: L("Vymazat historii", "Delete history"))
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        clearHistory(source: nil)
    }

    func clearHistory(source: URL?, completion: ((Bool) -> Void)? = nil) {
        historyGeneration += 1
        diskQueue.async {
            do {
                try self.historyStore.clear(source: source)
                DispatchQueue.main.async {
                    self.editors.flatMap(\.notes).filter { source == nil || $0.fileURL == source }.forEach { $0.historyFailure = nil }
                    self.editors.forEach { $0.updateStatus() }
                    completion?(true)
                }
            } catch {
                DispatchQueue.main.async { self.showError(errorMessage(error)); completion?(false) }
            }
        }
    }

    func restoreHistoricalVersion(id: UUID, source: URL, encoding: TextEncoding? = nil, completion: ((TextDocument?) -> Void)? = nil) {
        guard !editingLocked else { completion?(nil); return }
        let generation = historyGeneration
        diskQueue.async {
            let result = Result { () -> DecodedText in
                guard let version = try self.historyStore.versions(for: source).first(where: { $0.id == id }) else {
                    throw CocoaError(.fileReadNoSuchFile)
                }
                return try TextFileCodec.decode(version.data, encoding: encoding ?? version.encoding)
            }
            DispatchQueue.main.async {
                guard !self.editingLocked, self.historyGeneration == generation else { completion?(nil); return }
                switch result {
                case .success(let decoded):
                    let note = TextDocument()
                    note.text = decoded.text
                    note.format = decoded.format
                    note.customTitle = source.lastPathComponent + L(" (z historie)", " (from history)")
                    let editor = self.activeEditor ?? self.makeWindow()
                    editor.addNote(note)
                    editor.showWindow(nil)
                    completion?(note)
                case .failure(let error):
                    if let codec = error as? TextFileCodecError, case .invalidData = codec, encoding == nil {
                        let alert = NSAlert()
                        alert.messageText = L("Verzi nelze načíst ve známém kódování.", "Cannot read this version with its known encoding.")
                        alert.addButton(withTitle: L("Zkusit Windows-1250", "Try Windows-1250"))
                        alert.addButton(withTitle: L("Zrušit", "Cancel"))
                        if alert.runModal() == .alertFirstButtonReturn {
                            self.restoreHistoricalVersion(id: id, source: source, encoding: .windows1250, completion: completion)
                        } else { completion?(nil) }
                    } else { self.showError(errorMessage(error)); completion?(nil) }
                }
            }
        }
    }
}

extension EditorWindowController {
    @objc func showHistory(_ sender: Any?) {
        guard !app.editingLocked, let url = active?.fileURL else { return }
        app.diskQueue.async { [weak self, app] in
            let result = Result { try app.historyStore.versions(for: url) }
            DispatchQueue.main.async {
                guard let self, !app.editingLocked else { return }
                switch result {
                case .success(let versions):
                    if versions.isEmpty {
                        app.showError(L("Pro tento soubor není uložená historie. Zapíná se v Nastavení → Historie.", "No saved history for this file. Enable it in Settings → History."))
                        return
                    }
                    let formatter = DateFormatter()
                    formatter.locale = Preferences.interfaceLocale
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .medium
                    let choices = versions.map { version -> CommandChoice in
                        let id = version.id
                        let title = formatter.string(from: version.archivedAt) + " · " + ByteCountFormatter.string(fromByteCount: Int64(version.data.count), countStyle: .file)
                        return CommandChoice(title: title) { [weak app] in app?.restoreHistoricalVersion(id: id, source: url) }
                    }
                    self.presentPanel(title: L("Historie: ", "History: ") + url.lastPathComponent + L(" · obnovit jako nový koncept", " · restore as a new draft"), choices: choices)
                case .failure(let error): app.showError(errorMessage(error))
                }
            }
        }
    }

    @objc func clearFileHistory(_ sender: Any?) {
        guard !app.editingLocked, let url = active?.fileURL else { return }
        let alert = NSAlert()
        alert.messageText = L("Vymazat historii souboru ", "Delete history for ") + url.lastPathComponent + "?"
        alert.informativeText = L("Soubor a otevřený text zůstanou zachované.", "The file and open text will be kept.")
        alert.addButton(withTitle: L("Zrušit", "Cancel"))
        alert.addButton(withTitle: L("Vymazat historii", "Delete history"))
        if alert.runModal() == .alertSecondButtonReturn { app.clearHistory(source: url) }
    }
}
