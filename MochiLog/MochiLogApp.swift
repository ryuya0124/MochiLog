import SwiftData
import SwiftUI

@main
struct MochiLogApp: App {

  // アプリ起動時に「Application Support」フォルダがあるか確認し、なければ作る
  init() {
    do {
      let fileManager = FileManager.default
      let appSupportURL = try fileManager.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      print("Database path checked: \(appSupportURL.path)")
    } catch {
      print("Failed to create Application Support directory: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(for: BatteryRecord.self)
  }
}
