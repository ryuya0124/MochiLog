import XCTest

/// Uses records delivered by the paired iPhone fixture import; never creates cloud data.
final class WatchLayoutTests: XCTestCase {
  func testSyncedRecordsAndGermanDetails() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-appLanguage", "system", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
    app.launch()
    let device = app.buttons["watch.device.iPhone 15 Pro"]
    XCTAssertTrue(device.waitForExistence(timeout: 30), app.debugDescription)
    // The Watch launch transition can outlive the accessibility tree's first snapshot.
    Thread.sleep(forTimeInterval: 2)
    attach(app, "German Watch device list")
    // Initial event injection is intermittent on the watchOS 27 simulator.
    app.staticTexts["iPhone 15 Pro"].tap()
    let record = app.buttons.matching(identifier: "watch.record").firstMatch
    if !record.waitForExistence(timeout: 3) {
      attach(app, "Initial Watch tap did not navigate")
      // Retry only while the original destination is absent and the source is still visible.
      XCTAssertTrue(device.exists && device.isHittable, app.debugDescription)
      app.staticTexts["iPhone 15 Pro"].tap()
    }
    attach(app, "German Watch records")
    XCTAssertTrue(record.waitForExistence(timeout: 5), app.debugDescription)
    record.tap()
    attach(app, "German Watch health ring")
    scrollTo(app.staticTexts["Gemessene Kapazität"], in: app)
    attach(app, "German Watch battery details")
    scrollTo(app.staticTexts["Diagnoseergebnis"], in: app)
    attach(app, "German Watch diagnosis")
    scrollTo(app.staticTexts["Protokolldatum"], in: app)
    attach(app, "German Watch diagnostic and date")
  }

  private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
    XCTAssertTrue(element.waitForExistence(timeout: 5))
    for _ in 0..<24 {
      if isVisible(element, in: app) { break }
      let down = element.frame.midY < app.frame.midY
      app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.45 : 0.65))
        .press(forDuration: 0.1,
          thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.65 : 0.45)),
          withVelocity: .slow, thenHoldForDuration: 0.2)
      Thread.sleep(forTimeInterval: 0.3)
    }
    if !isVisible(element, in: app) { attach(app, "Unexpected scroll position") }
    XCTAssertTrue(isVisible(element, in: app), app.debugDescription)
  }

  private func isVisible(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
    let frame = element.frame
    let screen = app.frame
    return element.isHittable && frame.minY >= screen.minY + 48
      && frame.maxY <= screen.maxY - 36 && frame.width > 0 && frame.height > 0
  }

  private func attach(_ app: XCUIApplication, _ name: String) {
    let screenshot = XCUIScreen.main.screenshot()
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(name + ".png")
    try? screenshot.pngRepresentation.write(to: path)
    print("UI_SCREENSHOT: \(path.path)")
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
