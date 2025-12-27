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
      MochiLogRootView()
        .onOpenURL { url in
          handleOpenURL(url)
        }
    }
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
        let silent = !AppSettings.shared.openAppAfterShareImport
        UserDefaults.standard.set(text, forKey: "PendingSharedLogText")
        UserDefaults.standard.set(silent, forKey: "PendingSharedLogSilent")

        NotificationCenter.default.post(
          name: NSNotification.Name("ProcessSharedLog"),
          object: nil,
          userInfo: ["text": text, "silent": silent]
        )
      }
    } else {
      print("ファイルの読み込み失敗（対応する文字エンコーディングが見つかりません）: \(url)")
      DispatchQueue.main.async {
        let silent = !AppSettings.shared.openAppAfterShareImport
        NotificationCenter.default.post(
          name: NSNotification.Name("ProcessSharedLog"),
          object: nil,
          userInfo: ["text": "", "silent": silent]
        )
        // Avoid persisting an empty string; notify via UserDefaults that read failed
        UserDefaults.standard.removeObject(forKey: "PendingSharedLogText")
        UserDefaults.standard.removeObject(forKey: "PendingSharedLogSilent")
      }
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

/// アプリのルートビュー。iCloud設定に応じてModelContainerを動的に切り替える責務を持つ。
struct MochiLogRootView: View {
  @ObservedObject private var appSettings = AppSettings.shared
  @State private var container: ModelContainer?
  @State private var viewID = UUID()

  var body: some View {
    Group {
      if let container = container {
        MainTabView()
          .modelContainer(container)
          .id(viewID)  // IDを変更することでView階層全体を強制的に再構築
      } else {
        ProgressView()
      }
    }
    .onAppear {
      reloadContainer()
    }
    .onChange(of: appSettings.iCloudSyncEnabled) { _, _ in
      print("iCloud設定変更検知 - RootView再構築開始")
      reloadContainer()
    }
  }

  private func reloadContainer() {
    let isEnabled = appSettings.iCloudSyncEnabled
    print("コンテナ再生成開始: iCloud \(isEnabled ? "有効" : "無効")")

    let schema = Schema([BatteryRecord.self])
    let modelConfiguration: ModelConfiguration

    if isEnabled {
      modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    } else {
      modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none
      )
    }

    do {
      let newContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
      // 少し遅延させることでViewの破棄->生成をより確実にする（オプショナル）
      // ここでは即座に更新するが、IDを一新する
      self.container = newContainer
      self.viewID = UUID()
      print("コンテナ再生成完了: ID \(self.viewID)")
    } catch {
      fatalError("ModelContainerの作成に失敗しました: \(error)")
    }
  }
}
