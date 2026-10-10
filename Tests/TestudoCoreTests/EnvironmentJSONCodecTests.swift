import Foundation
import XCTest
@testable import TestudoCore

final class EnvironmentJSONCodecTests: XCTestCase {

    private struct Sample: Codable, Equatable {
        let id: UUID
        let title: String
        let createdAt: Date
        let status: String
    }

    private func sample() -> Sample {
        Sample(
            id: UUID(
                uuidString:
                    "11111111-2222-3333-4444-555555555555"
            )!,
            title: "Testudo Research",
            createdAt: Date(
                timeIntervalSince1970: 1_700_000_000
            ),
            status: "inProgress"
        )
    }

    func testEncodingMatchesLegacySettings() throws {
        let value = sample()

        let oldEncoder = JSONEncoder()

        oldEncoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        oldEncoder.dateEncodingStrategy = .iso8601

        let expected = try oldEncoder.encode(value)

        let actual = try EnvironmentJSONCodec.encode(value)

        XCTAssertEqual(actual, expected)
    }

    func testRoundTripPreservesData() throws {
        let value = sample()

        let encoded = try EnvironmentJSONCodec.encode(value)

        let decoded = try EnvironmentJSONCodec.decode(
            Sample.self,
            from: encoded
        )

        XCTAssertEqual(decoded, value)
    }

    func testInvalidJSONIsRejected() {
        let invalid = Data("invalid json".utf8)

        XCTAssertThrowsError(
            try EnvironmentJSONCodec.decode(
                Sample.self,
                from: invalid
            )
        )
    }

    func testUnknownFieldsAreIgnoredDuringDecode() throws {
        let value = sample()

        let encoded = try EnvironmentJSONCodec.encode(value)

        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: encoded
            ) as? [String: Any]
        )

        object["unknownFutureField"] = "future value"

        let extended = try JSONSerialization.data(
            withJSONObject: object
        )

        let decoded = try EnvironmentJSONCodec.decode(
            Sample.self,
            from: extended
        )

        XCTAssertEqual(decoded, value)
    }
}
