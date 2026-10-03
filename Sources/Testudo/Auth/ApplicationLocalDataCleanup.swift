import Foundation
import Security


enum ApplicationLocalDataCleanup {

    static func removeOwnedKeychainItems() {

        let query:
            [String: Any] =
            [
                kSecClass as String:
                    kSecClassGenericPassword,

                kSecReturnAttributes as String:
                    true,

                kSecMatchLimit as String:
                    kSecMatchLimitAll,
            ]


        var rawResult:
            CFTypeRef?


        let status =
            SecItemCopyMatching(
                query as CFDictionary,
                &rawResult
            )


        guard
            status
                == errSecSuccess,
            let items =
                rawResult
                    as? [[String: Any]]
        else {
            return
        }


        for item in items {

            let service =
                item[
                    kSecAttrService
                        as String
                ]
                as? String
                ?? ""

            let account =
                item[
                    kSecAttrAccount
                        as String
                ]
                as? String
                ?? ""


            let ownershipMarker =
                "\(service) \(account)"
                    .lowercased()


            guard
                ownershipMarker
                    .contains(
                        "testudo"
                    )
                || ownershipMarker
                    .contains(
                        "testudo"
                    )
            else {
                continue
            }


            var deleteQuery:
                [String: Any] =
                [
                    kSecClass as String:
                        kSecClassGenericPassword
                ]


            if !service.isEmpty {
                deleteQuery[
                    kSecAttrService
                        as String
                ] =
                    service
            }


            if !account.isEmpty {
                deleteQuery[
                    kSecAttrAccount
                        as String
                ] =
                    account
            }


            SecItemDelete(
                deleteQuery
                    as CFDictionary
            )
        }
    }
}
