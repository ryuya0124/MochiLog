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

  func testRefreshedOverviewScreens() {
    verifyOverview(size: "UICTContentSizeCategoryL")
  }

  func testRefreshedOverviewAtAccessibilitySize() {
    verifyOverview(size: "UICTContentSizeCategoryAccessibilityXXXL")
  }

  func testRefreshedLandscapeOverview() {
    XCUIDevice.shared.orientation = .landscapeLeft
    verifyOverview(size: "UICTContentSizeCategoryL")
  }

  func testRecordInfoSettingPersists() {
    app.launch()
    func openSettings() {
      let tab = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Settings")).firstMatch
      XCTAssertTrue(tab.waitForExistence(timeout: 10))
      tab.tap()
    }
    openSettings()
    let toggle = app.switches["settings.recordInfo"].firstMatch
    XCTAssertTrue(toggle.waitForExistence(timeout: 10))
    let original = toggle.value as? String
    toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    let changed = toggle.value as? String
    XCTAssertNotEqual(original, changed)
    screenshot("Settings Info Toggle")
    app.terminate()
    app.launch()
    openSettings()
    XCTAssertTrue(toggle.waitForExistence(timeout: 10))
    XCTAssertEqual(toggle.value as? String, changed)
    toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    XCTAssertEqual(toggle.value as? String, original)
  }

  func testStatisticsCards() {
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
    app.launch()
    let tab = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Analytics")).firstMatch
    XCTAssertTrue(tab.waitForExistence(timeout: 10))
    tab.tap()
    let statistics = app.otherElements["analytics.statistics"].firstMatch
    for _ in 0..<6 {
      if statistics.exists && statistics.isHittable { break }
      app.swipeUp()
    }
    app.swipeUp()
    XCTAssertTrue(app.staticTexts["Statistics"].firstMatch.exists)
    screenshot("Device Statistics")
  }

  func testLanguageAtBottom() {
    app.launch()
    openLanguage()
    XCTAssertTrue(app.buttons["language.en"].exists)
    screenshot("Language Settings at Bottom")
  }

  func testSettingsSidebarRemainsVisible() {
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
    app.launch()
    openLanguage()
    let watch = app.buttons["settings.category.appleWatch"]
    screenshot("Language Sidebar")
    XCTAssertTrue(watch.exists, app.debugDescription)
    let sidebar = app.scrollViews.containing(.button, identifier: "settings.language").firstMatch
    if !watch.isHittable { sidebar.swipeDown() }
    watch.tap()
    screenshot("Watch Settings Sidebar")
    XCTAssertTrue(app.buttons["settings.language"].exists)
    app.buttons["settings.category.advanced"].tap()
    screenshot("Advanced Light Settings")
  }

  private func verifyOverview(size: String) {
    app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
    app.launch()
    if app.buttons["View Sample Data"].exists { app.buttons["View Sample Data"].tap() }
    XCTAssertTrue(app.staticTexts["iPhone 15 Pro"].firstMatch.waitForExistence(timeout: 15))
    screenshot("Refreshed Home")
    for title in ["Analytics", "Settings"] {
      let tab = app.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@", title)).firstMatch
      XCTAssertTrue(tab.waitForExistence(timeout: 5), app.debugDescription)
      tab.tap()
      if title == "Analytics" {
        XCTAssertTrue(app.buttons["chart.range"].firstMatch.waitForExistence(timeout: 10), app.debugDescription)
      } else {
        XCTAssertTrue(app.switches["settings.recordInfo"].firstMatch.waitForExistence(timeout: 10), app.debugDescription)
      }
      screenshot("Refreshed " + title)
    }
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
      let sidebar = app.scrollViews.containing(.button, identifier: "settings.language").firstMatch
      if sidebar.exists { sidebar.swipeUp() } else { app.swipeUp() }
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
