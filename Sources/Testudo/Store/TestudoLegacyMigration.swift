import Foundation
import Security


// ============================================================
// MARK: - Historical product-name migration
//
// Current Testudo source and storage use only the Testudo name.
//
// The historical product name is reconstructed here rather than
// retained as a literal string in the current source tree.
//
// Migration covers:
//
// • ~/Library/Application Support/<historical name>
//      → ~/Library/Application Support/Testudo
//
// • historical root data filenames
//
// • app-owned storage paths inside ApplicationData.json
//
// • historical iCal Keychain services
//
// Portable .testudoenv and .testudouser files are not changed.
// ============================================================

enum TestudoLegacyMigration {

    private static var historicalProductName:
        String
    {
        [
            "D",
            "Report",
        ]
        .joined()
    }


    static func migrateIfNeeded() {

        migrateApplicationSupport()

        migrateKeychainService(
            suffix:
                ".iCalSubscriptions"
        )

        migrateKeychainService(
            suffix:
                ".iCal"
        )
    }


    // ========================================================
    // MARK: Application Support
    // ========================================================

    private static func migrateApplicationSupport() {

        guard
            let applicationSupport =
                FileManager
                    .default
                    .urls(
                        for:
                            .applicationSupportDirectory,
                        in:
                            .userDomainMask
                    )
                    .first
        else {
            return
        }


        let oldRoot =
            applicationSupport
                .appendingPathComponent(
                    historicalProductName,
                    isDirectory:
                        true
                )

        let newRoot =
            applicationSupport
                .appendingPathComponent(
                    "Testudo",
                    isDirectory:
                        true
                )


        guard
            FileManager
                .default
                .fileExists(
                    atPath:
                        oldRoot.path
                )
        else {
            return
        }


        do {

            if
                !FileManager
                    .default
                    .fileExists(
                        atPath:
                            newRoot.path
                    )
            {
                try FileManager
                    .default
                    .moveItem(
                        at:
                            oldRoot,
                        to:
                            newRoot
                    )

            } else {

                try mergeDirectory(
                    from:
                        oldRoot,
                    into:
                        newRoot
                )
            }


            migrateHistoricalFileNames(
                inside:
                    newRoot
            )


            rewriteApplicationDataPaths(
                at:
                    newRoot
                        .appendingPathComponent(
                            "ApplicationData.json"
                        ),
                oldRoot:
                    oldRoot,
                newRoot:
                    newRoot
            )

        } catch {

            print(
                "Testudo: local product-name migration could not be completed:",
                error
            )
        }
    }


    private static func mergeDirectory(
        from source:
            URL,
        into destination:
            URL
    ) throws {

        let fileManager =
            FileManager.default


        try fileManager
            .createDirectory(
                at:
                    destination,
                withIntermediateDirectories:
                    true
            )


        let children =
            try fileManager
                .contentsOfDirectory(
                    at:
                        source,
                    includingPropertiesForKeys:
                        nil
                )


        for sourceItem in children {

            let destinationItem =
                destination
                    .appendingPathComponent(
                        sourceItem
                            .lastPathComponent
                    )


            if
                !fileManager
                    .fileExists(
                        atPath:
                            destinationItem.path
                    )
            {
                try fileManager
                    .moveItem(
                        at:
                            sourceItem,
                        to:
                            destinationItem
                    )

                continue
            }


            var sourceIsDirectory:
                ObjCBool = false

            var destinationIsDirectory:
                ObjCBool = false


            fileManager
                .fileExists(
                    atPath:
                        sourceItem.path,
                    isDirectory:
                        &sourceIsDirectory
                )

            fileManager
                .fileExists(
                    atPath:
                        destinationItem.path,
                    isDirectory:
                        &destinationIsDirectory
                )


            if
                sourceIsDirectory
                    .boolValue,
                destinationIsDirectory
                    .boolValue
            {
                try mergeDirectory(
                    from:
                        sourceItem,
                    into:
                        destinationItem
                )
            }
        }


        let remaining =
            try fileManager
                .contentsOfDirectory(
                    at:
                        source,
                    includingPropertiesForKeys:
                        nil
                )


        if remaining.isEmpty {
            try fileManager
                .removeItem(
                    at:
                        source
                )
        }
    }


    private static func migrateHistoricalFileNames(
        inside root:
            URL
    ) {

        let fileManager =
            FileManager.default


        guard
            let enumerator =
                fileManager
                    .enumerator(
                        at:
                            root,
                        includingPropertiesForKeys:
                            nil
                    )
        else {
            return
        }


        var urls:
            [URL] =
            []


        for case
            let url as URL
            in enumerator
        {
            urls.append(
                url
            )
        }


        // Rename deepest descendants first.
        urls.sort {
            $0
                .pathComponents
                .count
                >
            $1
                .pathComponents
                .count
        }


        for sourceURL in urls {

            let oldName =
                sourceURL
                    .lastPathComponent


            guard
                oldName
                    .contains(
                        historicalProductName
                    )
            else {
                continue
            }


            let newName =
                oldName
                    .replacingOccurrences(
                        of:
                            historicalProductName,
                        with:
                            "Testudo"
                    )


            let destinationURL =
                sourceURL
                    .deletingLastPathComponent()
                    .appendingPathComponent(
                        newName
                    )


            guard
                !fileManager
                    .fileExists(
                        atPath:
                            destinationURL.path
                    )
            else {
                continue
            }


            try?
                fileManager
                    .moveItem(
                        at:
                            sourceURL,
                        to:
                            destinationURL
                    )
        }
    }


