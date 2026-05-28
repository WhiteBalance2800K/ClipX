import AppKit
import ClipXCore
import Foundation

enum TestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

struct TestCase {
    let name: String
    let run: () throws -> Void
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw TestFailure.failed(message)
    }
}

let tests: [TestCase] = [
    TestCase(name: "plain text payload returns text") {
        try expect(RTFDNormalizer.plainText(from: .text("hello")) == "hello", "plain text did not round trip")
    },
    TestCase(name: "RTF payload extracts plain text") {
        let data = try richTextData("Hello from RTF", documentType: .rtf)
        try expect(RTFDNormalizer.plainText(from: .rtf(data)) == "Hello from RTF", "RTF plain text mismatch")
    },
    TestCase(name: "RTFD payload extracts plain text") {
        let data = try richTextData("Hello from RTFD", documentType: .rtfd)
        try expect(RTFDNormalizer.plainText(from: .rtfd(data)) == "Hello from RTFD", "RTFD plain text mismatch")
    },
    TestCase(name: "HTML payload extracts plain text") {
        let html = "<p>Hello <strong>from HTML</strong></p>"
        try expect(RTFDNormalizer.plainText(from: .html(html)) == "Hello from HTML", "HTML plain text mismatch")
    },
    TestCase(name: "empty RTF does not normalize") {
        try expect(RTFDNormalizer.plainText(from: .rtf(Data())) == nil, "empty RTF should not normalize")
    },
    TestCase(name: "concealed pasteboard type is skipped") {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipXTests.concealed.\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("secret", forType: .string)
        pasteboard.setData(Data("1".utf8), forType: .concealed)

        let monitor = PasteboardMonitor(pasteboard: pasteboard)
        var captured = 0
        monitor.onItemCaptured = { _ in captured += 1 }

        pasteboard.clearContents()
        pasteboard.setString("secret2", forType: .string)
        pasteboard.setData(Data("1".utf8), forType: .concealed)
        monitor.poll(sourceApp: "Unit Test")

        try expect(captured == 0, "concealed pasteboard item was captured")
    },
    TestCase(name: "remote clipboard source is generic when device cannot be inferred") {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipXTests.remote.\(UUID().uuidString)"))
        pasteboard.clearContents()
        let monitor = PasteboardMonitor(pasteboard: pasteboard)
        var captured: ClipItem?
        monitor.onItemCaptured = { item in captured = item }

        pasteboard.clearContents()
        pasteboard.setString("copied from iPhone", forType: .string)
        pasteboard.setData(Data("1".utf8), forType: .remoteClipboard)
        monitor.poll()

        try expect(captured?.sourceApp == "Universal Clipboard", "generic remote clipboard source should not be mislabeled as iOS")
        try expect(captured?.metadata["remoteClipboard"] == "true", "remote clipboard marker was not preserved")
        try expect(captured?.metadata["sourceDeviceFamily"] == nil, "generic remote clipboard should not invent a device family")
        try expect(captured?.metadata["sourceInference"] == "generic", "generic remote clipboard inference was not preserved")
    },
    TestCase(name: "remote RTFD clipboard source is labeled as mobile") {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipXTests.remoteRTFD.\(UUID().uuidString)"))
        pasteboard.clearContents()
        let monitor = PasteboardMonitor(pasteboard: pasteboard)
        var captured: ClipItem?
        monitor.onItemCaptured = { item in captured = item }

        let rtfdData = try richTextData("copied from iPhone Photos", documentType: .rtfd)
        pasteboard.clearContents()
        pasteboard.setData(rtfdData, forType: .publicRTFD)
        pasteboard.setData(Data("1".utf8), forType: .remoteClipboard)
        monitor.poll()

        try expect(captured?.sourceApp == "iOS Device", "remote RTFD clipboard source should be labeled as a mobile device")
        try expect(captured?.metadata["remoteClipboard"] == "true", "remote RTFD marker was not preserved")
        try expect(captured?.metadata["sourceDeviceFamily"] == "iphone", "remote RTFD device family was not preserved")
        try expect(captured?.metadata["sourceInference"] == "mobile-rtfd", "remote RTFD inference was not preserved")
    },
    TestCase(name: "internal writes are not recaptured") {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipXTests.internal.\(UUID().uuidString)"))
        pasteboard.clearContents()
        let monitor = PasteboardMonitor(pasteboard: pasteboard)
        var captured = 0
        monitor.onItemCaptured = { _ in captured += 1 }

        pasteboard.clearContents()
        pasteboard.setString("external", forType: .string)
        monitor.poll(sourceApp: "Unit Test")
        try expect(captured == 1, "external pasteboard item was not captured")

        let item = ClipItem.make(payload: .text("from ClipX"), sourceApp: "ClipX")
        monitor.write(item)
        monitor.poll(sourceApp: "Unit Test")
        try expect(captured == 1, "internal write was recaptured")
    },
    TestCase(name: "HTML clipboard prefers readable plain text") {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipXTests.html.\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString(#"<span style="color: red">acOS</span>"#, forType: .html)
        pasteboard.setString("acOS", forType: .string)

        let item = PasteboardItemFactory.makeItem(from: pasteboard, sourceApp: "Safari")
        try expect(item?.kind == .text, "HTML clipboard should be saved as readable text")
        try expect(item?.payload == .text("acOS"), "HTML clipboard should keep only the readable text")
    },
    TestCase(name: "HTML-only clipboard extracts plain text") {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipXTests.htmlOnly.\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString(#"<span style="caret-color: rgb(31, 35, 40)">acOS</span>"#, forType: .html)

        let item = PasteboardItemFactory.makeItem(from: pasteboard, sourceApp: "Safari")
        try expect(item?.kind == .text, "HTML-only clipboard should be normalized to text")
        try expect(item?.payload == .text("acOS"), "HTML-only clipboard should strip tags and styles")
    },
    TestCase(name: "HTML payload writes readable plain text") {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipXTests.writeHTML.\(UUID().uuidString)"))
        pasteboard.clearContents()
        PasteboardWriter.write(.html(#"<span style="caret-color: rgb(31, 35, 40)">acOS</span>"#), to: pasteboard)

        try expect(pasteboard.string(forType: .string) == "acOS", "HTML payload should write readable plain text")
    },
    TestCase(name: "encrypted store round trips text item") {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try HistoryStore(directory: directory, keyProvider: InMemoryHistoryKeyProvider())
        let item = ClipItem.make(
            payload: .text("Release note: private clipboard history stays on this Mac by default."),
            sourceApp: "Unit Test",
            metadata: ["remoteClipboard": "false"]
        )

        try store.upsert(item)
        let loaded = try store.fetchAll(limit: 10)

        try expect(loaded.count == 1, "store should return one item")
        try expect(loaded.first?.payload == item.payload, "payload did not decrypt correctly")
        try expect(loaded.first?.sourceApp == "Unit Test", "source app did not persist")
    },
    TestCase(name: "default store creates local file key without keychain provider") {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try HistoryStore(directory: directory)
        let item = ClipItem.make(payload: .text("local key"), sourceApp: "Unit Test")

        try store.upsert(item)
        try expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("history.key").path), "default store did not create local key file")
        let loaded = try store.fetchAll(limit: 10)
        try expect(loaded.first?.payload == .text("local key"), "default store could not decrypt payload")
    },
    TestCase(name: "store skips blobs encrypted with another local key") {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        do {
            let store = try HistoryStore(directory: directory, keyProvider: InMemoryHistoryKeyProvider(keyData: Data(repeating: 1, count: 32)))
            try store.upsert(ClipItem.make(payload: .text("old key"), sourceApp: "Unit Test"))
        }

        let store = try HistoryStore(directory: directory, keyProvider: InMemoryHistoryKeyProvider(keyData: Data(repeating: 2, count: 32)))
        let loaded = try store.fetchAll(limit: 10)
        try expect(loaded.isEmpty, "store should skip blobs that cannot be decrypted with the active key")
    },
    TestCase(name: "flags and delete are persisted") {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try HistoryStore(directory: directory, keyProvider: InMemoryHistoryKeyProvider())
        let item = ClipItem.make(payload: .url(URL(string: "https://developer.apple.com")!), sourceApp: "Safari")

        try store.upsert(item)
        try store.updateFlags(id: item.id, favorite: true, pinned: true)
        var loaded = try store.fetchAll(limit: 10)
        try expect(loaded.first?.isFavorite == true, "favorite flag did not persist")
        try expect(loaded.first?.isPinned == true, "pinned flag did not persist")

        try store.delete(id: item.id)
        loaded = try store.fetchAll(limit: 10)
        try expect(loaded.isEmpty, "deleted item was returned")
    },
    TestCase(name: "purge keeps pinned items") {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = try HistoryStore(directory: directory, keyProvider: InMemoryHistoryKeyProvider())
        var old = ClipItem.make(payload: .text("old"), sourceApp: "Unit Test", createdAt: Date(timeIntervalSince1970: 100))
        old.isPinned = true
        let stale = ClipItem.make(payload: .text("stale"), sourceApp: "Unit Test", createdAt: Date(timeIntervalSince1970: 101))

        try store.upsert(old)
        try store.upsert(stale)
        try store.purge(before: Date(timeIntervalSince1970: 200))

        let loaded = try store.fetchAll(limit: 10)
        try expect(loaded.map(\.payload) == [.text("old")], "purge should keep pinned item only")
    }
]

func richTextData(_ text: String, documentType: NSAttributedString.DocumentType) throws -> Data {
    let attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 14)])
    return try attributed.data(
        from: NSRange(location: 0, length: attributed.length),
        documentAttributes: [.documentType: documentType]
    )
}

func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("ClipXTests-\(UUID().uuidString)", isDirectory: true)
}

var failures: [(String, Error)] = []
for test in tests {
    do {
        try test.run()
        print("PASS \(test.name)")
    } catch {
        failures.append((test.name, error))
        print("FAIL \(test.name): \(error)")
    }
}

if failures.isEmpty {
    print("All \(tests.count) ClipX core tests passed.")
} else {
    print("\(failures.count) ClipX core tests failed.")
    exit(1)
}
