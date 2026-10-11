import XCTest
@testable import Testudo

final class TestudoStoreImportTests: XCTestCase {

    func testStoreTypeIsAvailableWithoutInitialization() {
        let storeType = TestudoStore.self

        XCTAssertEqual(
            String(describing: storeType),
            "TestudoStore"
        )
    }
}
