import Combine
import Foundation
import SwiftUI

/// アプリ全体の設定を管理するクラス
final class AppSettings: ObservableObject {
  static let shared = AppSettings()

  // MARK: - UserDefaults Keys
  private enum Keys {
    static let registeredWatchModel = "registeredWatchModel"
    static let hasCompletedTutorial = "hasCompletedTutorial"
  }

  // MARK: - Published Properties

  /// 登録済みのApple Watchモデル名
  @Published var registeredWatchModel: String?

  /// チュートリアル完了済みフラグ
  @Published var hasCompletedTutorial: Bool

  // MARK: - Initialization

  private init() {
    self.registeredWatchModel = UserDefaults.standard.string(forKey: Keys.registeredWatchModel)
    self.hasCompletedTutorial = UserDefaults.standard.bool(forKey: Keys.hasCompletedTutorial)

    // プロパティの変更を監視してUserDefaultsに保存
    setupObservers()
  }

  private var cancellables = Set<AnyCancellable>()

  private func setupObservers() {
    $registeredWatchModel
      .dropFirst()
      .sink { [weak self] value in
        UserDefaults.standard.set(value, forKey: Keys.registeredWatchModel)
      }
      .store(in: &cancellables)

    $hasCompletedTutorial
      .dropFirst()
      .sink { [weak self] value in
        UserDefaults.standard.set(value, forKey: Keys.hasCompletedTutorial)
      }
      .store(in: &cancellables)
  }

  // MARK: - Methods

  /// Apple Watchモデルを登録
  func registerWatch(model: String) {
    registeredWatchModel = model
  }

  /// Apple Watch登録を解除
  func unregisterWatch() {
    registeredWatchModel = nil
  }

  /// チュートリアル完了を記録
  func completeTutorial() {
    hasCompletedTutorial = true
  }

  /// 利用可能なApple Watchモデル一覧を取得
  func availableWatchModels() -> [String] {
    return Array(Set(DeviceLibrary.deviceNames.values))
      .filter { $0.contains("Apple Watch") }
      .sorted()
  }

  /// デバイス情報を取得（サポート問い合わせ用）
  func getDeviceInfo() -> String {
    let device = UIDevice.current
    let appVersion =
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    let systemVersion = device.systemVersion
    let modelIdentifier = DeviceLibrary.localModelIdentifier() ?? "Unknown"
    let modelName = DeviceLibrary.getDeviceName(for: modelIdentifier) ?? modelIdentifier

    return """
      ---
      デバイス情報 / Device Info:
      アプリバージョン / App Version: \(appVersion) (\(buildNumber))
      iOS バージョン / iOS Version: \(systemVersion)
      デバイス / Device: \(modelName) (\(modelIdentifier))
      言語 / Language: \(Locale.current.language.languageCode?.identifier ?? "Unknown")
      ---
      """
  }
}
