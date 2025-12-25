import SwiftData
import SwiftUI

@main
struct MochiLogApp: App {
  private static let appGroupIdentifier = "group.net.ryuya-dev.MochiLog"

  init() {
    prepareApplicationSupportDirectories()
  }

  private func prepareApplicationSupportDirectories() {
    do {
      let fileManager = FileManager.default
      let appSupportURL = try fileManager.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
      print("Database path checked: \(appSupportURL.path)")
      try ensureAppGroupApplicationSupport(in: fileManager)
    } catch {
      print("Failed to create Application Support directory: \(error)")
    }
  }

  private func ensureAppGroupApplicationSupport(in fileManager: FileManager) throws {
    guard
      let containerURL = fileManager.containerURL(
        forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)
    else {
      return
    }
    let libraryURL = containerURL.appendingPathComponent("Library", isDirectory: true)
    let appGroupSupportURL = libraryURL.appendingPathComponent(
      "Application Support", isDirectory: true)
    try fileManager.createDirectory(at: appGroupSupportURL, withIntermediateDirectories: true)
    print("App Group database path checked: \(appGroupSupportURL.path)")
  }

  var body: some Scene {
    WindowGroup {
      MainTabView()
        .onOpenURL { url in
          handleOpenURL(url)
        }
    }
    .modelContainer(for: BatteryRecord.self)
  }

  // 開かれたURLを確認して処理（Document Types経由）
  private func handleOpenURL(_ url: URL) {
    print("Opened via URL: \(url)")

    guard url.isFileURL else { return }

    // ファイルへのアクセス権を要求（共有シートからのファイルはInboxにコピーされる）
    let secure = url.startAccessingSecurityScopedResource()
    defer {
      if secure { url.stopAccessingSecurityScopedResource() }
      // 処理後にInboxのファイルを削除
      cleanupInboxFile(url)
    }

    do {
      // Try common encodings to be resilient to sharing sources
      var text: String? = nil
      // 1. UTF-8
      if let s = try? String(contentsOf: url, encoding: .utf8) { text = s }
      // 2. UTF-16
      if text == nil, let s = try? String(contentsOf: url, encoding: .utf16) { text = s }
      // 3. ISO Latin 1
      if text == nil, let s = try? String(contentsOf: url, encoding: .isoLatin1) { text = s }
      // 4. Shift-JIS (Japanese logs sometimes encoded in Shift-JIS)
      if text == nil, let data = try? Data(contentsOf: url),
        let s = String(data: data, encoding: .shiftJIS)
      {
        text = s
      }
      // 5. Fallback to platform default initializer
      if text == nil, let s = try? String(contentsOf: url) { text = s }

      if let text = text {
        DispatchQueue.main.async {
          // Persist first as a fallback in case the HomeView hasn't registered yet.
          // Write before posting to avoid a race where the observer removes the pending
          // key before it has been set (which could cause double-processing).
          UserDefaults.standard.set(text, forKey: "PendingSharedLogText")

          NotificationCenter.default.post(
            name: NSNotification.Name("ProcessSharedLog"),
            object: nil,
            userInfo: ["text": text]
          )
        }
      } else {
        print("ファイルの読み込み失敗（対応する文字エンコーディングが見つかりません）: \(url)")
        DispatchQueue.main.async {
          NotificationCenter.default.post(
            name: NSNotification.Name("ProcessSharedLog"),
            object: nil,
            userInfo: ["text": ""]
          )
          // Avoid persisting an empty string; notify via UserDefaults that read failed
          UserDefaults.standard.removeObject(forKey: "PendingSharedLogText")
        }
      }
    } catch {
      print("ファイルの読み込み失敗: \(error)")
    }
  }

  // Inboxフォルダにコピーされたファイルを削除
  private func cleanupInboxFile(_ url: URL) {
    // Inboxフォルダ内のファイルかどうかをチェック
    if url.path.contains("/Inbox/") {
      try? FileManager.default.removeItem(at: url)
    }
  }
}
