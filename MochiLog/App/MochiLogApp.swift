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
      let text = try String(contentsOf: url, encoding: .utf8)
      // データを渡して処理を実行
      DispatchQueue.main.async {
        NotificationCenter.default.post(
          name: NSNotification.Name("ProcessSharedLog"),
          object: nil,
          userInfo: ["text": text]
        )
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
