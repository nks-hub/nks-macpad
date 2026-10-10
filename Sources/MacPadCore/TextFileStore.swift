import Foundation
import CryptoKit
import Darwin

public enum FileStamp: Codable, Equatable, Sendable {
    case missing
    case existing(sha256: String)
}

public struct LoadedText: Sendable {
    public let text: String
    public let format: TextFormat
    public let stamp: FileStamp
}

public enum TextFileStoreError: Error, Equatable {
    case conflict(expected: FileStamp, actual: FileStamp)
    /// Our text was written; the external version that raced the replace is kept at the URL.
    case conflictRecovered(URL, written: FileStamp)
    case unsupportedFile
    case coordinationFailed
}

public enum TextFileStore {
    public static func read(_ url: URL, encoding: TextEncoding? = nil) throws -> LoadedText {
        try coordinate(url, writing: false) { target in
            try requireRegularFile(target)
            let data = try Data(contentsOf: target)
            let decoded = try TextFileCodec.decode(data, encoding: encoding)
            return LoadedText(text: decoded.text, format: decoded.format, stamp: digest(data))
        }
    }

    public static func stamp(_ url: URL) throws -> FileStamp {
        try coordinate(url, writing: false) { try currentStamp($0) }
    }

    public static func identity(_ url: URL) throws -> String {
        let target = url.resolvingSymlinksInPath().standardizedFileURL
        try requireRegularFile(target)
        let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
        guard let device = attributes[.systemNumber] as? NSNumber,
              let inode = attributes[.systemFileNumber] as? NSNumber else {
            throw TextFileStoreError.unsupportedFile
        }
        return "\(device):\(inode)"
    }

    public static func write(_ text: String, format: TextFormat, to url: URL,
                             expected: FileStamp) throws -> FileStamp {
        try write(text, format: format, to: url, expected: expected, beforeReplace: {})
    }

    static func write(_ text: String, format: TextFormat, to url: URL, expected: FileStamp,
                      beforeReplace: @escaping () throws -> Void) throws -> FileStamp {
        let data = try TextFileCodec.encode(text, format: format)
        return try coordinate(url, writing: true) { target in
            let actual = try currentStamp(target)
            guard actual == expected else { throw TextFileStoreError.conflict(expected: expected, actual: actual) }
            if actual != .missing, !FileManager.default.isWritableFile(atPath: target.path) {
                throw CocoaError(.fileWriteNoPermission)
            }
            let temporary = target.deletingLastPathComponent().appendingPathComponent(".macpad-\(UUID().uuidString)")
            let manager = FileManager.default
            defer { try? manager.removeItem(at: temporary) }
            // A new file gets the usual umask mode; a replaced file keeps its own.
            try writeTemporary(data, to: temporary, mode: actual == .missing ? 0o666 : 0o600)
            let latest = try currentStamp(target)
            guard latest == expected else { throw TextFileStoreError.conflict(expected: expected, actual: latest) }
            try beforeReplace()
            if actual == .missing {
                try manager.moveItem(at: temporary, to: target)
            } else {
                let backupName = "MacPad-conflict-\(UUID().uuidString).txt"
                let backup = target.deletingLastPathComponent().appendingPathComponent(backupName)
                _ = try manager.replaceItemAt(target, withItemAt: temporary, backupItemName: backupName,
                                              options: .withoutDeletingBackupItem)
                // An uncoordinated writer can change the file after the last hash check.
                guard try currentStamp(backup) == expected else {
                    throw TextFileStoreError.conflictRecovered(backup, written: digest(data))
                }
                try manager.removeItem(at: backup)
            }
            return digest(data)
        }
    }

    private static func digest(_ data: Data) -> FileStamp {
        .existing(sha256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
    }

    static func writeTemporary(_ data: Data, to url: URL, mode: mode_t) throws {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, mode)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: data)
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
    }

    private static func requireRegularFile(_ url: URL) throws {
        guard url.isFileURL else { throw TextFileStoreError.unsupportedFile }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw TextFileStoreError.unsupportedFile
        }
    }

    private static func currentStamp(_ url: URL) throws -> FileStamp {
        do {
            try requireRegularFile(url)
            return digest(try Data(contentsOf: url))
        } catch let error as NSError where error.domain == NSCocoaErrorDomain &&
            (error.code == NSFileNoSuchFileError || error.code == NSFileReadNoSuchFileError) {
            return .missing
        }
    }

    private static func coordinate<T>(_ url: URL, writing: Bool, operation: @escaping (URL) throws -> T) throws -> T {
        guard url.isFileURL else { throw TextFileStoreError.unsupportedFile }
        let target = url.resolvingSymlinksInPath().standardizedFileURL
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<T, Error>?
        let accessor: (URL) -> Void = { coordinatedURL in
            result = Result { try operation(coordinatedURL) }
        }
        if writing {
            coordinator.coordinate(writingItemAt: target, options: .forReplacing,
                                   error: &coordinationError, byAccessor: accessor)
        } else {
            coordinator.coordinate(readingItemAt: target, options: [],
                                   error: &coordinationError, byAccessor: accessor)
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw TextFileStoreError.coordinationFailed }
        return try result.get()
    }
}
