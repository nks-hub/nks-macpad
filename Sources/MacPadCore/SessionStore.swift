import Foundation

public struct NoteSnapshot: Codable, Sendable {
    public var id: UUID
    public var text: String
    public var savedText: String?
    public var path: String?
    public var format: TextFormat
    public var savedFormat: TextFormat?
    public var stamp: FileStamp?
    public var title: String?
    public var pinned: Bool
    public var selectionLocation: Int
    public var selectionLength: Int
    public var scrollY: Double
    /// The note is an unmodified file: its text is not stored and is read from `path` on restore.
    public var textOnDisk: Bool

    public init(
        id: UUID = UUID(), text: String = "", savedText: String? = nil,
        path: String? = nil, format: TextFormat = TextFormat(),
        savedFormat: TextFormat? = nil, stamp: FileStamp? = nil,
        title: String? = nil, pinned: Bool = false,
        selectionLocation: Int = 0, selectionLength: Int = 0, scrollY: Double = 0,
        textOnDisk: Bool = false
    ) {
        self.id = id
        self.text = text
        self.savedText = savedText
        self.path = path
        self.format = format
        self.savedFormat = savedFormat
        self.stamp = stamp
        self.title = title
        self.pinned = pinned
        self.selectionLocation = selectionLocation
        self.selectionLength = selectionLength
        self.scrollY = scrollY
        self.textOnDisk = textOnDisk
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, savedText, path, format, savedFormat, stamp, title, pinned
        case selectionLocation, selectionLength, scrollY, textOnDisk
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        text = try values.decode(String.self, forKey: .text)
        savedText = try values.decodeIfPresent(String.self, forKey: .savedText)
        path = try values.decodeIfPresent(String.self, forKey: .path)
        format = try values.decode(TextFormat.self, forKey: .format)
        savedFormat = try values.decodeIfPresent(TextFormat.self, forKey: .savedFormat)
        stamp = try values.decodeIfPresent(FileStamp.self, forKey: .stamp)
        title = try values.decodeIfPresent(String.self, forKey: .title)
        pinned = try values.decode(Bool.self, forKey: .pinned)
        selectionLocation = try values.decode(Int.self, forKey: .selectionLocation)
        selectionLength = try values.decode(Int.self, forKey: .selectionLength)
        scrollY = try values.decode(Double.self, forKey: .scrollY)
        textOnDisk = try values.decodeIfPresent(Bool.self, forKey: .textOnDisk) ?? false
    }
}

public struct WindowSnapshot: Codable, Sendable {
    public var id: UUID
    public var notes: [NoteSnapshot]
    public var activeNoteID: UUID?
    public var frame: String?
    public var quickNote: Bool
    public var visible: Bool

    public init(
        id: UUID = UUID(), notes: [NoteSnapshot] = [], activeNoteID: UUID? = nil,
        frame: String? = nil, quickNote: Bool = false, visible: Bool = true
    ) {
        self.id = id
        self.notes = notes
        self.activeNoteID = activeNoteID
        self.frame = frame
        self.quickNote = quickNote
        self.visible = visible
    }
}

public struct SessionSnapshot: Codable, Sendable {
    public var version: Int
    public var windows: [WindowSnapshot]

    /// Version 2 adds `NoteSnapshot.textOnDisk`; version 1 sessions still load.
    public static let currentVersion = 2

    public init(version: Int = SessionSnapshot.currentVersion, windows: [WindowSnapshot] = []) {
        self.version = version
        self.windows = windows
    }
}

public enum SessionStoreError: Error, LocalizedError {
    case unsupportedVersion(Int)
    case unreadableSession
    case inaccessibleCopy
    case invalidSelection
    case invalidScrollPosition
    case invalidIdentity
    case invalidActiveNote
    case inUse

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "The saved session uses an unsupported format (\(version))."
        case .unreadableSession:
            return "The saved session and its backup cannot be read. Existing data was preserved."
        case .inaccessibleCopy:
            return "A saved session copy cannot be accessed. Existing data was preserved."
        case .invalidSelection:
            return "The saved text selection is outside the document."
        case .invalidScrollPosition:
            return "The saved scroll position is invalid."
        case .invalidIdentity:
            return "The saved session contains duplicate window or note identifiers."
        case .invalidActiveNote:
            return "The saved active note does not belong to its window."
        case .inUse:
            return "Another MacPad process is using this data folder."
        }
    }
}

public enum SessionStoreWarning: Equatable, Sendable {
    case recoveredFromBackup
    case backupUnavailable
}

/// Call from one serial queue. A successful save removes discarded text from both copies.
public final class SessionStore {
    public private(set) var lastLoadRecoveredFromBackup = false
    public private(set) var lastLoadWarning: SessionStoreWarning?

    private let directory: URL
    private var currentURL: URL { directory.appendingPathComponent("session.json") }
    private var backupURL: URL { directory.appendingPathComponent("session.backup.json") }
    private let files = FileManager.default
    private var hasInaccessibleCopy = false
    private var lockDescriptor: Int32 = -1

    public init(directory: URL) {
        self.directory = directory
    }

