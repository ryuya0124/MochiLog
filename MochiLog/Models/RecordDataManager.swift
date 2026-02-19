import Foundation

/// レコードデータを一元管理し、複数のビュー間でデータを共有するマネージャー
/// タブ切り替え時のパフォーマンス向上のため、@Queryを一箇所に集約
/// 注: DataStoreに置き換え済み。互換性のため残存。
@available(iOS 17, *)
@Observable
class RecordDataManager {
  /// シングルトンインスタンス
  static let shared = RecordDataManager()

  /// キャッシュされたレコード（降順：最新が先頭）
  private(set) var recordsDescending: [BatteryRecord] = []

  /// キャッシュされたレコード（昇順：古いものが先頭）
  private(set) var recordsAscending: [BatteryRecord] = []

  /// デバイス名リスト（ソート済み、計算結果をキャッシュ）
  private(set) var deviceNames: [String] = []

  /// 最後に更新したレコードのハッシュ値（不要な更新を防止）
  private var lastRecordsHash: Int?

  private init() {}

  /// レコードを更新（降順で受け取る想定）
  func updateRecords(_ newRecords: [BatteryRecord]) {
    let startTime = CFAbsoluteTimeGetCurrent()

    // より軽量なハッシュ計算（先頭と末尾の5件のみサンプリング）
    var hasher = Hasher()
    hasher.combine(newRecords.count)

    let sampleSize = min(5, newRecords.count)
    for i in 0..<sampleSize {
      let record = newRecords[i]
      hasher.combine(record.logDate)
      hasher.combine(record.deviceName)
    }
    if newRecords.count > sampleSize {
      for i in (newRecords.count - sampleSize)..<newRecords.count {
        let record = newRecords[i]
        hasher.combine(record.logDate)
        hasher.combine(record.deviceName)
      }
    }

    let newHash = hasher.finalize()

    // 変更がなければスキップ
    if newHash == lastRecordsHash {
      print("[Performance] RecordDataManager.updateRecordsスキップ（データ未変更）")
      return
    }

    print("[Performance] RecordDataManager.updateRecords開始（\(newRecords.count)件）")

    recordsDescending = newRecords
    recordsAscending = newRecords.reversed()

    // デバイス名リストを更新（Set経由で重複削除）
    deviceNames = Array(Set(newRecords.map { $0.deviceName })).sorted()

    lastRecordsHash = newHash

    let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
    print("[Performance] RecordDataManager.updateRecords完了: \(String(format: "%.2f", elapsed))ms")
  }

  /// レコード数を取得
  var count: Int {
    recordsDescending.count
  }

  /// レコードが空かどうか
  var isEmpty: Bool {
    recordsDescending.isEmpty
  }
}
