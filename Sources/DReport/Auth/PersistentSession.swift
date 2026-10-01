import Foundation
import Security

enum PersistentSession {
    private static let service =
        "com.dreport.DReport.session"

    private static let account =
        "current-user"

    static func save(
        userID: UUID
    ) {
        let data =
            Data(
                userID.uuidString.utf8
            )

        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,
            kSecAttrService as String:
                service,
            kSecAttrAccount as String:
                account
        ]

        SecItemDelete(
            query as CFDictionary
        )

        var insert = query

        insert[
            kSecValueData as String
        ] = data

        insert[
            kSecAttrAccessible as String
        ] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        SecItemAdd(
            insert as CFDictionary,
            nil
        )
    }

    static func loadUserID() -> UUID? {
        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,
            kSecAttrService as String:
                service,
            kSecAttrAccount as String:
                account,
            kSecReturnData as String:
                true,
            kSecMatchLimit as String:
                kSecMatchLimitOne
        ]

        var result:
            CFTypeRef?

        let status =
            SecItemCopyMatching(
                query as CFDictionary,
                &result
            )

        guard
            status == errSecSuccess,
            let data =
                result as? Data,
            let string =
                String(
                    data: data,
                    encoding: .utf8
                )
        else {
            return nil
        }

        return UUID(
            uuidString: string
        )
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String:
                kSecClassGenericPassword,
            kSecAttrService as String:
                service,
            kSecAttrAccount as String:
                account
        ]

        SecItemDelete(
            query as CFDictionary
        )
    }
}
