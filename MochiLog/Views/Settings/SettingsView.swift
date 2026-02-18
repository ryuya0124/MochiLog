import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 設定ビュー
struct SettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @StateObject private var appSettings = AppSettings.shared
  @State private var recordDataManager = RecordDataManager.shared

  /// RecordDataManagerからレコードを取得（キャッシュ済み）
  private var records: [BatteryRecord] {
    recordDataManager.recordsDescending
  }

  /// 利用可能なデバイス名リスト（ソート済み）
  private var availableDevices: [String] {
    let deviceNames = recordDataManager.deviceNames

    // AppSettings.deviceSortOrderでソート
    if appSettings.deviceSortOrder.isEmpty {
      return deviceNames
    } else {
      var ordered: [String] = []
      var remaining = Set(deviceNames)

      for name in appSettings.deviceSortOrder {
        if remaining.contains(name) {
          ordered.append(name)
          remaining.remove(name)
        }
      }
      ordered.append(contentsOf: remaining.sorted())
      return ordered
    }
  }

  @State private var showingWatchPicker = false
  @State private var showingDeleteConfirmation = false
  @State private var showingNoDataToDeleteAlert = false
  @State private var showingRemoveWatchConfirmation = false
  @State private var watchToRemove: String? = nil
  @State private var showingRemoveAllWatchesConfirmation = false
  @State private var showingTutorial = false
  @State private var showingSupportForm = false
  @State private var showingDonation = false
  @State private var showingDeleteDeviceConfirmation = false
  @State private var deletingDeviceId: String? = nil
  @State private var isAdvancedExpanded = false

  // デバイス選択設定用
  @State private var showingDevicePickerForRegistration = false

  // iCloud トグル用ローカル状態とエラー表示
  @State private var localICloudToggle: Bool = false
  @State private var showingICloudErrorAlert = false
  @State private var iCloudErrorMessage: String = ""

  // デバイスごとの削除機能用の状態
  @State private var showingDeviceDeletePicker = false
  @State private var showingDeviceDeleteConfirmation = false
  @State private var selectedDeviceToDelete: String?

  // ショートカット関連のアラート
  @State private var showingShortcutSetupPrompt = false

  // エクスポート/インポート関連
  @State private var showingExportSheet = false
  @State private var showingImportSheet = false
  @State private var showingImportAlert = false
  @State private var importResultMessage = ""
  @State private var showingExportError = false
  @State private var exportErrorMessage = ""

  // 大画面レイアウト用: 選択されたカテゴリ
  @State private var selectedCategory: SettingsCategory = .general

  var body: some View {
    NavigationStack {
      settingsList
        .navigationTitle(String(localized: "settings_title", table: "Settings"))
        .onAppear {
          localICloudToggle = appSettings.iCloudSyncEnabled
          setupShortcutNotification()
        }
        .sheet(isPresented: $showingWatchPicker) {
          HierarchicalDevicePickerView(initialCategory: .watch, lockCategory: true) {
            name, identifier in
            appSettings.registerWatch(model: name)
          }
        }
        .sheet(isPresented: $showingDevicePickerForRegistration) {
          HierarchicalDevicePickerView(allowedCategories: [.iphone, .ipad]) { name, identifier in
            appSettings.registerDevice(name: name)
          }
        }
        .sheet(isPresented: $showingTutorial) {
          TutorialView()
        }
        .sheet(isPresented: $showingSupportForm) {
          SupportFormView()
        }
        .sheet(isPresented: $showingDonation) {
          DonationView()
        }
        .alert(
          String(localized: "delete_all_data", table: "Settings"),
          isPresented: $showingDeleteConfirmation
        ) {
          Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
          Button(String(localized: "delete", table: "Common"), role: .destructive) {
            deleteAllRecords()
          }
        } message: {
          Text(String(localized: "delete_all_data_confirm", table: "Settings"))
        }
        .alert(
          String(localized: "no_data_to_delete_title", table: "Settings"),
          isPresented: $showingNoDataToDeleteAlert
        ) {
          Button(String(localized: "ok", table: "Common"), role: .cancel) {}
        } message: {
          Text(String(localized: "no_data_to_delete_message", table: "Settings"))
        }
        .alert(
          String(localized: "remove_watch", table: "Settings"),
          isPresented: $showingRemoveWatchConfirmation
        ) {
          Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
          Button(String(localized: "remove", table: "Common"), role: .destructive) {
            if let watch = watchToRemove {
              appSettings.removeWatch(model: watch)
            }
          }
        } message: {
          if let watch = watchToRemove {
            Text(
              String(
                format: String(localized: "remove_watch_confirm_specific", table: "Settings"), watch
              ))
          } else {
            Text(String(localized: "remove_watch_confirm", table: "Settings"))
          }
        }
        .alert(
          String(localized: "remove_all_watches", table: "Settings"),
          isPresented: $showingRemoveAllWatchesConfirmation
        ) {
          Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
          Button(String(localized: "remove", table: "Common"), role: .destructive) {
            appSettings.unregisterAllWatches()
          }
        } message: {
          Text(String(localized: "remove_all_watches_confirm", table: "Settings"))
        }
        .alert(
          String(localized: "icloud_sync_failed", table: "Settings"),
          isPresented: $showingICloudErrorAlert
        ) {
          Button(String(localized: "ok", table: "Common"), role: .cancel) {}
        } message: {
          Text(iCloudErrorMessage)
        }
        .sheet(isPresented: $showingDeviceDeletePicker) {
          DeviceDeletePickerView(availableDevices: availableDevices) { deviceName in
            selectedDeviceToDelete = deviceName
            showingDeviceDeleteConfirmation = true
          }
        }
        .alert(
          String(localized: "delete_device_data_title", table: "Settings"),
          isPresented: $showingDeviceDeleteConfirmation
        ) {
          Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
          Button(String(localized: "delete", table: "Common"), role: .destructive) {
            if let deviceName = selectedDeviceToDelete {
              deleteRecordsForDevice(deviceName)
            }
          }
        } message: {
          if let deviceName = selectedDeviceToDelete {
            Text(
              String(
                format: String(localized: "delete_device_data_confirm", table: "Settings"),
                deviceName
              ))
          }
        }
        .alert(
          String(localized: "shortcut_required_title", table: "Settings"),
          isPresented: $showingShortcutSetupPrompt
        ) {
          Button(String(localized: "setup_now", table: "Settings"), role: .none) {
            SettingsRedirectHelper.openShortcutSetup()
          }
          Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
        } message: {
          Text(String(localized: "shortcut_required_message", table: "Settings"))
        }
        .fileExporter(
          isPresented: $showingExportSheet,
          document: YAMLDocument(yaml: generateExportYAML()),
          contentType: .yaml,
          defaultFilename: DataExportService.generateFileName()
        ) { result in
          print("[SettingsView] fileExporter callback called")
          handleExportResult(result)
        }
        .onChange(of: showingExportSheet) { oldValue, newValue in
          print("[SettingsView] showingExportSheet changed from \(oldValue) to \(newValue)")
        }
        .fileImporter(
          isPresented: $showingImportSheet,
          allowedContentTypes: [.yaml],
          allowsMultipleSelection: false
        ) { result in
          print("[SettingsView] fileImporter callback called")
          handleImportResult(result)
        }
        .onChange(of: showingImportSheet) { oldValue, newValue in
          print("[SettingsView] showingImportSheet changed from \(oldValue) to \(newValue)")
        }
        .alert(
          String(localized: "import_result_title", table: "Settings"),
          isPresented: $showingImportAlert
        ) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(importResultMessage)
        }
        .alert(
          String(localized: "export_error_title", table: "Settings"),
          isPresented: $showingExportError
        ) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(exportErrorMessage)
        }
    }
  }

  // MARK: - iPad/iPhone向けList
  @ViewBuilder
  private var settingsList: some View {
    if horizontalSizeClass == .regular {
      // iPad: 2カラムレイアウト（左:カテゴリ一覧、右:詳細） - スクロール分離
      HStack(alignment: .top, spacing: 0) {
        // 左側：カテゴリ一覧（独立したScrollView）
        VStack(spacing: 0) {
          Divider()  // ヘッダーとの境界線
          ScrollView {
            VStack(spacing: 16) {
              ForEach(SettingsCategory.allCases) { category in
                CategoryCardView(
                  category: category,
                  isSelected: selectedCategory == category
                )
                .onTapGesture {
                  selectedCategory = category
                }
              }
            }
            .padding()
          }
        }
        .frame(width: 300)
        .frame(maxHeight: .infinity)
        .clipped()

        Divider()

        // 右側：選択されたカテゴリの詳細（Apple WatchのみList表示）
        if selectedCategory == .appleWatch {
          VStack(spacing: 0) {
            Divider()  // ヘッダーとの境界線
            AppleWatchSettingsView(
              showingWatchPicker: $showingWatchPicker,
              appSettings: appSettings
            )
          }
          .frame(maxHeight: .infinity)
          .clipped()
        } else if selectedCategory == .deviceSelection {
          VStack(spacing: 0) {
            Divider()  // ヘッダーとの境界線
            DeviceSelectionSettingsView(
              showingDevicePicker: $showingDevicePickerForRegistration,
              appSettings: appSettings
            )
          }
          .frame(maxHeight: .infinity)
          .clipped()
        } else {
          VStack(spacing: 0) {
            Divider()  // ヘッダーとの境界線
            ScrollView {
              VStack(spacing: 0) {
                switch selectedCategory {
                case .general:
                  GeneralSettingsView(
                    localICloudToggle: $localICloudToggle,
                    showingICloudErrorAlert: $showingICloudErrorAlert,
                    iCloudErrorMessage: $iCloudErrorMessage,
                    appSettings: appSettings
                  )
                case .appleWatch:
                  AppleWatchSettingsView(
                    showingWatchPicker: $showingWatchPicker,
                    appSettings: appSettings
                  )
                case .deviceSelection:
                  DeviceSelectionSettingsView(
                    showingDevicePicker: $showingDevicePickerForRegistration,
                    appSettings: appSettings
                  )
                case .dataManagement:
                  DataManagementSettingsView(
                    showingDeleteAllConfirmation: $showingDeleteConfirmation,
                    showingDeleteDeviceConfirmation: $showingDeleteDeviceConfirmation,
                    deletingDeviceId: $deletingDeviceId,
                    appSettings: appSettings,
                    availableDevices: availableDevices,
                    records: records,
                    modelContext: modelContext,
                    showingExportSheet: $showingExportSheet,
                    showingImportSheet: $showingImportSheet,
                    showingImportAlert: $showingImportAlert,
                    importResultMessage: $importResultMessage,
                    showingExportError: $showingExportError,
                    exportErrorMessage: $exportErrorMessage
                  )
                case .support:
                  SupportSettingsView()
                case .about:
                  AboutSettingsView()
                case .debug:
                  DebugSettingsView(appSettings: appSettings)
                case .advanced:
                  AdvancedSettingsView(appSettings: appSettings)
                }
              }
              .padding(.top)
              .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
          .groupBoxStyle(SettingsCardGroupBoxStyle())
          .frame(maxHeight: .infinity)
          .clipped()
        }
      }
      .background(Color(.systemGroupedBackground))
    } else {
      // iPhone: 通常のList
      List {
        settingsContent
      }
    }
  }

  // MARK: - 設定内容
  @ViewBuilder
  private var settingsContent: some View {
    // MARK: - 一般
    Section(String(localized: "general", table: "Settings")) {
      Toggle(
        String(localized: "enable_icloud_sync", table: "Settings"),
        isOn: Binding(
          get: {
            localICloudToggle
          },
          set: { newValue in
            localICloudToggle = newValue
            Task {
              let result = await appSettings.attemptSetICloudSyncAsync(newValue)
              await MainActor.run {
                switch result {
                case .success:
                  break
                case .failure(let err):
                  localICloudToggle = appSettings.iCloudSyncEnabled
                  iCloudErrorMessage =
                    err.errorDescription
                    ?? String(localized: "icloud_sync_failed", table: "Settings")
                  showingICloudErrorAlert = true
                }
              }
            }
          }))

      if let blocked = appSettings.iCloudSyncBlockedReason {
        Text(blocked)
          .font(.caption)
          .foregroundColor(.red)
      }

      Picker(
        String(localized: "accent_color", table: "Settings"),
        selection: $appSettings.accentColor
      ) {
        ForEach(AppSettings.ThemeColor.allCases) { theme in
          HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
              .fill(theme.color)
              .frame(width: 18, height: 18)
            Text(theme.localizedName)
          }
          .tag(theme)
        }
      }
      .pickerStyle(.menu)

      // サンプルデータ表示
      Button {
        appSettings.showingSampleData = true
        appSettings.selectedTabIndex = 0  // ホームページへ遷移
      } label: {
        Label(String(localized: "view_sample_data", table: "Home"), systemImage: "eye")
      }
    }

    // MARK: - デバイス選択設定
    Section {
      // モード表示・選択
      Picker(
        String(localized: "device_selection_mode", table: "Settings"),
        selection: $appSettings.deviceSelectionMode
      ) {
        ForEach(AppSettings.DeviceSelectionMode.allCases) { mode in
          Text(mode.localizedName).tag(mode)
        }
      }
      .pickerStyle(.menu)

      // preRegisteredモードの場合: 登録済みデバイス表示
      if appSettings.deviceSelectionMode == .preRegistered {
        if appSettings.registeredDevices.isEmpty {
          HStack {
            Label(
              String(localized: "registered_device", table: "Settings"),
              systemImage: "iphone.gen3"
            )
            Spacer()
            Text(String(localized: "not_registered", table: "Settings"))
              .foregroundStyle(.secondary)
          }
        } else {
          ForEach(appSettings.registeredDevices, id: \.self) { deviceName in
            HStack {
              let icon = deviceName.contains("iPad") ? "ipad.gen2" : "iphone.gen3"
              Label(deviceName, systemImage: icon)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button(role: .destructive) {
                appSettings.removeDevice(name: deviceName)
              } label: {
                Label(String(localized: "remove", table: "Common"), systemImage: "trash")
              }
              .tint(.red)
            }
          }
        }

        Button(action: { showingDevicePickerForRegistration = true }) {
          Label(
            String(localized: "add_device", table: "Settings"),
            systemImage: "plus.circle"
          )
        }
      }
    } header: {
      Text(String(localized: "device_selection_settings", table: "Settings"))
    } footer: {
      Text(appSettings.deviceSelectionMode.description)
    }

    // MARK: - Apple Watch 設定
    Section {
      // 登録済みWatchのリスト
      if appSettings.registeredWatches.isEmpty {
        HStack {
          Label(
            String(localized: "registered_watch", table: "Settings"), systemImage: "applewatch")
          Spacer()
          Text(String(localized: "not_registered", table: "Settings"))
            .foregroundStyle(.secondary)
        }
      } else {
        ForEach(appSettings.registeredWatches, id: \.self) { watchModel in
          HStack {
            Label(watchModel, systemImage: "applewatch")
          }
          .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
              watchToRemove = watchModel
              showingRemoveWatchConfirmation = true
            } label: {
              Label(String(localized: "remove", table: "Common"), systemImage: "trash")
            }
            .tint(.red)
          }
        }
      }

      // Watchを追加ボタン
      Button(action: { showingWatchPicker = true }) {
        Label(
          String(localized: "add_watch", table: "Settings"),
          systemImage: "plus.circle"
        )
      }

      // すべて削除ボタン（複数登録時のみ表示）
      if appSettings.registeredWatches.count > 1 {
        Button(action: { showingRemoveAllWatchesConfirmation = true }) {
          Label(
            String(localized: "remove_all_watches", table: "Settings"),
            systemImage: "trash"
          )
          .foregroundStyle(.red)
        }
      }
    } header: {
      Text(String(localized: "apple_watch_settings", table: "Settings"))
    } footer: {
      Text(
        appSettings.registeredWatches.isEmpty
          ? String(localized: "watch_selection_description", table: "Settings")
          : String(localized: "multiple_watch_description", table: "Settings")
      )
    }

    // MARK: - データ管理
    Section(String(localized: "data_management", table: "Settings")) {
      // エクスポート
      Button {
        showingExportSheet = true
      } label: {
        Label {
          Text(String(localized: "export_data", table: "Settings"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "square.and.arrow.up.fill")
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      // インポート
      Button {
        showingImportSheet = true
      } label: {
        Label {
          Text(String(localized: "import_data", table: "Settings"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "square.and.arrow.down.fill")
            .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button(role: .destructive) {
        if availableDevices.isEmpty {
          showingNoDataToDeleteAlert = true
        } else {
          showingDeviceDeletePicker = true
        }
      } label: {
        Label(String(localized: "delete_device_data", table: "Settings"), systemImage: "trash")
          .foregroundStyle(.red)
      }
      .tint(.red)

      Button(role: .destructive) {
        if records.isEmpty {
          showingNoDataToDeleteAlert = true
        } else {
          showingDeleteConfirmation = true
        }
      } label: {
        Label(
          String(localized: "delete_all_data", table: "Settings"), systemImage: "trash.fill"
        )
        .foregroundStyle(.red)
      }
      .tint(.red)
    }

    // MARK: - サポート
    Section(String(localized: "support", table: "Settings")) {
      Button(action: { showingTutorial = true }) {
        Label {
          Text(String(localized: "view_tutorial", table: "Home"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "lightbulb.fill")
            .foregroundStyle(.yellow)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      // ショートカット未インストール時のみ表示
      if !appSettings.isShortcutInstalled {
        Button(action: {
          SettingsRedirectHelper.openShortcutSetup()
        }) {
          Label {
            Text(String(localized: "setup_shortcut", table: "Settings"))
              .foregroundStyle(.primary)
          } icon: {
            Image(systemName: "arrow.down.circle")
              .foregroundStyle(.blue)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }

      Button(action: {
        SettingsRedirectHelper.openAnalyticsViaShortcut()
      }) {
        Label {
          Text(String(localized: "view_analytics_data", table: "Settings"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "doc.text.magnifyingglass")
            .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button(action: { showingSupportForm = true }) {
        Label {
          Text(String(localized: "contact_support", table: "Support"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "envelope.fill")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button(action: {
        if let url = URL(string: AppSettings.discordURL) {
          UIApplication.shared.open(url)
        }
      }) {
        Label {
          Text(String(localized: "join_discord", table: "Settings"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "bubble.left.and.bubble.right.fill")
            .foregroundStyle(.indigo)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      Button(action: { showingDonation = true }) {
        Label {
          Text(String(localized: "donation_title", table: "Settings"))
            .foregroundStyle(.primary)
        } icon: {
          Image(systemName: "heart.fill")
            .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }

    // MARK: - デバッグ
    Section(String(localized: "debug", table: "Support")) {
      Toggle(
        String(localized: "show_popup_on_load", table: "Support"),
        isOn: $appSettings.showPopupOnLoad)

      NavigationLink(destination: DebugLogsView()) {
        Label(
          String(localized: "view_error_logs", table: "Support"),
          systemImage: "exclamationmark.triangle")
      }
    }

    // MARK: - 高度な設定
    Section {
      DisclosureGroup(
        String(localized: "advanced_settings", table: "Settings"),
        isExpanded: $isAdvancedExpanded
      ) {
        VStack(spacing: 16) {
          // 分析データの計算基準
          Picker(
            String(localized: "analysis_source", table: "Settings"),
            selection: $appSettings.analysisDataSource
          ) {
            ForEach(AppSettings.AnalysisDataSource.allCases) { source in
              Text(source.localizedName).tag(source)
            }
          }
          .pickerStyle(.menu)
          .padding(.top, 4)

          Divider()

          // 共有インポート時にアプリを開くかどうか
          Toggle(
            String(localized: "open_app_after_share_import", table: "Settings"),
            isOn: $appSettings.openAppAfterShareImport
          )
          .padding(.top, 8)

          Text(String(localized: "open_app_after_share_import_description", table: "Settings"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)

          Toggle(
            String(localized: "enable_capacity_validation", table: "Settings"),
            isOn: $appSettings.enableCapacityValidation
          )

          if appSettings.enableCapacityValidation {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text(String(localized: "validation_threshold", table: "Settings"))
                Spacer()
                Text(String(format: "%.1f x", appSettings.capacityValidationThreshold))
                  .monospacedDigit()
                  .foregroundStyle(.secondary)
              }
              Slider(value: $appSettings.capacityValidationThreshold, in: 2...20, step: 0.5)
            }

            Picker(
              String(localized: "mismatch_behavior", table: "Settings"),
              selection: $appSettings.mismatchBehavior
            ) {
              ForEach(AppSettings.MismatchBehavior.allCases) { behavior in
                Text(behavior.localizedName).tag(behavior)
              }
            }
          }

          Text(String(localized: "validation_threshold_description", table: "Settings"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)

          Divider()

          // 重複したログの記録を許可
          Toggle(
            String(localized: "allow_duplicate_records", table: "Settings"),
            isOn: $appSettings.allowDuplicateRecords
          )
          .padding(.top, 8)

          Text(String(localized: "allow_duplicate_records_description", table: "Settings"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)

          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text(String(localized: "icloud_storage_threshold", table: "Settings"))
              Spacer()
              Text(String(format: "%.0f MB", appSettings.iCloudStorageThresholdMB))
                .foregroundStyle(.secondary)
            }
            Slider(value: $appSettings.iCloudStorageThresholdMB, in: 10...1024, step: 10)
          }

          if let blocked = appSettings.iCloudSyncBlockedReason {
            Text(blocked)
              .font(.caption)
              .foregroundColor(.red)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
      }
    }

    // MARK: - アプリについて
    Section {
      NavigationLink(destination: AboutView()) {
        Label(String(localized: "about_app", table: "Settings"), systemImage: "info.circle")
      }
    }
  }

  private func deleteAllRecords() {
    // modelContextから直接フェッチして削除
    let descriptor = FetchDescriptor<BatteryRecord>()
    guard let allRecords = try? modelContext.fetch(descriptor) else { return }
    for record in allRecords {
      modelContext.delete(record)
    }
    try? modelContext.save()

    // Remove any persisted shared log fallback
    UserDefaults.standard.removeObject(forKey: "PendingSharedLogText")
    UserDefaults.standard.removeObject(forKey: "PendingSharedLogSilent")

    // Notify other components (HomeView etc.) to clear transient UI state
    NotificationCenter.default.post(
      name: NSNotification.Name("DeleteAllDataPerformed"), object: nil)
  }

  private func deleteRecordsForDevice(_ deviceName: String) {
    // modelContextから直接フェッチして削除
    let descriptor = FetchDescriptor<BatteryRecord>(
      predicate: #Predicate { $0.deviceName == deviceName })
    guard let recordsToDelete = try? modelContext.fetch(descriptor) else { return }
    for record in recordsToDelete {
      modelContext.delete(record)
    }
    try? modelContext.save()

    // Notify other components (HomeView etc.) to clear transient UI state
    NotificationCenter.default.post(
      name: NSNotification.Name("DeleteAllDataPerformed"), object: nil)
  }

  private func setupShortcutNotification() {
    NotificationCenter.default.addObserver(
      forName: NSNotification.Name("ShortcutNotFound"),
      object: nil,
      queue: .main
    ) { _ in
      // ショートカットが見つからない場合はセットアップ誘導アラートを表示
      showingShortcutSetupPrompt = true
    }
  }

  // MARK: - エクスポート/インポート処理

  /// エクスポート用YAMLを生成
  private func generateExportYAML() -> String {
    do {
      return try DataExportService.exportToYAML(records: records)
    } catch {
      return "# Export failed: \(error.localizedDescription)"
    }
  }

  /// エクスポート結果を処理
  private func handleExportResult(_ result: Result<URL, Error>) {
    switch result {
    case .success:
      // 成功時は特に何もしない（システムが保存完了を通知）
      break
    case .failure(let error):
      exportErrorMessage = error.localizedDescription
      showingExportError = true
    }
  }

  /// インポート結果を処理
  private func handleImportResult(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first else { return }

      Task {
        // セキュリティスコープ付きリソースへのアクセスを開始
        guard url.startAccessingSecurityScopedResource() else {
          await MainActor.run {
            importResultMessage =
              String(
                localized: "import_error",
                table: "Settings"
              ) + ": ファイルへのアクセス権限がありません"
            showingImportAlert = true
          }
          return
        }

        defer {
          url.stopAccessingSecurityScopedResource()
        }

        do {
          let importResult = try DataImportService.importFromYAML(
            url: url,
            modelContext: modelContext,
            existingRecords: records,
            allowDuplicates: appSettings.allowDuplicateRecords
          )

          await MainActor.run {
            if importResult.hasErrors {
              importResultMessage = String(
                localized: "import_partial_success",
                table: "Settings"
              ).replacingOccurrences(of: "{imported}", with: "\(importResult.importedRecords)")
                .replacingOccurrences(of: "{skipped}", with: "\(importResult.skippedDuplicates)")
                .replacingOccurrences(of: "{errors}", with: "\(importResult.errors.count)")
            } else if importResult.skippedDuplicates > 0 {
              importResultMessage = String(
                localized: "import_success_with_duplicates",
                table: "Settings"
              ).replacingOccurrences(of: "{imported}", with: "\(importResult.importedRecords)")
                .replacingOccurrences(of: "{skipped}", with: "\(importResult.skippedDuplicates)")
            } else {
              importResultMessage = String(
                localized: "import_success",
                table: "Settings"
              ).replacingOccurrences(of: "{count}", with: "\(importResult.importedRecords)")
            }
            showingImportAlert = true
          }
        } catch {
          await MainActor.run {
            importResultMessage =
              String(
                localized: "import_error",
                table: "Settings"
              ) + ": \(error.localizedDescription)"
            showingImportAlert = true
          }
        }
      }

    case .failure(let error):
      importResultMessage =
        String(
          localized: "import_error",
          table: "Settings"
        ) + ": \(error.localizedDescription)"
      showingImportAlert = true
    }
  }
}

private struct SettingsCardGroupBoxStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      configuration.label
      configuration.content
    }
    .padding()
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color(.secondarySystemGroupedBackground))
    )
  }
}

#Preview {
  SettingsView()
    .modelContainer(for: BatteryRecord.self, inMemory: true)
}