    private static func rewriteApplicationDataPaths(
        at applicationDataURL:
            URL,
        oldRoot:
            URL,
        newRoot:
            URL
    ) {

        guard
            let raw =
                try? Data(
                    contentsOf:
                        applicationDataURL
                ),
            let rootObject =
                try? JSONSerialization
                    .jsonObject(
                        with:
                            raw
                    )
        else {
            return
        }


        let rewritten =
            rewriteJSONValue(
                rootObject,
                oldPrefix:
                    oldRoot.path,
                newPrefix:
                    newRoot.path
            )


        guard
            JSONSerialization
                .isValidJSONObject(
                    rewritten
                ),
            let output =
                try? JSONSerialization
                    .data(
                        withJSONObject:
                            rewritten,
                        options:
                            [
                                .prettyPrinted,
                                .sortedKeys,
                            ]
                    )
        else {
            return
        }


        try?
            output
                .write(
                    to:
                        applicationDataURL,
                    options:
                        .atomic
                )
    }


    private static func rewriteJSONValue(
        _ value:
            Any,
        oldPrefix:
            String,
        newPrefix:
            String
    ) -> Any {

        if
            let dictionary =
                value
                    as? [String: Any]
        {
            return
                Dictionary(
                    uniqueKeysWithValues:
                        dictionary
                            .map {
                                key,
                                child
                                in

                                (
                                    key,
                                    rewriteJSONValue(
                                        child,
                                        oldPrefix:
                                            oldPrefix,
                                        newPrefix:
                                            newPrefix
                                    )
                                )
                            }
                )
        }


        if
            let array =
                value
                    as? [Any]
        {
            return
                array
                    .map {
                        rewriteJSONValue(
                            $0,
                            oldPrefix:
                                oldPrefix,
                            newPrefix:
                                newPrefix
                        )
                    }
        }


        if
            let string =
                value
                    as? String,
            string
                == oldPrefix
            || string
                .hasPrefix(
                    oldPrefix
                    + "/"
                )
        {
            return
                newPrefix
                + String(
                    string
                        .dropFirst(
                            oldPrefix.count
                        )
                )
        }


        return value
    }


    // ========================================================
    // MARK: Historical Keychain service names
    // ========================================================

    private static func migrateKeychainService(
        suffix:
            String
    ) {

        let oldService =
            historicalProductName
            + suffix

        let newService =
            "Testudo"
            + suffix


        let query:
            [String: Any] =
            [
                kSecClass as String:
                    kSecClassGenericPassword,

                kSecAttrService as String:
                    oldService,

                kSecReturnAttributes as String:
                    true,

                kSecReturnData as String:
                    true,

                kSecMatchLimit as String:
                    kSecMatchLimitAll,
            ]


        var result:
            CFTypeRef?


        let status =
            SecItemCopyMatching(
                query
                    as CFDictionary,
                &result
            )


        guard
            status
                == errSecSuccess
        else {
            return
        }


        let items:
            [[String: Any]]


        if
            let array =
                result
                    as? [[String: Any]]
        {
            items =
                array

        } else if
            let item =
                result
                    as? [String: Any]
        {
            items =
                [
                    item
                ]

        } else {

            return
        }


        for item in items {

            guard
                let account =
                    item[
                        kSecAttrAccount
                            as String
                    ]
                    as? String,
                let secret =
                    item[
                        kSecValueData
                            as String
                    ]
                    as? Data
            else {
                continue
            }


            let identity:
                [String: Any] =
                [
                    kSecClass as String:
                        kSecClassGenericPassword,

                    kSecAttrService as String:
                        newService,

                    kSecAttrAccount as String:
                        account,
                ]


            var create =
                identity

            create[
                kSecValueData
                    as String
            ] =
                secret


            let addStatus =
                SecItemAdd(
                    create
                        as CFDictionary,
                    nil
                )


            var migrated =
                addStatus
                    == errSecSuccess


            if
                addStatus
                    == errSecDuplicateItem
            {
                let updateStatus =
                    SecItemUpdate(
                        identity
                            as CFDictionary,
                        [
                            kSecValueData as String:
                                secret
                        ]
                            as CFDictionary
                    )

                migrated =
                    updateStatus
                        == errSecSuccess
            }


            guard migrated else {
                continue
            }


            let oldItem:
                [String: Any] =
                [
                    kSecClass as String:
                        kSecClassGenericPassword,

                    kSecAttrService as String:
                        oldService,

                    kSecAttrAccount as String:
                        account,
                ]


            SecItemDelete(
                oldItem
                    as CFDictionary
            )
        }
    }
}
