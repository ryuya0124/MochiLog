import Charts
import SwiftData
// HomeView.swift
// 別ファイルへ分離
import SwiftUI
import UniformTypeIdentifiers

// MARK: - メインタブビュー
struct MainTabView: View {
  @StateObject private var appSettings = AppSettings.shared
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var showingTutorial = false
  @State private var selectedTab: AppTab = .home

  /// タブの定義
  enum AppTab: Int, CaseIterable, Identifiable {
    case home = 0
    case analytics = 1
    case settings = 2

    var id: Int { rawValue }

    var title: String {
      switch self {
      case .home: return String(localized: "tab_home", table: "Home")
      case .analytics: return String(localized: "tab_analytics", table: "Analytics")
      case .settings: return String(localized: "tab_settings", table: "Settings")
      }
    }

    var icon: String {
      switch self {
      case .home: return "house.fill"
      case .analytics: return "chart.line.uptrend.xyaxis"
      case .settings: return "gearshape.fill"
      }
    }
  }

  var body: some View {
    Group {
      if #available(iOS 18.0, *) {
        // iOS 18+: sidebarAdaptable スタイル（サイドバーを閉じると上部にタブバー）
        modernTabView
      } else if horizontalSizeClass == .regular {
        // iOS 17以下 + iPad: NavigationSplitView
        legacySplitView
      } else {
        // iOS 17以下 + iPhone: 従来のTabView
        legacyTabView
      }
    }
    .onAppear {
      // 初回起動時にチュートリアルを表示
      if !appSettings.hasCompletedTutorial {
        showingTutorial = true
      }
    }
    .sheet(isPresented: $showingTutorial) {
      TutorialView()
    }
    // AppSettings.selectedTabIndexの変更を監視してselectedTabに反映
    .onChange(of: appSettings.selectedTabIndex) { _, newValue in
      if let newTab = AppTab(rawValue: newValue), newTab != selectedTab {
        selectedTab = newTab
      }
    }
    // selectedTabの変更をselectedTabIndexに反映
    .onChange(of: selectedTab) { _, newValue in
      if appSettings.selectedTabIndex != newValue.rawValue {
        appSettings.selectedTabIndex = newValue.rawValue
      }
    }
  }

  // MARK: - iOS 18+ sidebarAdaptable スタイル
  @available(iOS 18.0, *)
  private var modernTabView: some View {
    TabView(selection: $selectedTab) {
      Tab(AppTab.home.title, systemImage: AppTab.home.icon, value: .home) {
        HomeView()
      }
      Tab(AppTab.analytics.title, systemImage: AppTab.analytics.icon, value: .analytics) {
        AnalyticsView()
      }
      Tab(AppTab.settings.title, systemImage: AppTab.settings.icon, value: .settings) {
        SettingsView()
      }
    }
    .tabViewStyle(.sidebarAdaptable)
    .tint(appSettings.accentColor.color)
  }

  // MARK: - iOS 17以下 iPad用 NavigationSplitView
  private var legacySplitView: some View {
    NavigationSplitView {
      List {
        ForEach(AppTab.allCases) { tab in
          Label(tab.title, systemImage: tab.icon)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
              selectedTab = tab
            }
            .listRowBackground(selectedTab == tab ? Color.accentColor.opacity(0.2) : Color.clear)
        }
      }
      .navigationTitle("MochiLog")
      .listStyle(.sidebar)
    } detail: {
      switch selectedTab {
      case .home:
        HomeView()
      case .analytics:
        AnalyticsView()
      case .settings:
        SettingsView()
      }
    }
    // トランジションアニメーションを無効化
    .animation(nil, value: selectedTab)
    .tint(appSettings.accentColor.color)
  }

  // MARK: - iOS 17以下 iPhone用 TabView
  private var legacyTabView: some View {
    TabView(selection: $selectedTab) {
      HomeView()
        .tabItem {
          Label(AppTab.home.title, systemImage: AppTab.home.icon)
        }
        .tag(AppTab.home)
      AnalyticsView()
        .tabItem {
          Label(AppTab.analytics.title, systemImage: AppTab.analytics.icon)
        }
        .tag(AppTab.analytics)
      SettingsView()
        .tabItem {
          Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
        }
        .tag(AppTab.settings)
    }
    .tint(appSettings.accentColor.color)
  }
}

