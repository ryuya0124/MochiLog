// HomeView+Utilities.swift
// ユーティリティメソッドをHomeViewから分離
import SwiftData
import SwiftUI
import UIKit  // for UIImage in Bundle extension

// MARK: - Bundle Extension
extension Bundle {
  var icon: UIImage? {
    if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
      let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
      let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
      let lastIcon = iconFiles.last
    {
      return UIImage(named: lastIcon)
    }
    return nil
  }
}

// MARK: - ユーティリティ関数
extension HomeView {
  /// BatteryRecordを作成する
  func createRecord(
    from result: LogParser.ParseResult,
    deviceName: String,
    deviceModelCodeOverride: String? = nil,
    designCapacityOverride: Int? = nil
  ) -> BatteryRecord {
    let logDate = result.logDate ?? Date()
    let modelCodeUsed = deviceModelCodeOverride ?? result.deviceModelCode
    let designCapacityUsed = designCapacityOverride ?? result.designCapacity ?? 0
    let record = BatteryRecord(
      logDate: logDate,
      deviceName: deviceName,
      deviceModelCode: modelCodeUsed,
      osVersion: result.osVersion,
      storage: result.storage,
      ram: result.ram,
      manufactureDate: nil,
      firstUseDate: result.firstUseDate,
      cycleCount: result.cycleCount ?? 0,
      designCapacity: designCapacityUsed,
      nominalCapacity: result.nominalCapacity ?? 0,
      rawCapacity: result.rawCapacity ?? 0,
      lowRateCapacity: result.lowRateCapacity,
      deflator: result.deflator,
      settingsDisplayPercent: result.settingsDisplayPercent,
      diagnosticResult: result.diagnosticResult,
      avgTemp: result.avgTemp,
      maxTemp: result.maxTemp,
      minTemp: result.minTemp,
      maxVoltage: result.maxVoltage,
      minVoltage: result.minVoltage,
      minSoC: result.dailyMinSoC,
      maxSoC: result.dailyMaxSoC
    )

    // If diagnostic result is missing but we have a design capacity, compute it from raw
    if record.diagnosticResult == nil && designCapacityUsed > 0 && record.rawCapacity > 0 {
      let rawRatio = (Double(record.rawCapacity) / Double(designCapacityUsed)) * 100.0
      if rawRatio < 80.0 {
        record.diagnosticResult = String(localized: "diag_replace_recommended", table: "Records")
      } else if rawRatio < 90.0 {
        record.diagnosticResult = String(localized: "diag_slightly_degraded", table: "Records")
      } else {
        record.diagnosticResult = String(localized: "diag_normal", table: "Records")
      }
    }

    return record
  }

  /// レコードを削除する
  func deleteRecords(_ items: [BatteryRecord]) {
    withAnimation(.snappy) {
      for item in items {
        // 選択中のレコードが削除対象なら先に選択を解除
        if let selected = selectedRecord, selected === item {
          selectedRecord = nil
        }
        modelContext.delete(item)
      }
    }
    // 保存はアニメーション外で行う
    Task.detached(priority: .userInitiated) {
      await MainActor.run {
        try? self.modelContext.save()
      }
    }
  }

  /// 詳細画面を表示する（iPadではナビゲーション、iPhoneではシート）
  func showRecordDetail(_ record: BatteryRecord) {
    print(
      "[HomeView] showRecordDetail called, horizontalSizeClass: \(String(describing: horizontalSizeClass))"
    )
    if horizontalSizeClass == .regular {
      print("[HomeView] Setting navigatingRecord (iPad)")
      navigatingRecord = record
    } else {
      print("[HomeView] Setting selectedRecord (iPhone)")
      selectedRecord = record
    }
  }

