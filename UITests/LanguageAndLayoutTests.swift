import XCTest

final class LanguageAndLayoutTests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = [
      "-hasCompletedTutorial", "YES", "-iCloudSyncEnabled", "NO",
      "-LastKnownAppVersion", "3.1.1", "-showPopupOnLoad", "NO",
      "-AppleLanguages", "(en)", "-AppleLocale", "en_US"
    ]
  }

  override func tearDownWithError() throws {
    XCUIDevice.shared.orientation = .portrait
    app.terminate()
  }

  private func openLanguage() {
    if app.buttons["language.en"].exists { return }
    if app.tabBars.buttons.count >= 3 {
      app.tabBars.buttons.element(boundBy: 2).tap()
    } else {
      // iPad's floating tab bar exposes cells in iOS 27.
      let settings = app.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@ OR label == %@", "Settings", "Einstellungen")
      ).firstMatch
      XCTAssertTrue(settings.waitForExistence(timeout: 5), app.debugDescription)
      settings.tap()
    }
    let link = app.buttons["settings.language"]
    for _ in 0..<8 {
      if link.exists && link.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(link.waitForExistence(timeout: 5))
    link.tap()
    XCTAssertTrue(app.buttons["language.en"].waitForExistence(timeout: 5))
  }

  private func screenshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func systemLanguageButton() -> XCUIElement {
    let button = app.buttons["language.system"]
    for _ in 0..<8 {
      if button.exists && button.isHittable { break }
      app.swipeDown()
    }
    XCTAssertTrue(button.exists)
    return button
  }

  func testLanguageSelectionPersistsAndUsesDeviceDefault() {
    app.launch()
    openLanguage()
    systemLanguageButton().tap()
    openLanguage()
    XCTAssertTrue(systemLanguageButton().label.contains("Follow device settings"))
    let german = app.buttons["language.de"]
    for _ in 0..<8 {
      if german.isHittable { break }
      app.swipeUp()
    }
    german.tap()
    openLanguage()
    screenshot("German language settings")
    XCTAssertTrue(systemLanguageButton().label.contains("Gerätesprache verwenden"))
    app.terminate()
    app.launch()
    openLanguage()
    XCTAssertTrue(systemLanguageButton().label.contains("Gerätesprache verwenden"))
    systemLanguageButton().tap()
  }

  func testSettingsAtLargeTextAndLandscape() {
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    app.launch()
    openLanguage()
    screenshot("Language settings at largest text size")
    XCUIDevice.shared.orientation = .landscapeLeft
    let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      self.app.frame.width > self.app.frame.height
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed,
      "The app must actually rotate")
    // Wait for the system rotation animation before capturing the whole display.
    Thread.sleep(forTimeInterval: 1)
    XCTAssertTrue(app.buttons["language.en"].waitForExistence(timeout: 5))
    screenshot("Language settings in landscape")
    XCUIDevice.shared.orientation = .portrait
  }
}
