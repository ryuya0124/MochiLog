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
      // App Group 用の Application Support フォルダも作成しておく
      if let groupURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.net.ryuya-dev.MochiLog")
      {
        let groupAppSupport = groupURL.appendingPathComponent(
          "Library/Application Support", isDirectory: true)
        try? fileManager.createDirectory(
          at: groupAppSupport, withIntermediateDirectories: true, attributes: nil)
        print("App Group Database path checked: \(groupAppSupport.path)")
      }
    } catch {
      print("Failed to create Application Support directory: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .onAppear {
          checkForSharedData()
        }
    }
    .modelContainer(for: BatteryRecord.self)
  }

  // Share Extensionからの共有データをチェック
  private func checkForSharedData() {
    let userDefaults = UserDefaults(suiteName: "group.net.ryuya-dev.MochiLog")
    if let sharedText = userDefaults?.string(forKey: "sharedLogText"), !sharedText.isEmpty {
      // 処理後は削除
      userDefaults?.removeObject(forKey: "sharedLogText")
      userDefaults?.synchronize()

      // NotificationCenterで通知
      NotificationCenter.default.post(
        name: NSNotification.Name("ProcessSharedLog"),
        object: nil,
        userInfo: ["text": sharedText]
      )
    }
  }
}
