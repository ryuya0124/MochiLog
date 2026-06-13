import Combine
import SwiftUI
import WatchConnectivity

@main
struct MochiLogApp: App {
  private static let appGroupIdentifier = "group.net.ryuya-dev.MochiLog"

  init() {
    prepareApplicationSupportDirectories()

    // Watch Connectivityセッションを開始
    WatchConnectivityManager.shared.startSession()

    // ファイルピッカー経由の単一ファイル処理完了通知（ログのみ）
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("SharedLogProcessingCompleted"),
      object: nil,
      queue: .main
    ) { notification in
      let hash = notification.userInfo?["contentHash"] as? Int
      print(
        "[MochiLogApp] Single file processing completed. Hash: \(String(describing: hash))")
    }
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
        .task {
          enforceSingleScene()
        }
        .onOpenURL { url in
          enforceSingleScene()
          handleOpenURL(url)
        }
    }
    .handlesExternalEvents(matching: ["*"])
  }

  // 重複URL処理防止（iPadの複数シーン対策）
  private static var lastProcessedURL: URL?
  private static var lastProcessedURLTime: Date?

  // MARK: - 共有ファイルキュー（複数ファイル順次処理用）

  /// 共有ファイルのキューエントリ（テキスト読み込み済み）
  private struct SharedFileEntry {
    let text: String?   // nil = 読み込み失敗
    let filename: String
    let silent: Bool
  }

  /// 処理待ちキュー（onOpenURLが複数回呼ばれた分をまとめる）
  private static var pendingSharedQueue: [SharedFileEntry] = []
  /// デバウンス用ワークアイテム
  private static var queueFlushWorkItem: DispatchWorkItem?

  // 開かれたURLを確認して処理（Document Types経由）
  private func handleOpenURL(_ url: URL) {
    print("Opened via URL: \(url)")

    // ショートカットコールバックの処理
    if url.scheme == "mochilog" {
      handleShortcutCallback(url)
      return
    }

    // 5秒以内の同じURL処理をスキップ
    let now = Date()
    if let lastURL = MochiLogApp.lastProcessedURL,
      let lastTime = MochiLogApp.lastProcessedURLTime,
      lastURL == url,
      now.timeIntervalSince(lastTime) < 5.0
    {
      print("[MochiLogApp] Skipping duplicate URL (within 5 seconds)")
      return
    }
    MochiLogApp.lastProcessedURL = url
    MochiLogApp.lastProcessedURLTime = now

    guard url.isFileURL else { return }

    // ファイルへのアクセス権を要求（共有シートからのファイルはInboxにコピーされる）
    let secure = url.startAccessingSecurityScopedResource()
    defer {
      if secure { url.stopAccessingSecurityScopedResource() }
      // 処理後にInboxのファイルを削除
      cleanupInboxFile(url)
    }

    // 複数エンコーディングを順番に試してテキストを読み込む
    var text: String? = nil
    if let s = try? String(contentsOf: url, encoding: .utf8) { text = s }
    if text == nil, let s = try? String(contentsOf: url, encoding: .utf16) { text = s }
    if text == nil, let s = try? String(contentsOf: url, encoding: .isoLatin1) { text = s }
    if text == nil, let data = try? Data(contentsOf: url),
      let s = String(data: data, encoding: .shiftJIS) { text = s }
    if text == nil, let s = try? String(contentsOf: url) { text = s }

    // 読み込み結果をキューに追加してデバウンス送信
    let silent = !AppSettings.shared.openAppAfterShareImport
    enqueueAndFlush(
      entry: SharedFileEntry(text: text, filename: url.lastPathComponent, silent: silent)
    )
  }

  /// 共有ファイルをキューに追加し、0.5秒デバウンス後にまとめて通知する
  /// ※ onOpenURL は常にメインスレッドで呼ばれるため、ロック不要
  private func enqueueAndFlush(entry: SharedFileEntry) {
    MochiLogApp.pendingSharedQueue.append(entry)
    print("[MochiLogApp] キューに追加: \(entry.filename) (合計\(MochiLogApp.pendingSharedQueue.count)件)")

    // 既存のタイマーをキャンセルして再スケジュール（デバウンス）
    MochiLogApp.queueFlushWorkItem?.cancel()
    let workItem = DispatchWorkItem {
      let queue = MochiLogApp.pendingSharedQueue
      MochiLogApp.pendingSharedQueue = []
      MochiLogApp.queueFlushWorkItem = nil

      guard !queue.isEmpty else { return }
      print("[MochiLogApp] \(queue.count)件をまとめて送信")

      // [[String: Any]] に変換してNotificationで送信
      let entries: [[String: Any]] = queue.map { entry in
        var dict: [String: Any] = [
          "filename": entry.filename,
          "silent": entry.silent,
        ]
        if let text = entry.text {
          dict["text"] = text
        }
        return dict
      }

      NotificationCenter.default.post(
        name: NSNotification.Name("ProcessSharedLogQueue"),
        object: nil,
        userInfo: ["entries": entries]
      )
    }
    MochiLogApp.queueFlushWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
  }

  // iPadで複数シーンが生成される場合に、先頭の1つだけ残して閉じる
  private func enforceSingleScene() {
    let scenes = UIApplication.shared.connectedScenes
    guard scenes.count > 1 else { return }

    for scene in scenes.dropFirst() {
      UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
    }
  }

  // Inboxフォルダにコピーされたファイルを削除
  private func cleanupInboxFile(_ url: URL) {
    // Inboxフォルダ内のファイルかどうかをチェック
    if url.path.contains("/Inbox/") {
      try? FileManager.default.removeItem(at: url)
    }
  }

  // ショートカットコールバックの処理
  private func handleShortcutCallback(_ url: URL) {
    switch url.host {
    case "shortcut-success":
      // 注: 現在はx-successコールバックを使用していないため、このケースは呼ばれない
      // ショートカット成功時はアプリに戻らず、解析データ画面に留まるようにするため
      print("✅ ショートカット実行成功")
      DispatchQueue.main.async {
        AppSettings.shared.isShortcutInstalled = true
      }

    case "shortcut-error":
      print("❌ ショートカットが存在しないか、エラー発生")
      DispatchQueue.main.async {
        AppSettings.shared.isShortcutInstalled = false
        // エラー通知を送信
        NotificationCenter.default.post(
          name: NSNotification.Name("ShortcutNotFound"), object: nil)
      }

    case "setup-complete":
      print("✅ ショートカットセットアップ完了")
      DispatchQueue.main.async {
        AppSettings.shared.isShortcutInstalled = true
        // セットアップ完了通知を送信
        NotificationCenter.default.post(
          name: NSNotification.Name("ShortcutSetupComplete"), object: nil)
      }

    default:
      break
    }
  }
}

