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
    static let enableCapacityValidation = "enableCapacityValidation"
    static let capacityValidationThreshold = "capacityValidationThreshold"
    static let mismatchBehavior = "mismatchBehavior"
  }

  /// 容量不一致時の挙動
  enum MismatchBehavior: String, CaseIterable, Identifiable {
    case manualSelection = "manualSelection"
    case error = "error"

    var id: String { self.rawValue }

    var localizedName: String {
      switch self {
      case .manualSelection: return String(localized: "mismatch_behavior_manual")
      case .error: return String(localized: "mismatch_behavior_error")
      }
    }
  }

  // MARK: - Published Properties

  /// 登録済みのApple Watchモデル名
  @Published var registeredWatchModel: String?

  /// チュートリアル完了済みフラグ
  @Published var hasCompletedTutorial: Bool

  /// バッテリー容量のバリデーションを有効にするか
  @Published var enableCapacityValidation: Bool

  /// バッテリー容量バリデーションの閾値（倍率）
  @Published var capacityValidationThreshold: Double

  /// 容量不一致時の挙動
  @Published var mismatchBehavior: MismatchBehavior

  // MARK: - Initialization

  private init() {
    self.registeredWatchModel = UserDefaults.standard.string(forKey: Keys.registeredWatchModel)
    self.hasCompletedTutorial = UserDefaults.standard.bool(forKey: Keys.hasCompletedTutorial)

    // デフォルト値の設定
    if UserDefaults.standard.object(forKey: Keys.enableCapacityValidation) == nil {
      self.enableCapacityValidation = true
    } else {
      self.enableCapacityValidation = UserDefaults.standard.bool(
        forKey: Keys.enableCapacityValidation)
    }

    let threshold = UserDefaults.standard.double(forKey: Keys.capacityValidationThreshold)
    self.capacityValidationThreshold = threshold == 0 ? 10.0 : threshold

    if let behaviorString = UserDefaults.standard.string(forKey: Keys.mismatchBehavior),
      let behavior = MismatchBehavior(rawValue: behaviorString)
    {
      self.mismatchBehavior = behavior
    } else {
      self.mismatchBehavior = .manualSelection
    }

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

    $enableCapacityValidation
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.enableCapacityValidation)
      }
      .store(in: &cancellables)

    $capacityValidationThreshold
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.capacityValidationThreshold)
      }
      .store(in: &cancellables)

    $mismatchBehavior
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value.rawValue, forKey: Keys.mismatchBehavior)
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
