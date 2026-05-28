import CryptoKit
import Foundation
import Security
import SQLite3

public protocol HistoryStoring {
    func upsert(_ item: ClipItem) throws
    func fetchAll(limit: Int) throws -> [ClipItem]
    func delete(id: UUID) throws
    func updateFlags(id: UUID, favorite: Bool?, pinned: Bool?) throws
    func purge(before date: Date) throws
}

public protocol HistoryKeyProviding {
    func loadOrCreateKey() throws -> SymmetricKey
}

public enum HistoryStoreError: Error, Equatable {
    case databaseOpenFailed(String)
    case databaseStepFailed(String)
    case databasePrepareFailed(String)
    case keychainFailed(OSStatus)
    case encryptionFailed
    case missingBlob(UUID)
}

public final class HistoryStore: HistoryStoring {
    private let databaseURL: URL
    private let blobDirectory: URL
    private let keyProvider: HistoryKeyProviding
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var db: OpaquePointer?

    public init(
        directory: URL = HistoryStore.defaultDirectory,
        keyProvider: HistoryKeyProviding? = nil
    ) throws {
        self.databaseURL = directory.appendingPathComponent("clipx.sqlite")
        self.blobDirectory = directory.appendingPathComponent("blobs", isDirectory: true)
        self.keyProvider = keyProvider ?? FileHistoryKeyProvider(directory: directory)

        try FileManager.default.createDirectory(at: blobDirectory, withIntermediateDirectories: true)
        if sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) != SQLITE_OK {
            throw HistoryStoreError.databaseOpenFailed(lastSQLiteError)
        }
        try execute(Self.schemaSQL)
    }

    deinit {
        sqlite3_close(db)
    }

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ClipX", isDirectory: true)
    }

    public func upsert(_ item: ClipItem) throws {
        let blobName = "\(item.id.uuidString).blob"
        try saveEncryptedPayload(item.payload, blobName: blobName)

        let metadataData = try encoder.encode(item.metadata)
        let metadataJSON = String(data: metadataData, encoding: .utf8) ?? "{}"
        let sql = """
        INSERT INTO clips (id, kind, source_app, created_at, preview, metadata_json, blob_name, favorite, pinned, sensitive, rtfd_fixed)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          kind = excluded.kind,
          source_app = excluded.source_app,
          created_at = excluded.created_at,
          preview = excluded.preview,
          metadata_json = excluded.metadata_json,
          blob_name = excluded.blob_name,
          favorite = excluded.favorite,
          pinned = excluded.pinned,
          sensitive = excluded.sensitive,
          rtfd_fixed = excluded.rtfd_fixed
        """

        try withStatement(sql) { statement in
            bindText(statement, 1, item.id.uuidString)
            bindText(statement, 2, item.kind.rawValue)
            bindText(statement, 3, item.sourceApp)
            sqlite3_bind_double(statement, 4, item.createdAt.timeIntervalSince1970)
            bindText(statement, 5, item.preview)
            bindText(statement, 6, metadataJSON)
            bindText(statement, 7, blobName)
            sqlite3_bind_int(statement, 8, item.isFavorite ? 1 : 0)
            sqlite3_bind_int(statement, 9, item.isPinned ? 1 : 0)
            sqlite3_bind_int(statement, 10, item.isSensitive ? 1 : 0)
            sqlite3_bind_int(statement, 11, item.wasRTFDFixed ? 1 : 0)
            try stepDone(statement)
        }
    }

    public func fetchAll(limit: Int = 500) throws -> [ClipItem] {
        let sql = """
        SELECT id, kind, source_app, created_at, preview, metadata_json, blob_name, favorite, pinned, sensitive, rtfd_fixed
        FROM clips
        ORDER BY pinned DESC, created_at DESC
        LIMIT ?
        """

        return try withStatement(sql) { statement in
            sqlite3_bind_int(statement, 1, Int32(limit))
            var items: [ClipItem] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard
                    let id = UUID(uuidString: columnText(statement, 0)),
                    let kind = ClipKind(rawValue: columnText(statement, 1))
                else { continue }

                let metadataData = Data(columnText(statement, 5).utf8)
                let metadata = (try? decoder.decode([String: String].self, from: metadataData)) ?? [:]
                let blobName = columnText(statement, 6)
                guard let payload = try? loadEncryptedPayload(blobName: blobName) else {
                    continue
                }
                items.append(ClipItem(
                    id: id,
                    kind: kind,
                    sourceApp: columnText(statement, 2),
                    createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                    preview: columnText(statement, 4),
                    metadata: metadata,
                    payload: payload,
                    isFavorite: sqlite3_column_int(statement, 7) == 1,
                    isPinned: sqlite3_column_int(statement, 8) == 1,
                    isSensitive: sqlite3_column_int(statement, 9) == 1,
                    wasRTFDFixed: sqlite3_column_int(statement, 10) == 1
                ))
            }
            return items
        }
    }

    public func delete(id: UUID) throws {
        try withStatement("DELETE FROM clips WHERE id = ?") { statement in
            bindText(statement, 1, id.uuidString)
            try stepDone(statement)
        }
        let blob = blobDirectory.appendingPathComponent("\(id.uuidString).blob")
        try? FileManager.default.removeItem(at: blob)
    }

    public func updateFlags(id: UUID, favorite: Bool? = nil, pinned: Bool? = nil) throws {
        if let favorite {
            try withStatement("UPDATE clips SET favorite = ? WHERE id = ?") { statement in
                sqlite3_bind_int(statement, 1, favorite ? 1 : 0)
                bindText(statement, 2, id.uuidString)
                try stepDone(statement)
            }
        }
        if let pinned {
            try withStatement("UPDATE clips SET pinned = ? WHERE id = ?") { statement in
                sqlite3_bind_int(statement, 1, pinned ? 1 : 0)
                bindText(statement, 2, id.uuidString)
                try stepDone(statement)
            }
        }
    }

    public func purge(before date: Date) throws {
        let ids = try idsBefore(date: date)
        for id in ids {
            try delete(id: id)
        }
    }

    private func idsBefore(date: Date) throws -> [UUID] {
        try withStatement("SELECT id FROM clips WHERE created_at < ? AND pinned = 0") { statement in
            sqlite3_bind_double(statement, 1, date.timeIntervalSince1970)
            var ids: [UUID] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                if let id = UUID(uuidString: columnText(statement, 0)) {
                    ids.append(id)
                }
            }
            return ids
        }
    }

    private func saveEncryptedPayload(_ payload: ClipPayload, blobName: String) throws {
        let key = try keyProvider.loadOrCreateKey()
        let data = try encoder.encode(payload)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw HistoryStoreError.encryptionFailed }
        try combined.write(to: blobDirectory.appendingPathComponent(blobName), options: .atomic)
    }

    private func loadEncryptedPayload(blobName: String) throws -> ClipPayload {
        let url = blobDirectory.appendingPathComponent(blobName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) ?? UUID()
            throw HistoryStoreError.missingBlob(id)
        }
        let key = try keyProvider.loadOrCreateKey()
        let data = try Data(contentsOf: url)
        let box = try AES.GCM.SealedBox(combined: data)
        let opened = try AES.GCM.open(box, using: key)
        return try decoder.decode(ClipPayload.self, from: opened)
    }

    private func execute(_ sql: String) throws {
        var error: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? lastSQLiteError
            sqlite3_free(error)
            throw HistoryStoreError.databaseStepFailed(message)
        }
    }

    private func withStatement<T>(_ sql: String, body: (OpaquePointer?) throws -> T) throws -> T {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryStoreError.databasePrepareFailed(lastSQLiteError)
        }
        defer { sqlite3_finalize(statement) }
        return try body(statement)
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw HistoryStoreError.databaseStepFailed(lastSQLiteError)
        }
    }

    private var lastSQLiteError: String {
        guard let db else { return "SQLite database is not open" }
        return String(cString: sqlite3_errmsg(db))
    }

    private static let schemaSQL = """
    CREATE TABLE IF NOT EXISTS clips (
      id TEXT PRIMARY KEY NOT NULL,
      kind TEXT NOT NULL,
      source_app TEXT NOT NULL,
      created_at REAL NOT NULL,
      preview TEXT NOT NULL,
      metadata_json TEXT NOT NULL,
      blob_name TEXT NOT NULL,
      favorite INTEGER NOT NULL DEFAULT 0,
      pinned INTEGER NOT NULL DEFAULT 0,
      sensitive INTEGER NOT NULL DEFAULT 0,
      rtfd_fixed INTEGER NOT NULL DEFAULT 0
    );
    CREATE INDEX IF NOT EXISTS clips_created_at_idx ON clips(created_at DESC);
    CREATE INDEX IF NOT EXISTS clips_kind_idx ON clips(kind);
    """
}

