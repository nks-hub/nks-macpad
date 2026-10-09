import Foundation
import CoreFoundation

public enum TextEncoding: String, Codable, CaseIterable, Sendable {
    case utf8, utf8BOM, utf16LE, utf16BE, windows1250
}

public enum LineEnding: String, Codable, CaseIterable, Sendable {
    case lf, crlf, cr, mixed
}

public struct TextFormat: Codable, Equatable, Sendable {
    public var encoding: TextEncoding
    public var lineEnding: LineEnding
    public var hasBOM: Bool

    public init(encoding: TextEncoding = .utf8, lineEnding: LineEnding = .crlf, hasBOM: Bool? = nil) {
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.hasBOM = hasBOM ?? (encoding == .utf8BOM || encoding == .utf16LE || encoding == .utf16BE)
    }

    private enum CodingKeys: String, CodingKey { case encoding, lineEnding, hasBOM }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(encoding: try values.decode(TextEncoding.self, forKey: .encoding),
                  lineEnding: try values.decode(LineEnding.self, forKey: .lineEnding),
                  hasBOM: try values.decodeIfPresent(Bool.self, forKey: .hasBOM))
    }
}

public struct DecodedText: Sendable {
    public let text: String
    public let format: TextFormat
}

public enum TextFileCodecError: Error, Equatable {
    case invalidData(TextEncoding)
    case unrepresentableText(TextEncoding)
    case mixedLineEndings
}

public enum TextFileCodec {
    private static let windows1250 = String.Encoding(rawValue:
        CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.windowsLatin2.rawValue)))

    /// A recognized BOM overrides the fallback encoding supplied for BOMless files.
    public static func decode(_ data: Data, encoding: TextEncoding? = nil) throws -> DecodedText {
        let detected: TextEncoding?
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            detected = .utf8BOM
        } else if data.starts(with: [0xFF, 0xFE]) {
            detected = .utf16LE
        } else if data.starts(with: [0xFE, 0xFF]) {
            detected = .utf16BE
        } else {
            detected = nil
        }
        let selected = detected ?? encoding ?? .utf8
        var payload = data
        if detected == .utf8BOM {
            payload.removeFirst(3)
        } else if detected != nil {
            payload.removeFirst(2)
        }
        let text: String
        switch selected {
        case .utf8, .utf8BOM:
            guard let decoded = String(data: payload, encoding: .utf8) else {
                throw TextFileCodecError.invalidData(selected)
            }
            text = decoded
        case .utf16LE, .utf16BE:
            text = try decodeUTF16(payload, encoding: selected)
        case .windows1250:
            guard let decoded = String(data: payload, encoding: windows1250),
                  decoded.data(using: windows1250, allowLossyConversion: false) == payload else {
                throw TextFileCodecError.invalidData(selected)
            }
            text = decoded
        }
        let endings = detectLineEndings(text)
        return DecodedText(text: normalize(text), format: TextFormat(encoding: selected, lineEnding: endings,
                                                                   hasBOM: payload.count != data.count))
    }

    public static func encode(_ text: String, format: TextFormat) throws -> Data {
        let separator: String
        switch format.lineEnding {
        case .lf: separator = "\n"
        case .crlf: separator = "\r\n"
        case .cr: separator = "\r"
        case .mixed: throw TextFileCodecError.mixedLineEndings
        }
        let normalized = normalize(text).replacingOccurrences(of: "\n", with: separator)
        switch format.encoding {
        case .utf8:
            return Data(normalized.utf8)
        case .utf8BOM:
            return Data([0xEF, 0xBB, 0xBF]) + Data(normalized.utf8)
        case .utf16LE, .utf16BE:
            let littleEndian = format.encoding == .utf16LE
            var bytes: [UInt8] = format.hasBOM ? (littleEndian ? [0xFF, 0xFE] : [0xFE, 0xFF]) : []
            for unit in normalized.utf16 {
                let low = UInt8(truncatingIfNeeded: unit)
                let high = UInt8(truncatingIfNeeded: unit >> 8)
                bytes.append(contentsOf: littleEndian ? [low, high] : [high, low])
            }
            return Data(bytes)
        case .windows1250:
            guard let bytes = normalized.data(using: windows1250, allowLossyConversion: false),
                  let decoded = String(data: bytes, encoding: windows1250),
                  Array(decoded.unicodeScalars) == Array(normalized.unicodeScalars) else {
                throw TextFileCodecError.unrepresentableText(format.encoding)
            }
            return bytes
        }
    }

    private static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    private static func detectLineEndings(_ text: String) -> LineEnding {
        let withoutPairs = text.replacingOccurrences(of: "\r\n", with: "")
        var found: [LineEnding] = []
        if text.contains("\r\n") { found.append(.crlf) }
        if withoutPairs.contains("\r") { found.append(.cr) }
        if withoutPairs.contains("\n") { found.append(.lf) }
        return found.count > 1 ? .mixed : (found.first ?? .crlf)
    }

    private static func decodeUTF16(_ data: Data, encoding: TextEncoding) throws -> String {
        guard data.count.isMultiple(of: 2) else { throw TextFileCodecError.invalidData(encoding) }
        let bytes = Array(data)
        var units: [UInt16] = []
        units.reserveCapacity(bytes.count / 2)
        for index in stride(from: 0, to: bytes.count, by: 2) {
            let first = UInt16(bytes[index]), second = UInt16(bytes[index + 1])
            units.append(encoding == .utf16LE ? first | (second << 8) : (first << 8) | second)
        }
        var index = 0
        while index < units.count {
            let unit = units[index]
            if (0xD800...0xDBFF).contains(unit) {
                guard index + 1 < units.count, (0xDC00...0xDFFF).contains(units[index + 1]) else {
                    throw TextFileCodecError.invalidData(encoding)
                }
                index += 2
            } else {
                guard !(0xDC00...0xDFFF).contains(unit) else {
                    throw TextFileCodecError.invalidData(encoding)
                }
                index += 1
            }
        }
        return String(decoding: units, as: UTF16.self)
    }
}
