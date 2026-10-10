import Foundation

public enum EnvironmentJSONCodec {

    public static func encode<T: Encodable>(
        _ value: T
    ) throws -> Data {

        let encoder = JSONEncoder()

        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]

        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(value)
    }

    public static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data
    ) throws -> T {

        let decoder = JSONDecoder()

        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(type, from: data)
    }
}