public struct InMemoryHistoryKeyProvider: HistoryKeyProviding {
    private let keyData: Data

    public init(keyData: Data = Data(repeating: 7, count: 32)) {
        self.keyData = keyData
    }

    public func loadOrCreateKey() throws -> SymmetricKey {
        SymmetricKey(data: keyData)
    }
}

public struct FileHistoryKeyProvider: HistoryKeyProviding {
    private let keyURL: URL

    public init(directory: URL = HistoryStore.defaultDirectory) {
        self.keyURL = directory.appendingPathComponent("history.key")
    }

    public func loadOrCreateKey() throws -> SymmetricKey {
        if FileManager.default.fileExists(atPath: keyURL.path) {
            return SymmetricKey(data: try Data(contentsOf: keyURL))
        }

        try FileManager.default.createDirectory(
            at: keyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var keyData = Data(count: 32)
        let status = keyData.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw HistoryStoreError.keychainFailed(status)
        }

        try keyData.write(to: keyURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: keyURL.path
        )
        return SymmetricKey(data: keyData)
    }
}

public struct KeychainHistoryKeyProvider: HistoryKeyProviding {
    private let service = "ClipX"
    private let account = "HistoryEncryptionKey"

    public init() {}

    public func loadOrCreateKey() throws -> SymmetricKey {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else {
            throw HistoryStoreError.keychainFailed(status)
        }

        var keyData = Data(count: 32)
        let randomStatus = keyData.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard randomStatus == errSecSuccess else {
            throw HistoryStoreError.keychainFailed(randomStatus)
        }

        query.removeValue(forKey: kSecReturnData as String)
        query[kSecValueData as String] = keyData
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess || addStatus == errSecDuplicateItem else {
            throw HistoryStoreError.keychainFailed(addStatus)
        }
        return SymmetricKey(data: keyData)
    }
}

private func bindText(_ statement: OpaquePointer?, _ index: Int32, _ text: String) {
    sqlite3_bind_text(statement, index, text, -1, SQLITE_TRANSIENT)
}

private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String {
    guard let text = sqlite3_column_text(statement, index) else { return "" }
    return String(cString: text)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