  /// Apple Watchにレコードを同期する（バックグラウンドで実行）
  func syncRecordsToWatch() {
    let startTime = CFAbsoluteTimeGetCurrent()
    print("[Performance] syncRecordsToWatch開始")

    // バックグラウンドで実行してUIスレッドをブロックしない
    Task.detached(priority: .utility) {
      // サンプルデータ表示中はサンプルデータを送信
      let isSampleMode = await MainActor.run { AppSettings.shared.showingSampleData }
      if isSampleMode {
        let sampleRecords = SampleDataProvider.generateSampleRecords()
        WatchConnectivityManager.shared.sendRecordsToWatch(sampleRecords, isSampleMode: true)
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("[Performance] syncRecordsToWatch完了（サンプルモード）: \(String(format: "%.2f", elapsed))ms")
        return
      }

      // レコードを取得
      let currentRecords = await MainActor.run { self.records }

      // レコードがある場合のみ同期
      guard !currentRecords.isEmpty else {
        // レコードがない場合はサンプルモードをオフにして空で送信
        WatchConnectivityManager.shared.sendRecordsToWatch([], isSampleMode: false)
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("[Performance] syncRecordsToWatch完了（空）: \(String(format: "%.2f", elapsed))ms")
        return
      }

      // 通常モードでデータを送信
      WatchConnectivityManager.shared.sendRecordsToWatch(currentRecords, isSampleMode: false)
      let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
      print(
        "[Performance] syncRecordsToWatch完了（\(currentRecords.count)件）: \(String(format: "%.2f", elapsed))ms"
      )
    }
  }
}

// MARK: - 重複チェック
extension HomeView {
  /// 日付とデバイス名で重複レコードを検索する（日単位）
  func hasDuplicateRecord(on date: Date, deviceName: String) -> Bool {
    records.contains { existing in
      // 日付を「日単位」で比較（時刻は無視）
      let sameDate = Calendar.current.isDate(existing.logDate, inSameDayAs: date)
      guard sameDate else { return false }

      // デバイス名（機種名）で比較
      return existing.deviceName == deviceName
    }
  }

  /// 既存のレコードを検索する
  func findExistingRecord(on date: Date, deviceName: String) -> BatteryRecord? {
    records.first { existing in
      let sameDevice = existing.deviceName == deviceName
      guard sameDevice else { return false }
      return abs(existing.logDate.timeIntervalSince(date)) < 1.0
    }
  }
}

// MARK: - データ整合性
extension HomeView {
  /// 起動時に「Unknown」デバイス名を解決する
  func reconcileUnknownDeviceNames() {
    var needsSave = false
    for record in records {
      guard record.deviceName == "Unknown",
        let code = record.deviceModelCode,
        let resolved = DeviceLibrary.getDeviceName(for: code)
      else {
        continue
      }
      record.deviceName = resolved
      needsSave = true
    }
    if needsSave {
      try? modelContext.save()
    }
  }

  /// 起動時にライブラリに設計容量が登録されていない既存レコードを補完する
  func reconcileMissingDesignCapacities() {
    var needsSave = false
    for record in records {
      // 0 は「未登録・情報なし」を表す (既存のコードとの互換性維持)
      guard record.designCapacity == 0 else { continue }

      // まずは model code から解決を試みる
      if let code = record.deviceModelCode,
        let resolvedName = DeviceLibrary.getDeviceName(for: code),
        let cap = DeviceLibrary.getCapacity(for: resolvedName),
        cap > 0
      {
        record.designCapacity = cap
        // 設計容量が埋まったら診断結果を再計算する
        if record.rawCapacity > 0 {
          let rawRatio = (Double(record.rawCapacity) / Double(cap)) * 100.0
          if rawRatio < 80.0 {
            record.diagnosticResult = String(
              localized: "diag_replace_recommended", table: "Records")
          } else if rawRatio < 90.0 {
            record.diagnosticResult = String(localized: "diag_slightly_degraded", table: "Records")
          } else {
            record.diagnosticResult = String(localized: "diag_normal", table: "Records")
          }
        }
        needsSave = true
        continue
      }

      // 次に deviceName から解決できるか試す
      if let cap = DeviceLibrary.getCapacity(for: record.deviceName), cap > 0 {
        record.designCapacity = cap
        if record.rawCapacity > 0 {
          let rawRatio = (Double(record.rawCapacity) / Double(cap)) * 100.0
          if rawRatio < 80.0 {
            record.diagnosticResult = String(
              localized: "diag_replace_recommended", table: "Records")
          } else if rawRatio < 90.0 {
            record.diagnosticResult = String(localized: "diag_slightly_degraded", table: "Records")
          } else {
            record.diagnosticResult = String(localized: "diag_normal", table: "Records")
          }
        }
        needsSave = true
      }
    }
    if needsSave { try? modelContext.save() }
  }
}
