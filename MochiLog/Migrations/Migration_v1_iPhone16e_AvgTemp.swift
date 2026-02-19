import Foundation
import SwiftData

/// v1マイグレーション: iPhone 16eの容量修正とavgTemp修正
@available(iOS 17, *)
struct Migration_v1_iPhone16e_AvgTemp: Migration {
  static let version = "v1_iPhone16e_AvgTemp"
  static let description = "iPhone 16eの設計容量を4005mAhに修正、avgTempを10倍に修正（バージョン2.0.0以下からのアップデート時のみ）"

  static func migrate(modelContext: ModelContext) throws {
    print("[Migration \(version)] Starting migration: \(description)")

    // アプリのバージョンを取得（AppSettings経由で統一）
    let currentVersion = AppSettings.currentAppVersion
    let previousVersion = UserDefaults.standard.string(forKey: AppSettings.Keys.lastSeenVersion)

    print(
      "[Migration \(version)] Previous version: \(previousVersion ?? "none"), Current version: \(currentVersion ?? "unknown")"
    )

    // 現在のバージョンをUserDefaultsに保存（次回起動時のため）
    if let currentVersion = currentVersion {
      UserDefaults.standard.set(currentVersion, forKey: AppSettings.Keys.lastSeenVersion)
    }

    // 全てのBatteryRecordを取得（SwiftDataモデル）
    let descriptor = FetchDescriptor<CurrentBatterySchema.BatteryRecord>()
    let allRecords = try modelContext.fetch(descriptor)

    var fixedAvgTempCount = 0
    var fixediPhone16eCount = 0

    for record in allRecords {
      var needsSave = false

      // 1. avgTempの修正（バージョン2.0.0以下からのアップデート時のみ）
      if shouldRunAvgTempMigration(from: previousVersion, to: currentVersion) {
        if let avgTemp = record.avgTemp, avgTemp < 10.0 {
          record.avgTemp = avgTemp * 10.0
          fixedAvgTempCount += 1
          needsSave = true
          print(
            "[Migration \(version)] Fixed avgTemp for \(record.deviceName) on \(record.logDate): \(avgTemp)°C → \(avgTemp * 10.0)°C"
          )
        }
      }

      // 2. iPhone 16eの設計容量修正（常に実行）
      if record.deviceName == "iPhone 16e", record.designCapacity == 3961 {
        record.designCapacity = 4005
        fixediPhone16eCount += 1
        needsSave = true
        print(
          "[Migration \(version)] Fixed designCapacity for iPhone 16e on \(record.logDate): 3961 → 4005 mAh"
        )
      }

      if needsSave {
        try modelContext.save()
      }
    }

    print(
      "[Migration \(version)] Completed. Fixed \(fixedAvgTempCount) avgTemp records and \(fixediPhone16eCount) iPhone 16e records."
    )
  }

  // MARK: - Private Helper Methods

  /// avgTempマイグレーションを実行すべきか判定
  /// - Parameters:
  ///   - previousVersion: 以前のバージョン
  ///   - currentVersion: 現在のバージョン
  /// - Returns: マイグレーションを実行すべき場合true
  private static func shouldRunAvgTempMigration(
    from previousVersion: String?, to currentVersion: String?
  ) -> Bool {
    // 以前のバージョンが記録されていない場合（2.0.0以前からのアップデート）
    // マイグレーション機能は2.0.1で初めて導入されたため、記録がない = 2.0.0以前
    guard let previousVersion = previousVersion else {
      print(
        "[Migration \(version)] No previous version found (upgrading from ≤2.0.0), running avgTemp migration"
      )
      return true
    }

    // 以前のバージョンが2.0.0以下かチェック
    let isFromOldVersion = compareVersion(previousVersion, lessThanOrEqual: "2.0.0")

    if isFromOldVersion {
      print(
        "[Migration \(version)] Upgrading from version \(previousVersion) (≤2.0.0), running avgTemp migration"
      )
    } else {
      print(
        "[Migration \(version)] Upgrading from version \(previousVersion) (>2.0.0), skipping avgTemp migration"
      )
    }

    return isFromOldVersion
  }

  /// バージョン文字列を比較（簡易版）
  /// - Parameters:
  ///   - version1: 比較するバージョン1
  ///   - version2: 比較するバージョン2
  /// - Returns: version1 <= version2の場合true
  private static func compareVersion(_ version1: String, lessThanOrEqual version2: String) -> Bool {
    let v1Components = version1.split(separator: ".").compactMap { Int($0) }
    let v2Components = version2.split(separator: ".").compactMap { Int($0) }

    for i in 0..<max(v1Components.count, v2Components.count) {
      let v1Value = i < v1Components.count ? v1Components[i] : 0
      let v2Value = i < v2Components.count ? v2Components[i] : 0

      if v1Value < v2Value {
        return true
      } else if v1Value > v2Value {
        return false
      }
    }

    return true  // 等しい場合もtrue
  }
}
