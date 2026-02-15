import Foundation
import SwiftData
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
  ///   - modelContext: SwiftDataのモデルコンテキスト
  ///   - existingRecords: 既存のレコード（重複チェック用）
  ///   - allowDuplicates: 重複を許可するかどうか
  /// - Returns: インポート結果
  /// - Throws: ImportError
  static func importFromYAML(
    url: URL,
    modelContext: ModelContext,
    existingRecords: [BatteryRecord],
    allowDuplicates: Bool
  ) throws -> ImportResult {
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
    var importedCount = 0
    var skippedCount = 0
    var errors: [String] = []

    for exportRecord in exportData.records {
      do {
        let batteryRecord = try convertToBatteryRecord(exportRecord)

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
        modelContext.insert(batteryRecord)
        importedCount += 1

      } catch {
        errors.append("Failed to import record: \(error.localizedDescription)")
      }
    }

    // 保存
    if importedCount > 0 {
      try? modelContext.save()
    }

    return ImportResult(
      totalRecords: exportData.records.count,
      importedRecords: importedCount,
      skippedDuplicates: skippedCount,
      errors: errors
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
    // } else if version == "2.0" {
    //   // バージョン2.0からのマイグレーション処理
    // }
  }
}
