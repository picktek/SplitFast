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

    func testShareHandoffShowsSourceAndClearReturnsToEmptyState() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_RESET_STATE"]
        app.launchEnvironment = [
            "UITEST_HANDOFF_URL": "splitfast://split?url=file:///tmp/shared.mov&name=shared.mov&access=copiedFallback&delete=0"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["shared.mov"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Copied fallback"].exists)
        XCTAssertTrue(app.buttons["startSplitButton"].isEnabled)

        app.buttons["clearSelectionButton"].tap()

        XCTAssertFalse(app.staticTexts["shared.mov"].exists)
        XCTAssertFalse(app.buttons["startSplitButton"].isEnabled)
    }

    func testClipLengthControlsUpdateAndPersist() {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST_RESET_STATE"]
        app.launch()

        XCTAssertTrue(app.staticTexts["clipLengthValue"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["clipLengthValue"].label, "30 seconds")

        app.buttons["clipLengthPreset60"].tap()
        XCTAssertEqual(app.staticTexts["clipLengthValue"].label, "60 seconds")

        app.buttons["decreaseClipLengthButton"].tap()
        XCTAssertEqual(app.staticTexts["clipLengthValue"].label, "55 seconds")

        app.buttons["increaseClipLengthButton"].tap()
        XCTAssertEqual(app.staticTexts["clipLengthValue"].label, "60 seconds")

        app.terminate()

        let relaunched = XCUIApplication()
        relaunched.launch()

        XCTAssertTrue(relaunched.staticTexts["clipLengthValue"].waitForExistence(timeout: 3))
        XCTAssertEqual(relaunched.staticTexts["clipLengthValue"].label, "60 seconds")
    }
}
