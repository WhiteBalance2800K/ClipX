import AppKit
import Foundation

public final class PasteboardMonitor {
    public var isPaused = false
    public var autoFixRTFD = true
    public var onItemCaptured: ((ClipItem) -> Void)?
    public var onRTFDFixed: ((String) -> Void)?

    private let pasteboard: NSPasteboard
    private var timer: Timer?
    private var lastChangeCount: Int
    private var ignoredChangeCount: Int?

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    public func start(interval: TimeInterval = 0.5) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func poll(sourceApp: String? = nil) {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        if ignoredChangeCount == changeCount {
            ignoredChangeCount = nil
            return
        }

        guard !isPaused else { return }
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let pasteboardTypes = pasteboard.types ?? []
        let isRemoteClipboard = PasteboardClassifier.isRemoteClipboard(types: pasteboardTypes)
        let remoteSource = isRemoteClipboard ? RemoteClipboardSource.infer(from: pasteboardTypes) : nil
        let appName = sourceApp
            ?? remoteSource?.sourceApp
            ?? frontmostApplication?.localizedName
            ?? "Unknown app"
        let sourceBundleIdentifier = isRemoteClipboard || sourceApp != nil ? nil : frontmostApplication?.bundleIdentifier
        let sourceDeviceFamily = isRemoteClipboard ? remoteSource?.deviceFamily : ClipXDeviceInfo.localDeviceFamily
        let sourceDeviceModel = isRemoteClipboard ? remoteSource?.deviceModel : ClipXDeviceInfo.localModelIdentifier
        guard var item = PasteboardItemFactory.makeItem(
            from: pasteboard,
            sourceApp: appName,
            sourceBundleIdentifier: sourceBundleIdentifier,
            sourceDeviceFamily: sourceDeviceFamily,
            sourceDeviceModel: sourceDeviceModel
        ) else { return }
        if let inference = remoteSource?.inference {
            item.metadata["sourceInference"] = inference
        }
        onItemCaptured?(item)

        guard autoFixRTFD, item.kind == .rtfd || item.wasRTFDFixed else { return }
        let plainText = item.metadata["rtfdPlainText"] ?? RTFDNormalizer.plainText(from: item.payload)
        guard let plainText, !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        writePlainTextInternally(plainText)
        item.wasRTFDFixed = true
        onRTFDFixed?(plainText)
    }

    public func write(_ item: ClipItem) {
        writeInternally {
            PasteboardWriter.write(item.payload, to: pasteboard)
        }
    }

    private func writePlainTextInternally(_ text: String) {
        writeInternally {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            pasteboard.setData(Data("1".utf8), forType: .clipXInternalWrite)
        }
    }

    private func writeInternally(_ block: () -> Void) {
        block()
        lastChangeCount = pasteboard.changeCount
        ignoredChangeCount = pasteboard.changeCount
    }
}

private struct RemoteClipboardSource {
    var sourceApp: String
    var deviceFamily: String?
    var deviceModel: String?
    var inference: String

    static func infer(from types: [NSPasteboard.PasteboardType]) -> RemoteClipboardSource {
        let rawTypes = Set(types.map(\.rawValue))
        if !rawTypes.intersection(RTFDNormalizer.rtfdTypes).isEmpty {
            return RemoteClipboardSource(
                sourceApp: "iOS Device",
                deviceFamily: "iphone",
                deviceModel: "iOS Device",
                inference: "mobile-rtfd"
            )
        }
        return RemoteClipboardSource(
            sourceApp: "Universal Clipboard",
            deviceFamily: nil,
            deviceModel: nil,
            inference: "generic"
        )
    }
}

public enum PasteboardWriter {
    public static func write(_ payload: ClipPayload, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.setData(Data("1".utf8), forType: .clipXInternalWrite)

        switch payload {
        case .text(let text), .color(let text):
            pasteboard.setString(text, forType: .string)
        case .html(let html):
            pasteboard.setString(plainTextFromHTML(html) ?? html, forType: .string)
        case .url(let url):
            pasteboard.setString(url.absoluteString, forType: .string)
            pasteboard.writeObjects([url as NSURL])
        case .image(let data):
            if let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            } else {
                pasteboard.setData(data, forType: .tiff)
            }
        case .fileURLs(let urls):
            pasteboard.writeObjects(urls.map { $0 as NSURL })
        case .rtf(let data):
            pasteboard.setData(data, forType: .rtf)
            if let text = RTFDNormalizer.plainText(from: .rtf(data)) {
                pasteboard.setString(text, forType: .string)
            }
        case .rtfd(let data):
            pasteboard.setData(data, forType: .publicRTFD)
            if let text = RTFDNormalizer.plainText(from: .rtfd(data)) {
                pasteboard.setString(text, forType: .string)
            }
        case .unknown(let values):
            for (type, data) in values {
                pasteboard.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
        }
    }

    private static func plainTextFromHTML(_ html: String) -> String? {
        let text = RTFDNormalizer.plainText(from: .html(html)) ?? stripHTML(html)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
}
