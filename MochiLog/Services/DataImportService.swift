import Foundation
import Yams

/// YAMLファイルからバッテリーレコードをインポートするサービス
struct DataImportService {

  /// インポートエラー
  enum ImportError: LocalizedError {
    case fileReadError
    case decodeError
    case invalidData
    case noRecords
    case unsupportedFormatVersion(String)

    var errorDescription: String? {
      switch self {
      case .fileReadError:
        return String(localized: "import_file_read_error", table: "Settings")
      case .decodeError:
        return String(localized: "import_decode_error", table: "Settings")
      case .invalidData:
        return String(localized: "import_invalid_data", table: "Settings")
      case .noRecords:
        return String(localized: "import_no_records", table: "Settings")
      case .unsupportedFormatVersion(let version):
        return String(localized: "import_unsupported_version", table: "Settings")
          .replacingOccurrences(of: "{version}", with: version)
      }
    }
  }

  /// インポート結果
  struct ImportResult {
    let totalRecords: Int
    let importedRecords: Int
    let skippedDuplicates: Int
    let errors: [String]

    var hasErrors: Bool {
      !errors.isEmpty
    }

    var successCount: Int {
      importedRecords
    }
  }

  /// YAMLファイルからデータをインポート
  /// - Parameters:
  ///   - url: YAMLファイルのURL
  ///   - dataStore: データストア
  ///   - existingRecords: 既存のレコード（重複チェック用）
  ///   - allowDuplicates: 重複を許可するかどうか
  /// - Returns: インポート結果
  /// - Throws: ImportError
  static func importFromYAML(
    url: URL,
    dataStore: DataStore,
    existingRecords: [BatteryRecord],
    allowDuplicates: Bool
  ) async throws -> ImportResult {
    // ファイルを読み込み
    let yamlString: String
    do {
      yamlString = try String(contentsOf: url, encoding: .utf8)
    } catch {
      throw ImportError.fileReadError
    }

    // YAMLをデコード
    let decoder = YAMLDecoder()
    let exportData: DataExportService.ExportData
    do {
      exportData = try decoder.decode(DataExportService.ExportData.self, from: yamlString)
    } catch {
      print("[DataImportService] YAML decode error: \(error)")
      throw ImportError.decodeError
    }

    // レコードが空でないか確認
    guard !exportData.records.isEmpty else {
      throw ImportError.noRecords
    }

    // バージョンチェック
    try validateFormatVersion(exportData.exportFormatVersion)

    // インポート処理
    let result = await MainActor.run {
      var importedCount = 0
      var skippedCount = 0
      var errors: [String] = []

      for exportRecord in exportData.records {
        do {
          let batteryRecord = try convertToBatteryRecord(exportRecord)

          // 3.0.0より古いデータの場合、iPhone Air MagSafeバッテリーのマイグレーションを実施
          if compareVersion(exportData.appVersion, lessThan: "3.0.0") {
            if batteryRecord.deviceName == "iPhone Air" {
              let isMagSafe = batteryRecord.firstUseDate == nil
                && batteryRecord.deflator == nil
                && (batteryRecord.lowRateCapacity == nil || batteryRecord.lowRateCapacity == 0)
                && batteryRecord.rawCapacity == 0

              if isMagSafe {
                batteryRecord.deviceName = "iPhone Air MagSafeバッテリー"
                batteryRecord.deviceModelCode = "A3385"
              }
            }
          }

          // 重複チェック
          if !allowDuplicates {
            let isDuplicate = existingRecords.contains { existing in
              let sameDate = Calendar.current.isDate(
                existing.logDate, inSameDayAs: batteryRecord.logDate)
              return sameDate && existing.deviceName == batteryRecord.deviceName
            }

            if isDuplicate {
              skippedCount += 1
              continue
            }
          }

          // レコードを追加
          dataStore.insert(batteryRecord)
          importedCount += 1

        } catch {
          errors.append("Failed to import record: \(error.localizedDescription)")
        }
      }

      // 保存
      if importedCount > 0 {
        dataStore.save()
      }

      return (importedCount, skippedCount, errors)
    }

    return ImportResult(
      totalRecords: exportData.records.count,
      importedRecords: result.0,
      skippedDuplicates: result.1,
      errors: result.2
    )
  }

  /// ExportRecordをBatteryRecordに変換
  /// - Parameter exportRecord: エクスポートレコード
  /// - Returns: バッテリーレコード
  /// - Throws: ImportError
  private static func convertToBatteryRecord(_ exportRecord: DataExportService.ExportRecord) throws
    -> BatteryRecord
  {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    // 日付のパース
    guard let logDate = formatter.date(from: exportRecord.logDate) else {
      throw ImportError.invalidData
    }

    let firstUseDate = exportRecord.firstUseDate.flatMap { formatter.date(from: $0) }

    // BatteryRecordを作成
    let record = BatteryRecord(
      logDate: logDate,
      deviceName: exportRecord.deviceName,
      deviceModelCode: exportRecord.deviceModelCode,
      osVersion: exportRecord.osVersion,
      storage: exportRecord.storage,
      ram: exportRecord.ram,
      manufactureDate: exportRecord.manufactureDate,
      firstUseDate: firstUseDate,
      cycleCount: exportRecord.cycleCount,
      designCapacity: exportRecord.designCapacity,
      nominalCapacity: exportRecord.nominalCapacity,
      rawCapacity: exportRecord.rawCapacity,
      lowRateCapacity: exportRecord.lowRateCapacity,
      deflator: exportRecord.deflator,
      settingsDisplayPercent: exportRecord.settingsDisplayPercent,
      diagnosticResult: exportRecord.diagnosticResult,
      avgTemp: exportRecord.avgTemp,
      maxTemp: exportRecord.maxTemp,
      minTemp: exportRecord.minTemp,
      maxVoltage: exportRecord.maxVoltage,
      minVoltage: exportRecord.minVoltage,
      minSoC: exportRecord.minSoC,
      maxSoC: exportRecord.maxSoC
    )

    return record
  }

  /// ファイル形式のバージョンを検証
  /// - Parameter version: ファイルのバージョン文字列
  /// - Throws: ImportError.unsupportedFormatVersion
  private static func validateFormatVersion(_ version: String) throws {
    // サポートされているバージョンのリスト
    let supportedVersions = ["1.0"]

    guard supportedVersions.contains(version) else {
      throw ImportError.unsupportedFormatVersion(version)
    }

    // 将来的に、バージョンごとのマイグレーション処理をここに追加できます
    // 例:
    // if version == "1.0" {
    //   // バージョン1.0からのマイグレーション処理
    // else if version == "2.0" {
    //   // バージョン2.0からのマイグレーション処理
    // }
  }

  /// バージョン文字列を比較する（v1 < v2 なら true）
  private static func compareVersion(_ version: String, lessThan target: String) -> Bool {
    // "unknown" 等の場合は古いとみなすか、ここでは false にするか
    // 確実に 3.0.0 より古いと判定できる場合のみ true にする
    if version == "unknown" { return true }
    
    let v1 = version.split(separator: ".").compactMap { Int($0) }
    let v2 = target.split(separator: ".").compactMap { Int($0) }
    let maxCount = max(v1.count, v2.count)
    for i in 0..<maxCount {
      let a = i < v1.count ? v1[i] : 0
      let b = i < v2.count ? v2[i] : 0
      if a < b { return true }
      if a > b { return false }
    }
    return false // 同じバージョンの場合は false
  }
}
