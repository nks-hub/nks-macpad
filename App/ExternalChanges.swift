import AppKit
import MacPadCore

extension EditorWindowController {
    func checkExternalChanges() {
        guard !app.editingLocked else { return }
        for note in notes {
            guard let url = note.fileURL, !note.saving else { continue }
            let revision = note.revision
            let expected = note.stamp
            let encoding = note.format.encoding
            app.diskQueue.async { [weak self, weak note] in
                do {
                    let actual = try TextFileStore.stamp(url)
                    if actual == expected {
                        DispatchQueue.main.async {
                            guard let self, let note, self.notes.contains(where: { $0 === note }),
                                  note.revision == revision, !note.saving, !self.app.editingLocked else { return }
                            note.externalChange = false
                            self.updateStatus()
                        }
                        return
                    }
                    let loaded: LoadedText?
                    if actual == .missing { loaded = nil }
                    else { loaded = try TextFileStore.read(url, encoding: encoding) }
                    DispatchQueue.main.async {
                        guard let self, let note, self.notes.contains(where: { $0 === note }), note.revision == revision, !note.saving,
                              note.fileURL == url, !self.app.editingLocked else { return }
                        if note.isDocumentEdited || loaded == nil {
                            note.externalChange = true
                        } else if let loaded {
                            note.text = loaded.text
                            note.savedText = loaded.text
                            note.format = loaded.format
                            note.savedFormat = loaded.format
                            note.stamp = loaded.stamp
                            note.undoManager?.removeAllActions()
                            note.revision &+= 1
                            let length = (note.text as NSString).length
                            note.selection = NSRange(location: min(note.selection.location, length), length: 0)
                            self.reload(note)
                        }
                        self.app.changed()
                    }
                } catch {
                    DispatchQueue.main.async {
                        guard let self, let note, self.notes.contains(where: { $0 === note }), note.fileURL == url else { return }
                        note.externalChange = true
                        self.updateStatus()
                    }
                }
            }
        }
    }
}
