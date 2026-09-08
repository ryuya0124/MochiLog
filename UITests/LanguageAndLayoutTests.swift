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

  private func openLanguage() {
    if app.buttons["language.en"].exists { return }
    app.tabBars.buttons.element(boundBy: 2).tap()
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
    let attachment = XCTAttachment(screenshot: app.screenshot())
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
    XCTAssertTrue(app.buttons["language.en"].waitForExistence(timeout: 5))
    screenshot("Language settings in landscape")
    XCUIDevice.shared.orientation = .portrait
  }
}
