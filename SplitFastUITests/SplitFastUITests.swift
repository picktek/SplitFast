import XCTest

final class SplitFastUITests: XCTestCase {
    func testLaunchShowsDefaultSplitControlsAndEmptyHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_RESET_STATE"]
        app.launch()

        XCTAssertTrue(app.navigationBars["SplitFast"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["chooseVideoButton"].exists)
        XCTAssertEqual(app.staticTexts["clipLengthValue"].label, "30 seconds")
        XCTAssertFalse(app.buttons["startSplitButton"].isEnabled)

        app.buttons["jobHistoryButton"].tap()

        XCTAssertTrue(app.staticTexts["emptyJobHistory"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["clearAllHistoryButton"].isEnabled)
    }
}