// MARK: - ホームビュー本体
struct HomeView: View {
  @Environment(\.modelContext) var modelContext
  @Environment(\.horizontalSizeClass) var horizontalSizeClass
  @Query(sort: \BatteryRecord.logDate, order: .reverse) var records: [BatteryRecord]
  @StateObject var appSettings = AppSettings.shared

  @State private var showingFilePicker = false
  @State var showingErrorAlert = false
  @State var errorMessage = ""
  @State var selectedRecord: BatteryRecord?
  /// iPadでナビゲーションによる詳細表示に使用する
  @State var navigatingRecord: BatteryRecord?
  @State var pendingParseResult: LogParser.ParseResult?
  @State var showingWatchSelection = false
  @State var isProcessing = false
  @State var showingMismatchAlert = false
  @State private var showingManualDevicePicker = false
  @State private var showingRegisterWatchAlert = false
  @State private var watchNameToRegister = ""
  @State private var showingParseErrorSavedAlert = false
  @State private var showingDebugLogsSheet = false
  @State private var showingReorderSheet = false
  @State private var showingTutorial = false

  @State private var viewportHeight: CGFloat = 0

  // デバッグ用：このHomeViewインスタンスを識別するID
  private let instanceID = UUID()

  /// 処理済みのログハッシュとタイムスタンプ（複数インスタンスで共有）

  private static var lastProcessedLogHash: Int?
  private static var lastProcessedTime: Date?

  /// 直近に追加されたログのキャッシュ（ログ日時: 追加時刻）。
  /// SwiftDataの反映ラグによる多重追加を防ぐために使用。
  static var recentlyAddedLogs: [String: Date] = [:]

  /// 現在処理中のcontentHash（複数のHomeViewインスタンスでの重複処理を防ぐ）
  static var processingContentHashes: Set<Int> = []
  static var processingLock = NSLock()

