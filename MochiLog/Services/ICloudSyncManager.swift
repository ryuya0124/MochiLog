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

  /// NSErrorの中からCKErrorを掘り起こす（全階層を再帰探索）
  private func extractCKError(_ error: Error) -> CKError? {
    let ns = error as NSError
    if ns.domain == CKErrorDomain, let ck = error as? CKError {
      return ck
    }
    if ns.domain == CKErrorDomain {
      // Swiftブリッジが効かない場合もNSErrorのままCKErrorとして扱う
      return CKError(_nsError: ns)
    }
    // NSUnderlyingErrorKey を再帰探索
    if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
      return extractCKError(underlying)
    }
    // underlyingErrors（複数）を探索
    if let underlyingErrors = ns.userInfo["NSUnderlyingErrorsKey"] as? [Error] {
      for e in underlyingErrors {
        if let found = extractCKError(e) { return found }
      }
    }
    return nil
  }

  /// CloudKit/CoreDataエラーの全情報をログ出力し、UI表示用の文字列として返す
  @discardableResult
  private func logCloudKitError(_ error: Error, eventType: NSPersistentCloudKitContainer.EventType) -> String {
    let typeLabel: String
    switch eventType {
    case .setup:  typeLabel = "setup"
    case .import: typeLabel = "import"
    case .export: typeLabel = "export"
    @unknown default: typeLabel = "unknown"
    }

    var lines: [String] = []
    lines.append("❌ CloudKitエラー (eventType=\(typeLabel))")
    dumpError(error, into: &lines, indent: "")

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

  /// NSErrorを再帰的にダンプする（partialFailureのサブエラーも完全展開）
  private func dumpError(_ error: Error, into lines: inout [String], indent: String) {
    let ns = error as NSError
    lines.append("\(indent)domain=\(ns.domain), code=\(ns.code)")
    lines.append("\(indent)desc=\(ns.localizedDescription)")

    // CKErrorDomainならコード名も表示
    if ns.domain == CKErrorDomain {
      lines.append("\(indent)CKError: \(ckErrorCodeName(ns.code)) (rawValue=\(ns.code))")
    }

    // userInfoを全て展開
    for (key, value) in ns.userInfo {
      let keyStr = "\(key)"
      switch keyStr {
      case NSUnderlyingErrorKey:
        if let sub = value as? Error {
          lines.append("\(indent)NSUnderlyingError:")
          dumpError(sub, into: &lines, indent: indent + "  ")
        }
      case CKPartialErrorsByItemIDKey:
        if let partial = value as? [AnyHashable: Error] {
          lines.append("\(indent)partialErrors(\(partial.count)件):")
          for (itemID, subErr) in partial {
            lines.append("\(indent)  [itemID=\(itemID)]")
            dumpError(subErr, into: &lines, indent: indent + "    ")
          }
        }
      case "NSUnderlyingErrorsKey":
        if let subs = value as? [Error] {
          lines.append("\(indent)NSUnderlyingErrors(\(subs.count)件):")
          for (i, sub) in subs.enumerated() {
            lines.append("\(indent)  [\(i)]")
            dumpError(sub, into: &lines, indent: indent + "    ")
          }
        }
      case NSLocalizedDescriptionKey, "NSLocalizedFailureReason":
        break // desc と重複するためスキップ
      default:
        lines.append("\(indent)[\(keyStr)]: \(value)")
      }
    }
  }

  /// CKErrorコード番号から名前文字列を返す
  private func ckErrorCodeName(_ code: Int) -> String {
    switch code {
    case 1:  return "internalError"
    case 2:  return "partialFailure"
    case 3:  return "networkUnavailable"
    case 4:  return "networkFailure"
    case 5:  return "badContainer"
    case 6:  return "serviceUnavailable"
    case 7:  return "requestRateLimited"
    case 9:  return "notAuthenticated"
    case 10: return "permissionFailure"
    case 11: return "unknownItem"
    case 12: return "invalidArguments"
    case 14: return "resultsTruncated"
    case 15: return "serverRecordChanged"
    case 16: return "serverRejectedRequest"
    case 17: return "assetFileNotFound"
    case 18: return "assetFileModified"
    case 19: return "incompatibleVersion"
    case 20: return "constraintViolation"
    case 21: return "operationCancelled"
    case 22: return "changeTokenExpired"
    case 23: return "batchRequestFailed"
    case 24: return "zoneBusy"
    case 25: return "badDatabase"
    case 26: return "quotaExceeded"
    case 27: return "zoneNotFound"
    case 28: return "limitExceeded"
    case 29: return "userDeletedZone"
    case 30: return "tooManyParticipants"
    case 31: return "alreadyShared"
    case 32: return "referenceViolation"
    case 33: return "managedAccountRestricted"
    case 34: return "participantMayNeedVerification"
    case 36: return "serverResponseLost"
    case 37: return "assetNotAvailable"
    case 38: return "accountTemporarilyUnavailable"
    default: return "unknown(\(code))"
    }
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

  /// 診断用: CloudKitに直接レコードを保存してみて、詳細なエラーを取得する
  @MainActor
  func runDiagnosticSyncTest() async {
    let container = CKContainer.default()
    let database = container.privateCloudDatabase
    
    // CoreData/SwiftDataが自動生成するレコードタイプ名 (通常は CD_ + エンティティ名)
    // SwiftDataは BatteryRecord、CoreDataは CDBatteryRecord という名前で作られている可能性あり
    let recordType = "CD_BatteryRecord"
    let recordID = CKRecord.ID(recordName: UUID().uuidString)
    let record = CKRecord(recordType: recordType, recordID: recordID)
    
    // CoreData/SwiftDataはフィールド名に CD_ をつける
    record["CD_deviceName"] = "Diagnostic Test"
    record["CD_logDate"] = Date()
    
    do {
      self.lastSyncStatus = .syncing
      _ = try await database.save(record)
      // テスト成功した場合はすぐに消す
      try? await database.deleteRecord(withID: recordID)
      self.lastErrorLog = "診断テスト成功: レコードの保存と削除に成功しました。スキーマやアクセス権に問題はありません。"
      self.lastSyncStatus = .error("診断テスト成功") // UIに表示させるため便宜上errorを使う
    } catch let error as CKError {
      var lines: [String] = []
      lines.append("❌ 診断テスト エラー (CKError)")
      dumpError(error, into: &lines, indent: "")
      let logText = lines.joined(separator: "\n")
      self.lastErrorLog = "[\(Date().formatted())]\n" + logText
      self.lastSyncStatus = .error("診断テスト失敗")
    } catch {
      self.lastErrorLog = "診断テスト エラー: \(error.localizedDescription)"
      self.lastSyncStatus = .error("診断テスト失敗")
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
