import XCTest

final class SynaestheticUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments += ["--uitesting"]
        app.launch()
    }

    func test_appLaunches_withoutCrash() {
        XCTAssertTrue(app.exists)
    }

    func test_homeScreen_isVisible() {
        // Adjust this assertion to match your actual root view content.
        XCTAssertTrue(app.staticTexts.firstMatch.exists)
    }
}
