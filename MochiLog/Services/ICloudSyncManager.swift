import CloudKit
import CoreData
import Foundation
import Combine

/// 競合（コンフリクト）した個々のレコード情報を保持するモデル
struct SyncConflictItem: Identifiable {
  let id = UUID()
  let recordID: UUID
  let localSnapshot: [String: Any]
  let serverSnapshot: [String: Any]

  // UI表示用のヘルパープロパティ
  var localDate: Date? { localSnapshot["logDate"] as? Date }
  var serverDate: Date? { serverSnapshot["logDate"] as? Date }
  var localDevice: String { (localSnapshot["deviceName"] as? String) ?? "Unknown" }
  var serverDevice: String { (serverSnapshot["deviceName"] as? String) ?? "Unknown" }

  var localCycleCount: Int? { localSnapshot["cycleCount"] as? Int }
  var serverCycleCount: Int? { serverSnapshot["cycleCount"] as? Int }
  
  var localDesignCapacity: Int? { localSnapshot["designCapacity"] as? Int }
  var serverDesignCapacity: Int? { serverSnapshot["designCapacity"] as? Int }
  
  var localNominalCapacity: Int? { localSnapshot["nominalCapacity"] as? Int }
  var serverNominalCapacity: Int? { serverSnapshot["nominalCapacity"] as? Int }
  
  var localSettingsDisplayPercent: Int? { localSnapshot["settingsDisplayPercent"] as? Int }
  var serverSettingsDisplayPercent: Int? { serverSnapshot["settingsDisplayPercent"] as? Int }
}

/// コンフリクト解決の選択肢
enum SyncConflictResolution {
  case server
  case local
  case all
}

/// 同期ステータス
enum SyncStatus: Equatable {
  case idle
  case syncing
  case success
  case error(String)
  case notAuthenticated  // CKError.notAuthenticated (code 2)
}

/// iCloud同期のコンフリクト（競合）をメモリ上で管理し、手動解決をサポートするマネージャー
final class ICloudSyncManager: ObservableObject {
  static let shared = ICloudSyncManager()

  /// 現在未解決のコンフリクト一覧
  @Published var unresolvedConflicts: [SyncConflictItem] = []
  
  /// 最近の同期ステータス
  @Published var lastSyncStatus: SyncStatus = .idle

  /// 最後に発生したエラーの詳細ログ（UI表示・コピー用）
  @Published var lastErrorLog: String? = nil

  /// インポート完了時にrefreshを呼ぶDataStore（弱参照）
  private weak var dataStore: DataStore?

  /// DataStoreを登録する（AppDelegate/初期化時に呼ぶ）
  func register(dataStore: DataStore) {
    self.dataStore = dataStore
  }

