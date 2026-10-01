import Foundation
import CryptoKit
import Security

enum PasswordHasher {
    static let defaultIterations = 120_000

    static func createHash(
        password: String
    ) throws -> (
        saltBase64: String,
        hashBase64: String,
        iterations: Int
    ) {
        let salt =
            try randomData(
                count: 16
            )

        let hash =
            deriveKey(
                password: password,
                salt: salt,
                iterations:
                    defaultIterations
            )

        return (
            salt.base64EncodedString(),
            hash.base64EncodedString(),
            defaultIterations
        )
    }

    static func verify(
        password: String,
        saltBase64: String,
        expectedHashBase64: String,
        iterations: Int
    ) -> Bool {
        guard
            let salt =
                Data(
                    base64Encoded:
                        saltBase64
                ),
            let expected =
                Data(
                    base64Encoded:
                        expectedHashBase64
                )
        else {
            return false
        }

        let candidate =
            deriveKey(
                password: password,
                salt: salt,
                iterations:
                    iterations
            )

        return timingSafeEqual(
            candidate,
            expected
        )
    }

    private static func deriveKey(
        password: String,
        salt: Data,
        iterations: Int
    ) -> Data {
        let key =
            SymmetricKey(
                data:
                    Data(
                        password.utf8
                    )
            )

        var blockIndex =
            UInt32(1).bigEndian

        let blockData =
            withUnsafeBytes(
                of: &blockIndex
            ) {
                Data($0)
            }

        var firstInput = Data()
        firstInput.append(salt)
        firstInput.append(blockData)

        var u =
            Data(
                HMAC<SHA256>
                    .authenticationCode(
                        for: firstInput,
                        using: key
                    )
            )

        var result = u

        if iterations > 1 {
            for _ in 2...iterations {
                u =
                    Data(
                        HMAC<SHA256>
                            .authenticationCode(
                                for: u,
                                using: key
                            )
                    )

                for index in result.indices {
                    result[index] =
                        result[index]
                        ^ u[index]
                }
            }
        }

        return result
    }

    private static func randomData(
        count: Int
    ) throws -> Data {
        var bytes =
            [UInt8](
                repeating: 0,
                count: count
            )

        let status =
            SecRandomCopyBytes(
                kSecRandomDefault,
                bytes.count,
                &bytes
            )

        guard status == errSecSuccess else {
            throw NSError(
                domain:
                    "DReport.PasswordHasher",
                code: Int(status)
            )
        }

        return Data(bytes)
    }

    private static func timingSafeEqual(
        _ lhs: Data,
        _ rhs: Data
    ) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }

        var difference: UInt8 = 0

        for index in lhs.indices {
            difference |=
                lhs[index] ^ rhs[index]
        }

        return difference == 0
    }
}
