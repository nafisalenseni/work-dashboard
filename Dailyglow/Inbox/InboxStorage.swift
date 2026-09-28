import Foundation
import Security

struct InboxNote: Codable, Identifiable {
  let id: UUID
  let body: String
  let source: String
  let captured_at: String

}

// Presentation state stays on this Mac until task fields are added to the backend.
struct InboxLocalState: Codable, Equatable {
  struct Draft: Codable, Equatable {
    var id: UUID
    var body: String
  }
  var drafts: [Draft] = []
  var completed: Set<UUID> = []
  var todayIDs: Set<UUID>? = nil
  var categories: [String: String]? = nil
  var order: [UUID] = []

  static let key = "dailyglow.inbox.local-tasks.v1"
  static func load() -> Self {
    guard let data = UserDefaults.standard.data(forKey: key),
      let state = try? JSONDecoder().decode(Self.self, from: data)
    else { return Self() }
    return state
  }
}

struct InboxResponse: Decodable { let notes: [InboxNote] }

enum InboxKeychain {
  static func query(_ project: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "dailyglow.inbox.read-secret",
      kSecAttrAccount as String: project,
    ]
  }

  static func read(_ project: String) throws -> String? {
    var query = query(project)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data,
      let secret = String(data: data, encoding: .utf8)
    else {
      throw InboxError.message("Could not read the inbox credential from Keychain.")
    }
    return secret
  }

  static func save(_ secret: String, project: String) throws {
    let query = query(project)
    let attributes = [kSecValueData as String: Data(secret.utf8)]
    var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var item = query.merging(attributes) { _, new in new }
      item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
      status = SecItemAdd(item as CFDictionary, nil)
    }
    guard status == errSecSuccess else {
      throw InboxError.message("Could not save the inbox credential in Keychain.")
    }
  }
}

enum InboxError: LocalizedError {
  case message(String)
  var errorDescription: String? {
    switch self {
    case .message(let message): message
    }
  }
}

