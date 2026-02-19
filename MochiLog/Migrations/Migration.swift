import Foundation
import SwiftData

/// マイグレーションプロトコル
/// 各マイグレーションはこのプロトコルに準拠する必要があります
@available(iOS 17, *)
protocol Migration {
  /// マイグレーションのバージョン識別子（例: "v1_iPhone16e_AvgTemp"）
  static var version: String { get }

  /// マイグレーションの説明
  static var description: String { get }

  /// マイグレーションを実行する
  /// - Parameter modelContext: SwiftDataのモデルコンテキスト
  /// - Throws: マイグレーション中のエラー
  static func migrate(modelContext: ModelContext) throws
}