/// アプリのルートビュー。iCloud設定に応じてDataStoreを動的に切り替える責務を持つ。
struct MochiLogRootView: View {
  private let appSettings = AppSettings.shared
  @StateObject private var dataStore: DataStore
  @State private var viewID = UUID()
  @State private var isReloading = false

  init() {
    let store = DataStore.create(iCloudEnabled: AppSettings.shared.iCloudSyncEnabled)
    _dataStore = StateObject(wrappedValue: store)
  }

  var body: some View {
    ZStack {
      // メインコンテンツ
      MainTabView()
        .environmentObject(dataStore)
        .id(viewID)
        .allowsHitTesting(!isReloading)  // リロード中は操作無効（見た目は変えない）
        .blur(radius: isReloading ? 1.5 : 0)  // 少しぼかす
        .animation(.easeInOut(duration: 0.5), value: isReloading)  // ぼかしのアニメーション
        .task {
          // アプリ起動時にマイグレーションを実行
          dataStore.runMigrations()
        }

      // ローディングオーバーレイ
      // 再読込時のみ出る。
      if isReloading {
        ZStack {
          // 背景が消えても違和感がないように、ベースカラーを敷く
          Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()

          // すりガラス効果
          Rectangle()
            .fill(.ultraThinMaterial)
            .ignoresSafeArea()

          VStack(spacing: 24) {
            ProgressView()
              .controlSize(.large)
              .scaleEffect(1.2)

            Text(String(localized: "applying_settings", table: "Settings"))
              .font(.headline)
              .foregroundStyle(.secondary)
          }
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
      }
    }
    .onReceive(appSettings.$iCloudSyncEnabled.removeDuplicates().dropFirst()) { _ in
      print("iCloud設定変更検知 - RootView再構築開始")
      // タブインデックスを保存してリロード後に復元
      let currentTabIndex = appSettings.selectedTabIndex
      withAnimation(.easeInOut(duration: 0.2)) {
        isReloading = true
      }
      reloadDataStore(delay: 0.1, preserveTabIndex: currentTabIndex)
    }
  }

  private func reloadDataStore(delay: Double = 0.1, preserveTabIndex: Int? = nil) {
    // 遅延実行
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {

      // ある程度待機してから新しいストアを作成・適用
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        let isEnabled = appSettings.iCloudSyncEnabled
        print("DataStore再生成開始: iCloud \(isEnabled ? "有効" : "無効")")

        // 注: iOS 17+ ではストア再生成、iOS 16 では iCloud 未サポートなので影響なし
        // DataStore は @StateObject なので直接差し替えは不可
        // 代わりにリフレッシュで対応
        dataStore.refreshRecords()
        self.viewID = UUID()
        print("DataStore再生成完了: ID \(self.viewID)")

        // タブインデックスを復元
        if let tabIndex = preserveTabIndex {
          appSettings.selectedTabIndex = tabIndex
        }

        // 完了したら、文字が読める程度の時間を確保してから消す
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          withAnimation(.easeInOut(duration: 0.5)) {
            self.isReloading = false
          }
        }
      }
    }
  }
}
