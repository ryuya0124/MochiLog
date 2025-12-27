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

    // 新規: チャートとiCloud設定
    static let defaultChartUnit = "defaultChartUnit"
    static let iCloudSyncEnabled = "iCloudSyncEnabled"
    static let iCloudStorageThresholdMB = "iCloudStorageThresholdMB"
    static let accentColor = "accentColor"
    static let showPopupOnLoad = "showPopupOnLoad"

    // 新規: 共有インポート時にアプリを開くかどうか
    static let openAppAfterShareImport = "openAppAfterShareImport"

    // 新規: デバイスの並び順
    static let deviceSortOrder = "deviceSortOrder"

    // 新規: 分析データの計算基準
    static let analysisDataSource = "analysisDataSource"

    // 新規: 重複ログ記録を許可
    static let allowDuplicateRecords = "allowDuplicateRecords"
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

  /// 分析データの計算基準
  enum AnalysisDataSource: String, CaseIterable, Identifiable {
    case actual = "actual"
    case nominal = "nominal"

    var id: String { self.rawValue }

    var localizedName: String {
      switch self {
      case .actual: return String(localized: "analysis_source_actual")
      case .nominal: return String(localized: "analysis_source_nominal")
      }
    }
  }

  /// チャートで利用する単位
  enum ChartUnit: String, CaseIterable, Identifiable {
    case hour
    case day
    case week
    case month

    var id: String { self.rawValue }

    var localizedName: String {
      switch self {
      case .hour: return String(localized: "chart_unit_hour")
      case .day: return String(localized: "chart_unit_day")
      case .week: return String(localized: "chart_unit_week")
      case .month: return String(localized: "chart_unit_month")
      }
    }

    var calendarComponent: Calendar.Component {
      switch self {
      case .hour: return .hour
      case .day: return .day
      case .week: return .weekOfYear
      case .month: return .month
      }
    }
  }

  /// アプリのアクセントカラー（テーマ色）
  enum ThemeColor: String, CaseIterable, Identifiable {
    case green
    case blue
    case orange
    case purple

    var id: String { self.rawValue }

    var localizedName: String {
      switch self {
      case .green: return String(localized: "theme_color_green")
      case .blue: return String(localized: "theme_color_blue")
      case .orange: return String(localized: "theme_color_orange")
      case .purple: return String(localized: "theme_color_purple")
      }
    }

    var color: Color {
      switch self {
      case .green: return .green
      case .blue: return .blue
      case .orange: return .orange
      case .purple: return .purple
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

  /// デフォルトのチャート単位
  @Published var defaultChartUnit: ChartUnit

  /// iCloud同期を有効にするか（設定）
  @Published var iCloudSyncEnabled: Bool

  /// iCloud同期を抑制するための容量閾値（MB）
  @Published var iCloudStorageThresholdMB: Double

  /// iCloud 同期がブロックされた際の説明（ユーザ表示用）
  @Published var iCloudSyncBlockedReason: String?

  /// 読み込み後すぐにポップアップを表示するか
  @Published var showPopupOnLoad: Bool

  /// 共有インポート時にアプリを開くかどうか（true = 開く、false = 開かない）
  @Published var openAppAfterShareImport: Bool

  /// アプリのアクセント（テーマ）カラー
  @Published var accentColor: ThemeColor

  /// セッション内（アプリ再起動まで）にチャートのレンジ初期化を自動で行ったかどうか
  /// - 注意: 永続化しない。一度 true になるとアプリが再起動するまで上書きしない（ユーザーの選択を尊重するため）
  @Published var hasAutoInitializedChartRange: Bool = false

  /// サンプルデータ表示モード（タブ間で共有、非永続化）
  @Published var showingSampleData: Bool = false

  /// 選択されているタブのインデックス（0: Home, 1: Analytics, 2: Settings）
  /// 選択されているタブのインデックス（0: Home, 1: Analytics, 2: Settings）
  @Published var selectedTabIndex: Int = 0

  /// デバイスの並び順（名前の配列）
  @Published var deviceSortOrder: [String] = []

  /// 分析データの計算基準
  @Published var analysisDataSource: AnalysisDataSource

  /// 重複したログの記録を許可するかどうか
  @Published var allowDuplicateRecords: Bool

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

    // 新規: チャート単位とiCloud設定の初期値
    if let chartUnitString = UserDefaults.standard.string(forKey: Keys.defaultChartUnit),
      let unit = ChartUnit(rawValue: chartUnitString)
    {
      self.defaultChartUnit = unit
    } else {
      self.defaultChartUnit = .day
    }

    if UserDefaults.standard.object(forKey: Keys.iCloudSyncEnabled) == nil {
      self.iCloudSyncEnabled = false
    } else {
      self.iCloudSyncEnabled = UserDefaults.standard.bool(forKey: Keys.iCloudSyncEnabled)
    }

    let storageThreshold = UserDefaults.standard.double(forKey: Keys.iCloudStorageThresholdMB)
    self.iCloudStorageThresholdMB = storageThreshold == 0 ? 100.0 : storageThreshold

    // 読み込み後すぐにポップアップを表示するか: デフォルトは false
    if UserDefaults.standard.object(forKey: Keys.showPopupOnLoad) == nil {
      self.showPopupOnLoad = false
    } else {
      self.showPopupOnLoad = UserDefaults.standard.bool(forKey: Keys.showPopupOnLoad)
    }

    // 共有インポート時にアプリを開くかどうか: デフォルトは true
    if UserDefaults.standard.object(forKey: Keys.openAppAfterShareImport) == nil {
      self.openAppAfterShareImport = true
    } else {
      self.openAppAfterShareImport = UserDefaults.standard.bool(
        forKey: Keys.openAppAfterShareImport)
    }

    // アクセントカラー: 永続化された値があれば読み込む
    if let colorString = UserDefaults.standard.string(forKey: Keys.accentColor),
      let theme = ThemeColor(rawValue: colorString)
    {
      self.accentColor = theme
    } else {
      self.accentColor = .green
    }

    // ブロック理由は起動時には空
    self.iCloudSyncBlockedReason = nil

    // デバイス並び順の読み込み
    self.deviceSortOrder = UserDefaults.standard.stringArray(forKey: Keys.deviceSortOrder) ?? []

    // 分析データソースの初期化
    if let sourceString = UserDefaults.standard.string(forKey: Keys.analysisDataSource),
      let source = AnalysisDataSource(rawValue: sourceString)
    {
      self.analysisDataSource = source
    } else {
      self.analysisDataSource = .nominal
    }

    // 重複ログ記録許可の初期化（デフォルトは false）
    self.allowDuplicateRecords = UserDefaults.standard.bool(forKey: Keys.allowDuplicateRecords)

    // プロパティの変更を監視してUserDefaultsに保存
    setupObservers()

    // 起動時に iCloud 同期が有効な場合は再評価して必要なら無効化する
    if self.iCloudSyncEnabled {
      _ = attemptSetICloudSync(true)
    }
  }

  private var cancellables = Set<AnyCancellable>()

  private func setupObservers() {
    $registeredWatchModel
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.registeredWatchModel)
      }
      .store(in: &cancellables)

    $hasCompletedTutorial
      .dropFirst()
      .sink { value in
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

    // 新規: チャート単位の永続化
    $defaultChartUnit
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value.rawValue, forKey: Keys.defaultChartUnit)
      }
      .store(in: &cancellables)

    // 新規: iCloud 同期設定の永続化・検証
    $iCloudSyncEnabled
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.iCloudSyncEnabled)
        // NOTE: Do NOT call `attemptSetICloudSync` here to avoid re-entrant calls that can
        // lead to infinite recursion (setting the published property from within its own sink).
        // Validation/activation should be triggered explicitly from UI (SettingsView) or during init.
      }
      .store(in: &cancellables)

    $iCloudStorageThresholdMB
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.iCloudStorageThresholdMB)
      }
      .store(in: &cancellables)

    // Persist show popup on load setting
    $showPopupOnLoad
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.showPopupOnLoad)
      }
      .store(in: &cancellables)

    // Persist 'open app after share import' setting
    $openAppAfterShareImport
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.openAppAfterShareImport)
      }
      .store(in: &cancellables)

    // Persist accent color changes
    $accentColor
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value.rawValue, forKey: Keys.accentColor)
      }
      .store(in: &cancellables)

    $deviceSortOrder
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.deviceSortOrder)
      }
      .store(in: &cancellables)

    $analysisDataSource
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value.rawValue, forKey: Keys.analysisDataSource)
      }
      .store(in: &cancellables)

    $allowDuplicateRecords
      .dropFirst()
      .sink { value in
        UserDefaults.standard.set(value, forKey: Keys.allowDuplicateRecords)
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

  // MARK: - iCloud / Storage helpers

  /// デバイスの空き容量をMBで取得
  func deviceFreeSpaceMB() -> Double {
    do {
      let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
      if let free = attrs[.systemFreeSize] as? NSNumber {
        return free.doubleValue / 1024.0 / 1024.0
      }
    } catch {
      return 0
    }
    return 0
  }

  /// iCloud 有効化時の失敗理由
  enum ICloudError: LocalizedError {
    case lowSpace(requiredMB: Int)
    case unknown

    var errorDescription: String? {
      switch self {
      case .lowSpace(let requiredMB):
        return String(format: String(localized: "icloud_sync_blocked_low_space"), requiredMB)
      case .unknown:
        return String(localized: "icloud_sync_failed")
      }
    }
  }

  /// iCloud 同期を有効化する前に容量を評価する。
  func canEnableICloudSync() -> Result<Void, ICloudError> {
    let freeMB = deviceFreeSpaceMB()
    if freeMB < iCloudStorageThresholdMB {
      return .failure(.lowSpace(requiredMB: Int(iCloudStorageThresholdMB)))
    }
    return .success(())
  }

  /// 互換性用: 古い evaluateStorageAndMaybeBlockSync 呼び出しを解決するヘルパー
  private func evaluateStorageAndMaybeBlockSync() {
    _ = attemptSetICloudSync(true)
  }

  /// ユーザーが iCloud 同期を切り替えようとしたときに呼ぶ。失敗時はエラーを返す（UI側でアラート等を表示する）
  func attemptSetICloudSync(_ enabled: Bool) -> Result<Void, ICloudError> {
    // Short-circuit if state is already the desired one to avoid unnecessary sinks and re-entry
    if iCloudSyncEnabled == enabled { return .success(()) }

    if enabled {
      switch canEnableICloudSync() {
      case .success:
        iCloudSyncEnabled = true
        iCloudSyncBlockedReason = nil
        // TODO: 実際の iCloud / CloudKit 同期処理の開始
        return .success(())
      case .failure(let err):
        // do not enable and record reason
        iCloudSyncBlockedReason = err.errorDescription
        iCloudSyncEnabled = false
        return .failure(err)
      }
    } else {
      // Disable sync
      iCloudSyncEnabled = false
      iCloudSyncBlockedReason = nil
      // TODO: 停止処理
      return .success(())
    }
  }
}