  var body: some View {
    NavigationStack {
      ZStack {
        homeContent
        processingOverlay
      }
      .navigationTitle("MochiLog")
      .toolbar {
        if !records.isEmpty || appSettings.showingSampleData {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingReorderSheet = true }) {
              Image(systemName: "arrow.up.arrow.down")
            }
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { showingFilePicker = true }) {
            Image(systemName: "plus")
          }
          .disabled(isProcessing)
        }
      }
      .sheet(isPresented: $showingReorderSheet) {
        DeviceReorderView(
          items: appSettings.showingSampleData
            ? SampleDataProvider.sampleDeviceNames
            : Array(Set(records.map { $0.deviceName })).sorted(),
          onSave: { newOrder in
            appSettings.deviceSortOrder = newOrder
          }
        )
      }
      .fileImporter(
        isPresented: $showingFilePicker,
        allowedContentTypes: [
          .json,
          .plainText,
          .data,
          .folder,
          UTType(filenameExtension: "zip")!,
          UTType(filenameExtension: "ips")!,
          UTType(filenameExtension: "synced")!,  // .ips.ca.synced ファイル用
        ],
        allowsMultipleSelection: true
      ) { result in
        Task {
          await handleFileImport(result: result)
        }
      }
      .alert(String(localized: "error", table: "Common"), isPresented: $showingErrorAlert) {
        Button(String(localized: "ok", table: "Common"), role: .cancel) {}
      } message: {
        Text(errorMessage)
      }
      .sheet(
        item: Binding(
          get: { horizontalSizeClass == .compact ? selectedRecord : nil },
          set: { selectedRecord = $0 }
        )
      ) { record in
        RecordDetailView(record: record)
      }
      .navigationDestination(item: $navigatingRecord) { record in
        RecordDetailView(record: record)
      }
      .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProcessSharedLog")))
      {
        notification in
        // 通知のuserInfoから直接テキストを取得
        guard let text = notification.userInfo?["text"] as? String, !text.isEmpty else {
          print("[HomeView] Skipping notification (no text)")
          // 空の通知の場合も処理フラグをリセット
          NotificationCenter.default.post(
            name: NSNotification.Name("SharedLogProcessingCompleted"),
            object: nil
          )
          return
        }

        // Determine whether we should process silently (don't show UI)
        let silent = (notification.userInfo?["silent"] as? Bool) ?? false
        let contentHash = notification.userInfo?["contentHash"] as? Int

        // 複数のHomeViewインスタンスでの重複処理を防ぐ
        if let hash = contentHash {
          HomeView.processingLock.lock()
          let isAlreadyProcessing = HomeView.processingContentHashes.contains(hash)
          if !isAlreadyProcessing {
            HomeView.processingContentHashes.insert(hash)
          }
          HomeView.processingLock.unlock()

          if isAlreadyProcessing {
            print(
              "[HomeView] Instance \(instanceID) skipping duplicate processing for hash: \(hash)")
            return
          }

          // 10秒後に自動的にクリーンアップ（処理が失敗した場合のフェイルセーフ）
          DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            HomeView.processingLock.lock()
            HomeView.processingContentHashes.remove(hash)
            HomeView.processingLock.unlock()
          }
        }

        print(
          "[HomeView] Instance \(instanceID) processing shared log, silent=\(silent), hash=\(String(describing: contentHash))"
        )
        processLogTextAsync(text, silent: silent, contentHash: contentHash)
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSNotification.Name("ShowRecordDetail"))
      ) { notification in
        print("[HomeView] Instance \(instanceID) received ShowRecordDetail notification")
        guard let logDate = notification.userInfo?["logDate"] as? Date,
          let deviceName = notification.userInfo?["deviceName"] as? String
        else {
          return
        }

        // recordsから該当するレコードを検索
        if let record = records.first(where: {
          $0.deviceName == deviceName && abs($0.logDate.timeIntervalSince(logDate)) < 1.0
        }) {
          print("[HomeView] Instance \(instanceID) showing detail for \(deviceName)")
          showRecordDetail(record)
        } else {
          print("[HomeView] Instance \(instanceID) record not found yet, waiting...")
        }
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSNotification.Name("ShowImportError"))
      ) { notification in
        if let error = notification.userInfo?["errorMessage"] as? String {
          errorMessage = error
          showingErrorAlert = true
        }
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSNotification.Name("DeleteAllDataPerformed"))
      ) { _ in
        // Clear transient UI and pending state when all data is removed
        pendingParseResult = nil
        selectedRecord = nil
        showingMismatchAlert = false
        showingWatchSelection = false
        showingManualDevicePicker = false
        showingRegisterWatchAlert = false
      }
      .onReceive(
        NotificationCenter.default.publisher(for: NSNotification.Name("ParseErrorSaved"))
      ) {
        _ in
        // デバッグログ表示設定がオンの場合のみアラートを表示
        if appSettings.showPopupOnLoad {
          showingParseErrorSavedAlert = true
        }
      }
      .alert(
        String(localized: "log_saved", table: "Home"), isPresented: $showingParseErrorSavedAlert
      ) {
        Button(String(localized: "view_log", table: "Records")) {
          // アラートが閉じた後にシートを開く
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingDebugLogsSheet = true
          }
        }
        Button(String(localized: "ok", table: "Common"), role: .cancel) {}
      } message: {
        Text(String(localized: "log_saved_message", table: "Home"))
      }
      .sheet(isPresented: $showingDebugLogsSheet) {
        DebugLogsView()
      }
      .sheet(isPresented: $showingTutorial) {
        TutorialView()
      }
      .onAppear {
        reconcileUnknownDeviceNames()
        reconcileMissingDesignCapacities()
        // UserDefaultsフォールバックは廃止（MochiLogAppから直接Notificationが送信される）
      }
      .sheet(isPresented: $showingWatchSelection) {
        HierarchicalDevicePickerView(initialCategory: .watch, lockCategory: true) {
          name, identifier in
          guard let result = pendingParseResult else { return }
          let record = createRecord(
            from: result,
            deviceName: name,
            deviceModelCodeOverride: identifier,
            designCapacityOverride: DeviceLibrary.getCapacity(for: name)
          )
          withAnimation(.snappy) {
            modelContext.insert(record)
          }
          // 保存はアニメーション外で行う
          Task.detached(priority: .userInitiated) {
            await MainActor.run {
              try? self.modelContext.save()
            }
          }
          selectedRecord = nil
          pendingParseResult = nil

          if appSettings.registeredWatchModel == nil {
            watchNameToRegister = name
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
              showingRegisterWatchAlert = true
            }
          }
        }
      }
      .alert(
        String(localized: "register_watch_title", table: "Settings"),
        isPresented: $showingRegisterWatchAlert
      ) {
        Button(String(localized: "register", table: "Common")) {
          appSettings.registeredWatchModel = watchNameToRegister
        }
        Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
      } message: {
        Text(String(localized: "register_watch_message", table: "Settings"))
      }
      .alert(
        String(localized: "mismatch_warning_title", table: "Home"),
        isPresented: $showingMismatchAlert
      ) {
        Button(String(localized: "select_manually", table: "Home")) {
          showingManualDevicePicker = true
        }
        Button(String(localized: "cancel", table: "Common"), role: .cancel) {
          pendingParseResult = nil
        }
      } message: {
        Text(String(localized: "mismatch_warning_message", table: "Home"))
      }
      .sheet(isPresented: $showingManualDevicePicker) {
        HierarchicalDevicePickerView { name, identifier in
          guard let result = pendingParseResult else { return }
          let record = createRecord(
            from: result,
            deviceName: name,
            deviceModelCodeOverride: identifier,
            designCapacityOverride: DeviceLibrary.getCapacity(for: name)
          )
          withAnimation(.snappy) {
            modelContext.insert(record)
          }
          // 保存はアニメーション外で行う
          Task.detached(priority: .userInitiated) {
            await MainActor.run {
              try? self.modelContext.save()
            }
          }
          selectedRecord = nil
          pendingParseResult = nil

          if name.contains("Apple Watch") && appSettings.registeredWatchModel == nil {
            watchNameToRegister = name
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
              showingRegisterWatchAlert = true
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var homeContent: some View {
    if appSettings.showingSampleData {
      SampleDataHomeView(
        showingSampleData: $appSettings.showingSampleData,
        onRecordTap: { record in
          showRecordDetail(record)
        },
        openFilePicker: {
          showingFilePicker = true
        })
    } else if !records.isEmpty {
      RecordListView(
        records: records,
        onRecordTap: { record in
          showRecordDetail(record)
        },
        onRecordDelete: { record in
          deleteRecords([record])
        },
        showContextMenu: true
      )
    } else {
      noDataView
    }
  }

  private var noDataView: some View {
    GeometryReader { geo in
      ScrollView {
        ContentUnavailableView {
          Label(String(localized: "no_data", table: "Home"), systemImage: "battery.0")
        } description: {
          Text(String(localized: "no_data_description", table: "Home"))
        } actions: {
          VStack(spacing: 12) {
            Button {
              showingTutorial = true
            } label: {
              Label(String(localized: "view_tutorial", table: "Home"), systemImage: "play.circle")
            }
            .buttonStyle(.bordered)

            Button {
              withAnimation { appSettings.showingSampleData = true }
            } label: {
              Label(String(localized: "view_sample_data", table: "Home"), systemImage: "eye")
            }
            .buttonStyle(.borderedProminent)
          }
        }
        .frame(maxWidth: .infinity)
        // 「実スクロール」を作らないため、viewportより 1pt 小さくする
        .frame(minHeight: max(0, viewportHeight - 1))
      }
      .scrollBounceBehavior(.always)  // バウンスは常に有効
      .onAppear {
        viewportHeight = geo.size.height
      }
      .onChange(of: geo.size.height) { oldValue, newValue in
        // 回転など「大きい変化」だけ追従。Large Title の伸縮由来の揺れは無視。
        if abs(newValue - viewportHeight) > 80 {
          viewportHeight = newValue
        }
      }
    }
  }

  @ViewBuilder
  private var processingOverlay: some View {
    if isProcessing {
      Color.black.opacity(0.3)
        .ignoresSafeArea()
      VStack(spacing: 16) {
        ProgressView()
          .scaleEffect(1.5)
          .tint(.white)
        Text(String(localized: "parsing_log", table: "Home"))
          .font(.headline)
          .foregroundColor(.white)
      }
      .padding(32)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
  }
}