    deinit {
        if lockDescriptor >= 0 { close(lockDescriptor) }
    }

    /// Takes an exclusive advisory lock on the data folder, held until the store is released.
    /// Two processes writing the same session would each drop the other's drafts on save.
    public func lock() throws {
        guard lockDescriptor < 0 else { return }
        try files.createDirectory(at: directory, withIntermediateDirectories: true,
                                  attributes: [.posixPermissions: 0o700])
        let descriptor = open(directory.appendingPathComponent("session.lock").path, O_RDWR | O_CREAT | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno
            close(descriptor)
            if code == EWOULDBLOCK { throw SessionStoreError.inUse }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        lockDescriptor = descriptor
    }

    public func load() throws -> SessionSnapshot? {
        lastLoadRecoveredFromBackup = false
        lastLoadWarning = nil
        hasInaccessibleCopy = false
        let current = try readCopy(at: currentURL)
        let backup = try readCopy(at: backupURL)
        if case .inaccessible = current { hasInaccessibleCopy = true }
        if case .inaccessible = backup { hasInaccessibleCopy = true }
        if case .valid(let session) = current {
            switch backup {
            case .valid: break
            default: lastLoadWarning = .backupUnavailable
            }
            return session
        }
        if case .valid(let session) = backup {
            lastLoadRecoveredFromBackup = true
            lastLoadWarning = .recoveredFromBackup
            return session
        }
        if case .missing = current, case .missing = backup { return nil }
        throw SessionStoreError.unreadableSession
    }

    public func save(_ session: SessionSnapshot) throws {
        try validate(session)
        // Check both headers before overwriting, even if only the backup is from a newer app.
        let previous = try load()
        guard !hasInaccessibleCopy else { throw SessionStoreError.inaccessibleCopy }
        let data = try JSONEncoder().encode(session)
        try files.createDirectory(at: directory, withIntermediateDirectories: true,
                                  attributes: [.posixPermissions: 0o700])
        try files.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        if lastLoadRecoveredFromBackup, let previous {
            // Keep a valid main copy before deleting the only usable backup.
            try writePrivate(JSONEncoder().encode(previous), to: currentURL)
        }

        // Removing the old backup first prevents discarded notes resurfacing after a crash.
        // A crash before the main commit keeps the old session; after it, only the new one.
        if files.fileExists(atPath: backupURL.path) { try files.removeItem(at: backupURL) }
        try writePrivate(data, to: currentURL)
        try writePrivate(data, to: backupURL)
    }

    private enum Copy {
        case missing
        case inaccessible
        case corrupt
        case valid(SessionSnapshot)
    }

    private struct Header: Decodable {
        let version: Int
    }

    private func readCopy(at url: URL) throws -> Copy {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .missing
        } catch {
            // I/O failure must not hide another readable copy, but forbids later overwrites.
            return .inaccessible
        }

        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data) else { return .corrupt }
        guard (1...SessionSnapshot.currentVersion).contains(header.version) else {
            throw SessionStoreError.unsupportedVersion(header.version)
        }
        guard let session = try? decoder.decode(SessionSnapshot.self, from: data) else { return .corrupt }
        do {
            try validate(session)
        } catch {
            return .corrupt
        }
        return .valid(session)
    }

    private func validate(_ session: SessionSnapshot) throws {
        guard (1...SessionSnapshot.currentVersion).contains(session.version) else {
            throw SessionStoreError.unsupportedVersion(session.version)
        }
        var windowIDs = Set<UUID>()
        var noteIDs = Set<UUID>()
        for window in session.windows {
            guard windowIDs.insert(window.id).inserted else { throw SessionStoreError.invalidIdentity }
            for note in window.notes {
                guard noteIDs.insert(note.id).inserted else { throw SessionStoreError.invalidIdentity }
            }
            if let active = window.activeNoteID, !window.notes.contains(where: { $0.id == active }) {
                throw SessionStoreError.invalidActiveNote
            }
        }
        for note in session.windows.flatMap(\.notes) {
            if note.textOnDisk {
                guard note.path != nil, note.text.isEmpty, note.selectionLocation >= 0, note.selectionLength >= 0 else {
                    throw SessionStoreError.invalidSelection
                }
                guard note.scrollY.isFinite, note.scrollY >= 0 else { throw SessionStoreError.invalidScrollPosition }
                continue
            }
            let length = note.text.utf16.count
            guard note.selectionLocation >= 0, note.selectionLocation <= length,
                  note.selectionLength >= 0, note.selectionLength <= length - note.selectionLocation else {
                throw SessionStoreError.invalidSelection
            }
            guard note.scrollY.isFinite, note.scrollY >= 0 else {
                throw SessionStoreError.invalidScrollPosition
            }
        }
    }

    /// Synced before the rename: save() deletes the old backup first, so unsynced copies could both be lost on power failure.
    private func writePrivate(_ data: Data, to url: URL) throws {
        let temporary = directory.appendingPathComponent(".session-\(UUID().uuidString)")
        defer { try? files.removeItem(at: temporary) }
        try TextFileStore.writeTemporary(data, to: temporary, mode: 0o600)
        guard rename(temporary.path, url.path) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
}