  private init() {
    // NSPersistentCloudKitContainerの同期イベントを監視する
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleCloudKitEventChanged(_:)),
      name: NSPersistentCloudKitContainer.eventChangedNotification,
      object: nil
    )
  }
  
  @objc
  private func handleCloudKitEventChanged(_ notification: Notification) {
    guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else {
      return
    }

    DispatchQueue.main.async {
      if event.endDate == nil {
        // イベント終了日時がない場合は同期中
        self.lastSyncStatus = .syncing
      } else {
        if let error = event.error {
          // 詳細ログ出力
          self.logCloudKitError(error, eventType: event.type)

          // CKError.notAuthenticated (rawValue=9) を個別ハンドリング
          // ※ CKErrorDomain code 2 は partialFailure であり notAuthenticated ではない
          if let ckError = self.extractCKError(error), ckError.code == .notAuthenticated {
            print("[ICloudSync] ⚠️ notAuthenticated (CKError rawValue=9): iCloudにサインインしていないか、iCloud Driveが無効です")
            self.lastSyncStatus = .notAuthenticated
            // アカウント状態を非同期で確認してログに追記
            Task {
              await self.logAccountStatus()
            }
          } else {
            let friendlyMessage = self.friendlyErrorMessage(error)
            self.lastSyncStatus = .error(friendlyMessage)
          }
        } else {
          self.lastSyncStatus = .success
          AppSettings.shared.lastICloudSyncDate = Date().timeIntervalSince1970

          // インポートイベント完了時（他デバイスからデータを受信した場合）は
          // ローカルコンテキストを最新状態に更新してUIに反映する
          if event.type == .import {
            self.dataStore?.refreshRecords()
          }
        }
      }
    }
  }

  // MARK: - エラー解析ヘルパー

  /// NSErrorの中からCKErrorを掘り起こす（ネストされている場合も対応）
  private func extractCKError(_ error: Error) -> CKError? {
    if let ck = error as? CKError {
      return ck
    }
    let ns = error as NSError
    // underlyingErrorsに格納されている場合
    if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
      return extractCKError(underlying)
    }
    return nil
  }

  /// CloudKit/CoreDataエラーの詳細をログ出力し、UI表示用の文字列として返す
  @discardableResult
  private func logCloudKitError(_ error: Error, eventType: NSPersistentCloudKitContainer.EventType) -> String {
    let ns = error as NSError
    let typeLabel: String
    switch eventType {
    case .setup:  typeLabel = "setup"
    case .import: typeLabel = "import"
    case .export: typeLabel = "export"
    @unknown default: typeLabel = "unknown"
    }

    // ログ行を配列に積んでまとめて出力・保存する
    var lines: [String] = []
    lines.append("❌ CloudKitエラー (eventType=\(typeLabel))")
    lines.append("   domain=\(ns.domain), code=\(ns.code)")
    lines.append("   \(ns.localizedDescription)")

    // CKError情報を展開
    if let ckError = extractCKError(error) {
      lines.append("   CKError.code=\(ckError.code.rawValue) (\(ckError.code))")
      if let retryAfter = ckError.retryAfterSeconds {
        lines.append("   retryAfter=\(Int(retryAfter))秒")
      }
      if let serverRecord = ckError.serverRecord {
        lines.append("   serverRecord=\(serverRecord)")
      }
      // partialFailure (rawValue=2) の場合はサブエラーを個別に展開
      if ckError.code == .partialFailure,
         let partialErrors = ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] {
        lines.append("   partialFailure: \(partialErrors.count)件のサブエラー")
        for (itemID, subError) in partialErrors {
          let sub = subError as NSError
          lines.append("     - itemID=\(itemID): \(sub.domain) \(sub.code) — \(sub.localizedDescription)")
        }
      }
    }

    // userInfo全体をダンプ（NSError層）
    if !ns.userInfo.isEmpty {
      lines.append("   userInfo:")
      for (key, value) in ns.userInfo {
        if key == NSUnderlyingErrorKey, let underlyingError = value as? Error {
          let ue = underlyingError as NSError
          lines.append("     NSUnderlyingError: \(ue.domain) \(ue.code) — \(ue.localizedDescription)")
          for (k2, v2) in ue.userInfo {
            lines.append("       [\(k2)]: \(v2)")
          }
        } else if key == CKPartialErrorsByItemIDKey {
          lines.append("     [CKPartialErrorsByItemIDKey]: (上記参照)")
        } else {
          lines.append("     [\(key)]: \(value)")
        }
      }
    }

    let logText = lines.joined(separator: "\n")

    // Xcodeコンソールへも出力
    for line in lines {
      print("[ICloudSync] \(line)")
    }

    // UI表示用に保存（日時付き）
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
    lastErrorLog = "[\(timestamp)]\n" + logText

    return logText
  }

  /// CKErrorコードに応じた日本語エラーメッセージを返す
  private func friendlyErrorMessage(_ error: Error) -> String {
    if let ckError = extractCKError(error) {
      switch ckError.code {
      case .partialFailure:
        // rawValue=2。一部レコードの保存/取得に失敗。ログを見て個別エラーを確認する
        let count = (ckError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error])?.count ?? 0
        return "一部データの同期に失敗しました（\(count)件）(CKError \(ckError.code.rawValue))"
      case .networkUnavailable, .networkFailure:
        return "ネットワークに接続できません (CKError \(ckError.code.rawValue))"
      case .serviceUnavailable:
        return "iCloudサービスが一時的に利用できません (CKError \(ckError.code.rawValue))"
      case .requestRateLimited:
        let wait = ckError.retryAfterSeconds.map { "(\(Int($0))秒後にリトライ)" } ?? ""
        return "リクエスト制限中です \(wait) (CKError \(ckError.code.rawValue))"
      case .quotaExceeded:
        return "iCloudの空き容量が不足しています (CKError \(ckError.code.rawValue))"
      case .zoneNotFound, .unknownItem:
        return "CloudKitのゾーンが見つかりません。iCloud同期をいったんオフにして再度オンにしてください (CKError \(ckError.code.rawValue))"
      case .serverRecordChanged:
        return "別デバイスとの競合が発生しました (CKError \(ckError.code.rawValue))"
      case .notAuthenticated:
        // rawValue=9
        return "iCloudにサインインしていないか認証エラーが発生しました (CKError \(ckError.code.rawValue))"
      default:
        let ns = error as NSError
        return "\(ns.localizedDescription) (\(ns.domain) \(ns.code))"
      }
    }
    let ns = error as NSError
    return "\(ns.localizedDescription) (\(ns.domain) \(ns.code))"
  }

  /// CKContainerのアカウント状態を非同期で取得してログ出力
  private func logAccountStatus() async {
    do {
      let status = try await CKContainer.default().accountStatus()
      let label: String
      switch status {
      case .available:        label = "available（正常）"
      case .noAccount:        label = "noAccount（アカウントなし）"
      case .restricted:       label = "restricted（制限あり）"
      case .couldNotDetermine: label = "couldNotDetermine（不明）"
      case .temporarilyUnavailable: label = "temporarilyUnavailable（一時的に利用不可）"
      @unknown default:       label = "unknown"
      }
      print("[ICloudSync] ℹ️ CKContainer.accountStatus = \(label)")
    } catch {
      print("[ICloudSync] ⚠️ accountStatus取得失敗: \(error)")
    }
  }

  /// SwiftData/CoreDataの保存エラーから競合を抽出し、管理リストに追加する
  @MainActor
  func handleSaveError(_ error: Error) {
    let nsError = error as NSError
    // NSManagedObjectMergeError
    if nsError.domain == NSCocoaErrorDomain, nsError.code == NSManagedObjectMergeError {
      if let mergeConflicts = nsError.userInfo["conflictList"] as? [NSMergeConflict] {
        for conflict in mergeConflicts {
          // コンフリクトしたオブジェクトから必要なデータを抽出
          let sourceObject = conflict.sourceObject
          guard let recordID = sourceObject.value(forKey: "recordID") as? UUID else { continue }

          let localSnap = conflict.objectSnapshot ?? [:]
          let serverSnap = conflict.cachedSnapshot ?? [:]

          let item = SyncConflictItem(
            recordID: recordID,
            localSnapshot: localSnap,
            serverSnapshot: serverSnap
          )

          // 既に同じrecordIDのコンフリクトがあれば追加しない
          if !unresolvedConflicts.contains(where: { $0.recordID == recordID }) {
            unresolvedConflicts.append(item)
          }
        }
      }
    }
  }

  /// 指定したコンフリクトをリストから削除する
  @MainActor
  func removeConflict(id: UUID) {
    unresolvedConflicts.removeAll { $0.id == id }
  }

  /// 全てのコンフリクトをクリアする
  @MainActor
  func clearConflicts() {
    unresolvedConflicts.removeAll()
  }

  /// コンフリクトを解決する
  @MainActor
  func resolveConflict(_ conflict: SyncConflictItem, resolution: SyncConflictResolution, dataStore: DataStore) {
    switch resolution {
    case .server:
      // サーバーを優先する場合、ローカルの変更はすでにrollbackされているので、何もしない（リストから削除のみ）
      break

    case .local:
      // ローカルを優先する場合、ローカルのスナップショットからレコードを作成し、既存のレコードを上書き（削除＋挿入）する
      if let record = parseSnapshot(conflict.localSnapshot, recordID: conflict.recordID) {
        // 既存のレコードを削除して再挿入する
        let existing = dataStore.fetchRecords(for: record.deviceName).first { $0.id == conflict.recordID }
        if let existing = existing {
          dataStore.delete(existing)
        }
        dataStore.insert(record)
        dataStore.save()
      }

    case .all:
      // 全てを残す場合、サーバーデータはそのまま維持し、ローカルデータを新しいIDで追加する
      if let record = parseSnapshot(conflict.localSnapshot, recordID: UUID()) { // 新しいUUID
        dataStore.insert(record)
        dataStore.save()
      }
    }
    removeConflict(id: conflict.id)
  }

  /// スナップショット辞書から BatteryRecord を生成するヘルパー
  private func parseSnapshot(_ dict: [String: Any], recordID: UUID) -> BatteryRecord? {
    guard let logDate = dict["logDate"] as? Date,
          let deviceName = dict["deviceName"] as? String else {
      return nil
    }

    return BatteryRecord(
      id: recordID,
      logDate: logDate,
      deviceName: deviceName,
      deviceModelCode: dict["deviceModelCode"] as? String,
      osVersion: dict["osVersion"] as? String,
      storage: dict["storage"] as? String,
      ram: dict["ram"] as? String,
      manufactureDate: dict["manufactureDate"] as? String,
      firstUseDate: dict["firstUseDate"] as? Date,
      cycleCount: (dict["cycleCount"] as? Int) ?? 0,
      designCapacity: (dict["designCapacity"] as? Int) ?? 0,
      nominalCapacity: (dict["nominalCapacity"] as? Int) ?? 0,
      rawCapacity: (dict["rawCapacity"] as? Int) ?? 0,
      lowRateCapacity: dict["lowRateCapacity"] as? Int,
      deflator: dict["deflator"] as? Double,
      settingsDisplayPercent: dict["settingsDisplayPercent"] as? Int,
      diagnosticResult: dict["diagnosticResult"] as? String,
      avgTemp: dict["avgTemp"] as? Double,
      maxTemp: dict["maxTemp"] as? Double,
      minTemp: dict["minTemp"] as? Double,
      maxVoltage: dict["maxVoltage"] as? Double,
      minVoltage: dict["minVoltage"] as? Double,
      minSoC: dict["minSoC"] as? Int,
      maxSoC: dict["maxSoC"] as? Int
    )
  }

  /// テスト用: ダミーのコンフリクトを生成してリストに追加する
  @MainActor
  func simulateConflict() {
    let dummyRecordID = UUID()
    let localSnap: [String: Any] = [
      "logDate": Date(),
      "deviceName": "Test Device (Local)",
      "cycleCount": 150,
      "designCapacity": 3000,
      "nominalCapacity": 2500,
      "settingsDisplayPercent": 85
    ]
    let serverSnap: [String: Any] = [
      "logDate": Date().addingTimeInterval(-3600),
      "deviceName": "Test Device (Server)",
      "cycleCount": 140,
      "designCapacity": 3000,
      "nominalCapacity": 2600,
      "settingsDisplayPercent": 88
    ]
    
    let item = SyncConflictItem(
      recordID: dummyRecordID,
      localSnapshot: localSnap,
      serverSnapshot: serverSnap
    )
    
    unresolvedConflicts.append(item)
  }
}
