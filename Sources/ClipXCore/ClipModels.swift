import Foundation

public enum ClipKind: String, Codable, CaseIterable, Identifiable {
    case text
    case url
    case image
    case file
    case rtf
    case rtfd
    case html
    case color
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .text: "Text"
        case .url: "URL"
        case .image: "Image"
        case .file: "File"
        case .rtf: "RTF"
        case .rtfd: "RTFD"
        case .html: "HTML"
        case .color: "Color"
        case .unknown: "Unknown"
        }
    }
}

public enum ClipPayload: Equatable, Codable {
    case text(String)
    case url(URL)
    case image(Data)
    case fileURLs([URL])
    case rtf(Data)
    case rtfd(Data)
    case html(String)
    case color(String)
    case unknown([String: Data])

    private enum CodingKeys: String, CodingKey {
        case kind
        case text
        case url
        case data
        case fileURLs
        case unknown
    }

    public var kind: ClipKind {
        switch self {
        case .text: .text
        case .url: .url
        case .image: .image
        case .fileURLs: .file
        case .rtf: .rtf
        case .rtfd: .rtfd
        case .html: .html
        case .color: .color
        case .unknown: .unknown
        }
    }

    public var searchableText: String {
        switch self {
        case .text(let value), .color(let value):
            value
        case .html(let value):
            RTFDNormalizer.plainText(from: .html(value)) ?? Self.stripHTML(value)
        case .url(let url):
            url.absoluteString
        case .fileURLs(let urls):
            urls.map(\.path).joined(separator: "\n")
        case .rtf(let data), .rtfd(let data), .image(let data):
            "\(kind.rawValue) \(data.count) bytes"
        case .unknown(let values):
            values.keys.sorted().joined(separator: " ")
        }
    }

    private static func stripHTML(_ html: String) -> String {
        let withoutTags = html.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        let decoded = withoutTags.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        return decoded.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(ClipKind.self, forKey: .kind)
        switch kind {
        case .text:
            self = .text(try container.decode(String.self, forKey: .text))
        case .url:
            self = .url(try container.decode(URL.self, forKey: .url))
        case .image:
            self = .image(try container.decode(Data.self, forKey: .data))
        case .file:
            self = .fileURLs(try container.decode([URL].self, forKey: .fileURLs))
        case .rtf:
            self = .rtf(try container.decode(Data.self, forKey: .data))
        case .rtfd:
            self = .rtfd(try container.decode(Data.self, forKey: .data))
        case .html:
            self = .html(try container.decode(String.self, forKey: .text))
        case .color:
            self = .color(try container.decode(String.self, forKey: .text))
        case .unknown:
            self = .unknown(try container.decode([String: Data].self, forKey: .unknown))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .text(let value), .html(let value), .color(let value):
            try container.encode(value, forKey: .text)
        case .url(let url):
            try container.encode(url, forKey: .url)
        case .image(let data), .rtf(let data), .rtfd(let data):
            try container.encode(data, forKey: .data)
        case .fileURLs(let urls):
            try container.encode(urls, forKey: .fileURLs)
        case .unknown(let values):
            try container.encode(values, forKey: .unknown)
        }
    }
}

public struct ClipItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var kind: ClipKind
    public var sourceApp: String
    public var createdAt: Date
    public var preview: String
    public var metadata: [String: String]
    public var payload: ClipPayload
    public var isFavorite: Bool
    public var isPinned: Bool
    public var isSensitive: Bool
    public var wasRTFDFixed: Bool

    public init(
        id: UUID = UUID(),
        kind: ClipKind,
        sourceApp: String,
        createdAt: Date = Date(),
        preview: String,
        metadata: [String: String] = [:],
        payload: ClipPayload,
        isFavorite: Bool = false,
        isPinned: Bool = false,
        isSensitive: Bool = false,
        wasRTFDFixed: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.sourceApp = sourceApp
        self.createdAt = createdAt
        self.preview = preview
        self.metadata = metadata
        self.payload = payload
        self.isFavorite = isFavorite
        self.isPinned = isPinned
        self.isSensitive = isSensitive
        self.wasRTFDFixed = wasRTFDFixed
    }
}

public extension ClipItem {
    static func make(
        payload: ClipPayload,
        sourceApp: String,
        createdAt: Date = Date(),
        metadata: [String: String] = [:],
        isSensitive: Bool = false,
        wasRTFDFixed: Bool = false
    ) -> ClipItem {
        let preview = ClipPreview.make(for: payload)
        return ClipItem(
            kind: payload.kind,
            sourceApp: sourceApp,
            createdAt: createdAt,
            preview: preview,
            metadata: metadata,
            payload: payload,
            isSensitive: isSensitive,
            wasRTFDFixed: wasRTFDFixed
        )
    }
}

public enum ClipPreview {
    public static func make(for payload: ClipPayload, limit: Int = 240) -> String {
        let raw: String
        switch payload {
        case .text(let value):
            raw = value
        case .url(let url):
            raw = url.absoluteString
        case .image(let data):
            raw = "Image · \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))"
        case .fileURLs(let urls):
            raw = urls.map(\.lastPathComponent).joined(separator: ", ")
        case .rtf(let data):
            raw = RTFDNormalizer.plainText(from: .rtf(data)) ?? "Rich text · \(data.count) bytes"
        case .rtfd(let data):
            raw = RTFDNormalizer.plainText(from: .rtfd(data)) ?? "RTFD package · \(data.count) bytes"
        case .html(let value):
            raw = value.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        case .color(let value):
            raw = value
        case .unknown(let values):
            raw = values.keys.sorted().joined(separator: ", ")
        }
        let compact = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > limit else { return compact }
        return String(compact.prefix(limit - 1)) + "…"
    }
}
