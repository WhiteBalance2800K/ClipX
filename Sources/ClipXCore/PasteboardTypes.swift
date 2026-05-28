import AppKit
import Darwin
import Foundation

public extension NSPasteboard.PasteboardType {
    static let clipXInternalWrite = NSPasteboard.PasteboardType("com.clipx.internal-write")
    static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    static let remoteClipboard = NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")
    static let publicRTFD = NSPasteboard.PasteboardType("public.rtfd")
    static let flatRTFD = NSPasteboard.PasteboardType("com.apple.flat-rtfd")
}

public enum PasteboardClassifier {
    public static func isSensitive(types: [NSPasteboard.PasteboardType]) -> Bool {
        types.contains(.concealed)
    }

    public static func isInternalWrite(types: [NSPasteboard.PasteboardType]) -> Bool {
        types.contains(.clipXInternalWrite)
    }

    public static func isRemoteClipboard(types: [NSPasteboard.PasteboardType]) -> Bool {
        types.contains(.remoteClipboard)
    }
}

public enum PasteboardItemFactory {
    public static func makeItem(
        from pasteboard: NSPasteboard,
        sourceApp: String,
        sourceBundleIdentifier: String? = nil,
        sourceDeviceFamily: String? = nil,
        sourceDeviceModel: String? = nil,
        now: Date = Date()
    ) -> ClipItem? {
        let types = pasteboard.types ?? []
        guard !types.isEmpty else { return nil }
        guard !PasteboardClassifier.isSensitive(types: types) else { return nil }
        guard !PasteboardClassifier.isInternalWrite(types: types) else { return nil }

        let fileURLs = readFileURLs(from: pasteboard)
        let stringTypes = types.map(\.rawValue)
        let metadata = metadata(
            from: types,
            fileURLs: fileURLs,
            sourceBundleIdentifier: sourceBundleIdentifier,
            sourceDeviceFamily: sourceDeviceFamily,
            sourceDeviceModel: sourceDeviceModel
        )

        if let rtfd = RTFDNormalizer.normalize(
            types: stringTypes,
            dataByType: { pasteboard.data(forType: NSPasteboard.PasteboardType($0)) },
            fileURLs: fileURLs
        ) {
            let data = firstRTFDData(from: pasteboard, types: types)
            let payload: ClipPayload = data.map { .rtfd($0) } ?? .fileURLs(fileURLs)
            return ClipItem.make(
                payload: payload,
                sourceApp: sourceApp,
                createdAt: now,
                metadata: metadata.merging([
                    "rtfdPlainText": rtfd.plainText,
                    "rtfdSource": rtfd.sourceDescription
                ]) { _, new in new },
                wasRTFDFixed: true
            )
        }

        let readableURLs = readURLs(from: pasteboard)
        if readableURLs.count == 1,
           let url = readableURLs.first,
           url.scheme?.hasPrefix("http") == true {
            return ClipItem.make(payload: .url(url), sourceApp: sourceApp, createdAt: now, metadata: metadata)
        }

        if !fileURLs.isEmpty {
            return ClipItem.make(payload: .fileURLs(fileURLs), sourceApp: sourceApp, createdAt: now, metadata: metadata)
        }

        if let color = readColor(from: pasteboard) {
            return ClipItem.make(payload: .color(color), sourceApp: sourceApp, createdAt: now, metadata: metadata)
        }

        if let imageData = readImageData(from: pasteboard) {
            return ClipItem.make(payload: .image(imageData), sourceApp: sourceApp, createdAt: now, metadata: metadata)
        }

        if let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
                return ClipItem.make(payload: .url(url), sourceApp: sourceApp, createdAt: now, metadata: metadata)
            }
            return ClipItem.make(payload: .text(text), sourceApp: sourceApp, createdAt: now, metadata: metadata)
        }

        if let html = pasteboard.string(forType: .html), !html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let text = RTFDNormalizer.plainText(from: .html(html)) ?? stripHTML(html)
            if let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                return ClipItem.make(payload: .text(text), sourceApp: sourceApp, createdAt: now, metadata: metadata)
            }
        }

        if let rtfData = pasteboard.data(forType: .rtf), !rtfData.isEmpty {
            if let text = RTFDNormalizer.plainText(from: .rtf(rtfData)) {
                return ClipItem.make(payload: .text(text), sourceApp: sourceApp, createdAt: now, metadata: metadata)
            }
            return ClipItem.make(payload: .rtf(rtfData), sourceApp: sourceApp, createdAt: now, metadata: metadata)
        }

        let unknown = Dictionary(uniqueKeysWithValues: types.compactMap { type in
            pasteboard.data(forType: type).map { (type.rawValue, $0) }
        })
        guard !unknown.isEmpty else { return nil }
        return ClipItem.make(payload: .unknown(unknown), sourceApp: sourceApp, createdAt: now, metadata: metadata)
    }

    private static func metadata(
        from types: [NSPasteboard.PasteboardType],
        fileURLs: [URL],
        sourceBundleIdentifier: String?,
        sourceDeviceFamily: String?,
        sourceDeviceModel: String?
    ) -> [String: String] {
        var metadata = [
            "types": types.map(\.rawValue).joined(separator: ","),
            "remoteClipboard": PasteboardClassifier.isRemoteClipboard(types: types) ? "true" : "false"
        ]
        if let sourceBundleIdentifier, !sourceBundleIdentifier.isEmpty {
            metadata["sourceBundleIdentifier"] = sourceBundleIdentifier
        }
        if let sourceDeviceFamily, !sourceDeviceFamily.isEmpty {
            metadata["sourceDeviceFamily"] = sourceDeviceFamily
        }
        if let sourceDeviceModel, !sourceDeviceModel.isEmpty {
            metadata["sourceDeviceModel"] = sourceDeviceModel
        }
        if !fileURLs.isEmpty {
            metadata["fileCount"] = "\(fileURLs.count)"
        }
        return metadata
    }

    private static func readFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        let urls = readURLs(from: pasteboard)
        if !urls.isEmpty {
            return urls.filter(\.isFileURL)
        }
        if let value = pasteboard.string(forType: .fileURL),
           let url = URL(string: value),
           url.isFileURL {
            return [url]
        }
        return []
    }

    private static func firstRTFDData(from pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Data? {
        for type in types where RTFDNormalizer.rtfdTypes.contains(type.rawValue) {
            if let data = pasteboard.data(forType: type), !data.isEmpty {
                return data
            }
        }
        return nil
    }

    private static func readImageData(from pasteboard: NSPasteboard) -> Data? {
        if let data = pasteboard.data(forType: .png), !data.isEmpty {
            return data
        }
        if let data = pasteboard.data(forType: .tiff), !data.isEmpty {
            return data
        }
        if let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation,
           !tiff.isEmpty {
            return tiff
        }
        return nil
    }

    private static func readColor(from pasteboard: NSPasteboard) -> String? {
        guard let color = NSColor(from: pasteboard)?.usingColorSpace(.sRGB) else { return nil }
        return String(
            format: "#%02X%02X%02X",
            Int(round(color.redComponent * 255)),
            Int(round(color.greenComponent * 255)),
            Int(round(color.blueComponent * 255))
        )
    }

    private static func readURLs(from pasteboard: NSPasteboard) -> [URL] {
        guard let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) else {
            return []
        }
        return objects.compactMap { object in
            if let url = object as? URL {
                return url
            }
            if let nsURL = object as? NSURL {
                return nsURL as URL
            }
            return nil
        }
    }

    private static func stripHTML(_ html: String) -> String? {
        let withoutTags = html.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        let decoded = withoutTags.replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        return decoded.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ClipXDeviceInfo {
    static var localModelIdentifier: String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else {
            return "Mac"
        }
        var model = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &model, &size, nil, 0) == 0 else {
            return "Mac"
        }
        return String(cString: model)
    }

    static var localDeviceFamily: String {
        let model = localModelIdentifier.lowercased()
        if model.contains("macmini") {
            return "macmini"
        }
        if model.contains("macbook") {
            return "macbook"
        }
        if model.contains("imac") {
            return "imac"
        }
        if model.contains("macstudio") {
            return "macstudio"
        }
        if model.contains("macpro") {
            return "macpro"
        }
        return "mac"
    }
}
