import AppKit
import Foundation

public struct RTFDNormalizationResult: Equatable {
    public var plainText: String
    public var detectedTypes: [String]
    public var sourceDescription: String

    public init(plainText: String, detectedTypes: [String], sourceDescription: String) {
        self.plainText = plainText
        self.detectedTypes = detectedTypes
        self.sourceDescription = sourceDescription
    }
}

public enum RTFDNormalizer {
    public static let rtfdTypes: Set<String> = [
        "public.rtfd",
        "com.apple.flat-rtfd",
        "NSRTFDPboardType"
    ]

    public static func containsRTFDType(_ types: [String]) -> Bool {
        !Set(types).intersection(rtfdTypes).isEmpty
    }

    public static func isRTFDFileURL(_ url: URL) -> Bool {
        url.pathExtension.caseInsensitiveCompare("rtfd") == .orderedSame
    }

    public static func plainText(from payload: ClipPayload) -> String? {
        switch payload {
        case .rtf(let data):
            return attributedString(from: data, documentType: .rtf)?.string.nonEmpty
        case .rtfd(let data):
            return attributedString(from: data, documentType: .rtfd)?.string.nonEmpty
        case .fileURLs(let urls):
            for url in urls where isRTFDFileURL(url) {
                if let text = plainText(fromRTFDFileURL: url) {
                    return text
                }
            }
            return nil
        case .html(let html):
            return attributedString(from: Data(html.utf8), documentType: .html)?.string.nonEmpty
        case .text(let text):
            return text.nonEmpty
        case .url, .image, .color, .unknown:
            return nil
        }
    }

    public static func normalize(
        types: [String],
        dataByType: (String) -> Data?,
        fileURLs: [URL] = []
    ) -> RTFDNormalizationResult? {
        var detected = types.filter { rtfdTypes.contains($0) }

        for type in detected {
            guard let data = dataByType(type) else { continue }
            if let text = attributedString(from: data, documentType: .rtfd)?.string.nonEmpty {
                return RTFDNormalizationResult(
                    plainText: text,
                    detectedTypes: detected,
                    sourceDescription: type
                )
            }
        }

        for url in fileURLs where isRTFDFileURL(url) {
            detected.append("file://*.rtfd")
            if let text = plainText(fromRTFDFileURL: url) {
                return RTFDNormalizationResult(
                    plainText: text,
                    detectedTypes: detected,
                    sourceDescription: url.lastPathComponent
                )
            }
        }

        return nil
    }

    public static func plainText(fromRTFDFileURL url: URL) -> String? {
        guard isRTFDFileURL(url) else { return nil }
        do {
            let wrapper = try FileWrapper(url: url, options: .immediate)
            return NSAttributedString(rtfdFileWrapper: wrapper, documentAttributes: nil)?.string.nonEmpty
        } catch {
            return nil
        }
    }

    private static func attributedString(
        from data: Data,
        documentType: NSAttributedString.DocumentType
    ) -> NSAttributedString? {
        guard !data.isEmpty else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: documentType],
            documentAttributes: nil
        )
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
