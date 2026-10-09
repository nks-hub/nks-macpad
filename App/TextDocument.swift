import AppKit
import MacPadCore

final class TextDocument: NSDocument {
    let id: UUID
    var text = ""
    var savedText: String?
    var format = TextFormat()
    var savedFormat: TextFormat?
    var stamp: FileStamp?
    var customTitle: String?
    var pinned = false
    var selection = NSRange(location: 0, length: 0)
    var scrollY: Double = 0
    var revision: UInt64 = 0
    var saving = false
    var externalChange = false

    init(id: UUID = UUID()) {
        self.id = id
        super.init()
        undoManager = UndoManager()
    }

    override class var autosavesInPlace: Bool { false }
    override class var autosavesDrafts: Bool { false }
    override var isDocumentEdited: Bool {
        if externalChange { return true }
        if let savedText { return !text.utf8.elementsEqual(savedText.utf8) || format != savedFormat }
        return !text.isEmpty
    }

    var title: String {
        if let fileURL { return fileURL.lastPathComponent }
        if let customTitle, !customTitle.isEmpty { return customTitle }
        let first = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return first.isEmpty ? L("Nová poznámka", "New note") : String(first.prefix(48))
    }

    override func data(ofType typeName: String) throws -> Data {
        try TextFileCodec.encode(text, format: format)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        let decoded = try TextFileCodec.decode(data)
        text = decoded.text
        format = decoded.format
        savedText = text
        savedFormat = format
    }

    func load(_ url: URL, encoding: TextEncoding? = nil) throws {
        let loaded = try TextFileStore.read(url, encoding: encoding)
        text = loaded.text
        savedText = text
        format = loaded.format
        savedFormat = format
        stamp = loaded.stamp
        externalChange = false
        fileURL = url.resolvingSymlinksInPath().standardizedFileURL
        undoManager?.removeAllActions()
        updateChangeCount(.changeCleared)
        revision &+= 1
    }

    func changed(to value: String) {
        text = value
        revision &+= 1
    }

    func snapshot() -> NoteSnapshot {
        NoteSnapshot(id: id, text: text, savedText: savedText,
                     path: fileURL?.path, format: format, savedFormat: savedFormat,
                     stamp: stamp, title: customTitle, pinned: pinned,
                     selectionLocation: selection.location, selectionLength: selection.length,
                     scrollY: scrollY)
    }

    convenience init(snapshot: NoteSnapshot) {
        self.init(id: snapshot.id)
        text = snapshot.text
        savedText = snapshot.savedText
        format = snapshot.format
        savedFormat = snapshot.savedFormat
        fileURL = snapshot.path.map { URL(fileURLWithPath: $0) }
        stamp = snapshot.stamp
        customTitle = snapshot.title
        pinned = snapshot.pinned
        let length = (text as NSString).length
        let location = min(max(0, snapshot.selectionLocation), length)
        selection = NSRange(location: location,
                            length: min(max(0, snapshot.selectionLength), length - location))
        scrollY = max(0, snapshot.scrollY)
    }
}
