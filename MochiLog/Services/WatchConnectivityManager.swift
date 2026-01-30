import Combine
import Foundation
import SwiftData
import WatchConnectivity

/// iPhoneからApple Watchへデータを送信するためのWatch Connectivity Manager
/// シングルトンパターンで実装し、アプリ全体から利用可能
final class WatchConnectivityManager: NSObject, ObservableObject {
  // MARK: - シングルトン

  static let shared = WatchConnectivityManager()

  // MARK: - Published プロパティ

  /// Watchアプリが到達可能かどうか
  @Published private(set) var isReachable = false

  /// Watchアプリがインストールされているかどうか
  @Published private(set) var isWatchAppInstalled = false

  /// 最後の同期日時
  @Published private(set) var lastSyncDate: Date?

  // MARK: - プライベートプロパティ

  private var session: WCSession?

  // MARK: - 初期化

  private override init() {
    super.init()
  }

  // MARK: - セッション管理

  /// Watch Connectivityセッションを開始
  func startSession() {
    guard WCSession.isSupported() else {
      print("[WatchConnectivity] WCSessionはこのデバイスでサポートされていません")
      return
    }

    session = WCSession.default
    session?.delegate = self
    session?.activate()
    print("[WatchConnectivity] セッションをアクティベート中...")
  }

  /// バッテリーレコードをApple Watchに送信
  /// - Parameters:
  ///   - records: 送信するBatteryRecordの配列
  ///   - isSampleMode: サンプルモードかどうか
  func sendRecordsToWatch(_ records: [BatteryRecord], isSampleMode: Bool = false) {
    guard let session = session, session.activationState == .activated else {
      print("[WatchConnectivity] セッションがアクティブではありません")
      return
    }

    guard session.isWatchAppInstalled else {
      print("[WatchConnectivity] Watchアプリがインストールされていません")
      return
    }

    // BatteryRecordを軽量なWatchBatteryRecordに変換
    let watchRecords = records.map { WatchBatteryRecord(from: $0) }

    // Codableデータをシリアライズ
    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(watchRecords)

      // Application Contextとして送信（最新の状態を保持）
      let context: [String: Any] = [
        "records": data,
        "syncDate": Date().timeIntervalSince1970,
        "isSampleMode": isSampleMode,
      ]

      try session.updateApplicationContext(context)
      lastSyncDate = Date()
      print(
        "[WatchConnectivity] \(watchRecords.count)件のレコードをWatchに送信しました（サンプルモード: \(isSampleMode)）")
    } catch {
      print("[WatchConnectivity] データのエンコードまたは送信に失敗: \(error)")
    }
  }

  /// 即座にデータを送信（Watchが到達可能な場合のみ）
  /// - Parameter records: 送信するBatteryRecordの配列
  func sendRecordsImmediately(_ records: [BatteryRecord]) {
    guard let session = session,
      session.activationState == .activated,
      session.isReachable
    else {
      // 到達不可能な場合はApplication Contextにフォールバック
      sendRecordsToWatch(records)
      return
    }

    let watchRecords = records.map { WatchBatteryRecord(from: $0) }

    do {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(watchRecords)

      let message: [String: Any] = [
        "records": data,
        "syncDate": Date().timeIntervalSince1970,
      ]

      session.sendMessage(
        message,
        replyHandler: { reply in
          Task { @MainActor in
            self.lastSyncDate = Date()
            print("[WatchConnectivity] Watchからの応答を受信: \(reply)")
          }
        },
        errorHandler: { error in
          print("[WatchConnectivity] メッセージ送信エラー: \(error)")
          // エラー時はApplication Contextにフォールバック
          Task { @MainActor in
            self.sendRecordsToWatch(records)
          }
        })
    } catch {
      print("[WatchConnectivity] データのエンコードに失敗: \(error)")
    }
  }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    Task { @MainActor in
      if let error = error {
        print("[WatchConnectivity] アクティベーション失敗: \(error)")
        return
      }

      switch activationState {
      case .activated:
        print("[WatchConnectivity] セッションがアクティベートされました")
        isWatchAppInstalled = session.isWatchAppInstalled
        isReachable = session.isReachable
      case .inactive:
        print("[WatchConnectivity] セッションが非アクティブです")
      case .notActivated:
        print("[WatchConnectivity] セッションがアクティベートされていません")
      @unknown default:
        break
      }
    }
  }

  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
    print("[WatchConnectivity] セッションが非アクティブになりました")
  }

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    print("[WatchConnectivity] セッションが非アクティブ化されました")
    // 再アクティベート
    Task { @MainActor in
      self.session?.activate()
    }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in
      isReachable = session.isReachable
      print("[WatchConnectivity] 到達可能性が変更されました: \(session.isReachable)")
    }
  }

  nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
    Task { @MainActor in
      isWatchAppInstalled = session.isWatchAppInstalled
      print("[WatchConnectivity] Watchアプリのインストール状態が変更されました: \(session.isWatchAppInstalled)")
    }
  }

  /// Watchからメッセージを受信（返信ハンドラー付き）
  nonisolated func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    print("[WatchConnectivity] Watch側からメッセージを受信しました")

    // 同期リクエストの場合、Application Contextを返す
    if message["request"] as? String == "syncRecords" {
      Task { @MainActor in
        // 現在のApplication Contextを返す
        let context = session.applicationContext
        if !context.isEmpty {
          print("[WatchConnectivity] Application Contextを返信します")
          replyHandler(context)
        } else {
          print("[WatchConnectivity] Application Contextが空です")
          replyHandler(["error": "No data available"])
        }
      }
    } else {
      replyHandler(["status": "ok"])
    }
  }
}
