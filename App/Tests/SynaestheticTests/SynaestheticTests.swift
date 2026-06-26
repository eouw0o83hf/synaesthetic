import XCTest
@testable import Synaesthetic

final class SynaestheticTests: XCTestCase {

    // MARK: - Example Tests

    func test_example_passes() {
        // Replace this with your first real test.
        XCTAssertTrue(true)
    }

    func test_example_async() async throws {
        // Example async test. Use `async throws` for tests that call async code.
        let value = await someAsyncHelper()
        XCTAssertEqual(value, 42)
    }

    // MARK: - Private

    private func someAsyncHelper() async -> Int {
        42
    }
}
