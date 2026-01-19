import SwiftData
import SwiftUI

// MARK: - 設定ビュー
struct SettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Query private var records: [BatteryRecord]
  @StateObject private var appSettings = AppSettings.shared

  @State private var showingWatchPicker = false
  @State private var showingDeleteConfirmation = false
  @State private var showingNoDataToDeleteAlert = false
  @State private var showingRemoveWatchConfirmation = false
  @State private var showingTutorial = false
  @State private var showingSupportForm = false
  @State private var showingDonation = false
  @State private var showingDeleteDeviceConfirmation = false
  @State private var deletingDeviceId: String? = nil
  @State private var isAdvancedExpanded = false

  // iCloud トグル用ローカル状態とエラー表示
  @State private var localICloudToggle: Bool = false
  @State private var showingICloudErrorAlert = false
  @State private var iCloudErrorMessage: String = ""

  // デバイスごとの削除機能用の状態
  @State private var showingDeviceDeletePicker = false
  @State private var showingDeviceDeleteConfirmation = false
  @State private var selectedDeviceToDelete: String?

  // 大画面レイアウト用: 選択されたカテゴリ
  @State private var selectedCategory: SettingsCategory = .general

  var body: some View {
    NavigationStack {
      settingsList
        .navigationTitle(String(localized: "settings", table: "Settings"))
        .onAppear { localICloudToggle = appSettings.iCloudSyncEnabled }
        .sheet(isPresented: $showingWatchPicker) {
          HierarchicalDevicePickerView(initialCategory: .watch, lockCategory: true) {
            name, identifier in
            appSettings.registerWatch(model: name)
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
          Button(String(localized: "remove_watch", table: "Settings"), role: .destructive) {
            appSettings.unregisterWatch()
          }
        } message: {
          Text(String(localized: "remove_watch_confirm", table: "Settings"))
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
    }
  }

  // MARK: - iPad/iPhone向けList
  @ViewBuilder
  private var settingsList: some View {
    if horizontalSizeClass == .regular {
      // iPad: 2カラムレイアウト（左:カテゴリカード、右:詳細）
      HStack(spacing: 0) {
        categoriesColumn
          .frame(width: 300)

        Divider()

        // 右側：選択されたカテゴリの詳細
        detailColumn(category: selectedCategory)
      }
    } else {
      // iPhone: 通常のList
      List {
        settingsContent
      }
    }
  }

  // MARK: - カテゴリカラム（iPad専用）
  @ViewBuilder
  private var categoriesColumn: some View {
    ScrollView {
      VStack(spacing: 16) {
        ForEach(SettingsCategory.allCases) { category in
          CategoryCardView(
            category: category,
            isSelected: selectedCategory == category
          )
          .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
              selectedCategory = category
            }
          }
        }
      }
      .padding()
    }
    .background(Color(.systemGroupedBackground))
  }

  // MARK: - 詳細カラム（iPad専用）
  // MARK: - 詳細カラム（選択されたカテゴリの内容）
  @ViewBuilder
  private func detailColumn(category: SettingsCategory) -> some View {
    ScrollView {
      VStack(spacing: 0) {
        switch category {
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
            showingRemoveWatchConfirmation: $showingRemoveWatchConfirmation,
            appSettings: appSettings
          )
        case .dataManagement:
          DataManagementSettingsView(
            showingDeleteAllConfirmation: $showingDeleteConfirmation,
            showingDeleteDeviceConfirmation: $showingDeleteDeviceConfirmation,
            deletingDeviceId: $deletingDeviceId,
            appSettings: appSettings
          )
        case .support:
          SupportSettingsView()
        case .debug:
          DebugSettingsView(appSettings: appSettings)
        case .advanced:
          AdvancedSettingsView(appSettings: appSettings)
        }
      }
      .padding(.top)
    }
    .background(Color(.systemGroupedBackground))
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

    // MARK: - Apple Watch 設定
    Section {
      HStack {
        Label(
          String(localized: "registered_watch", table: "Settings"), systemImage: "applewatch")
        Spacer()
        Text(
          appSettings.registeredWatchModel
            ?? String(localized: "not_registered", table: "Settings")
        )
        .foregroundStyle(.secondary)
      }

      Button(action: { showingWatchPicker = true }) {
        Label(
          appSettings.registeredWatchModel == nil
            ? String(localized: "register_watch", table: "Settings")
            : String(localized: "change_watch", table: "Settings"),
          systemImage: "plus.circle"
        )
      }

      if appSettings.registeredWatchModel != nil {
        Button(role: .destructive, action: { showingRemoveWatchConfirmation = true }) {
          Label(
            String(localized: "remove_watch", table: "Settings"), systemImage: "minus.circle")
        }
      }
    } header: {
      Text(String(localized: "apple_watch_settings", table: "Settings"))
    } footer: {
      Text(String(localized: "watch_selection_description", table: "Settings"))
    }

    // MARK: - データ管理
    Section(String(localized: "data_management", table: "Settings")) {
      Button(role: .destructive) {
        if records.isEmpty {
          showingNoDataToDeleteAlert = true
        } else {
          showingDeleteConfirmation = true
        }
      } label: {
        Label(
          String(localized: "delete_all_data", table: "Settings"), systemImage: "trash.fill")
      }

      Button(role: .destructive) {
        if availableDevices.isEmpty {
          showingNoDataToDeleteAlert = true
        } else {
          showingDeviceDeletePicker = true
        }
      } label: {
        Label(String(localized: "delete_device_data", table: "Settings"), systemImage: "trash")
      }
    }

    // MARK: - サポート
    Section(String(localized: "support", table: "Settings")) {
      Button(action: { showingTutorial = true }) {
        Label(String(localized: "view_tutorial", table: "Home"), systemImage: "book.fill")
      }

      Button(action: { showingSupportForm = true }) {
        Label(
          String(localized: "contact_support", table: "Support"), systemImage: "envelope.fill")
      }

      Button(action: { showingDonation = true }) {
        Label(String(localized: "donation_title", table: "Settings"), systemImage: "heart.fill")
      }
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

  private var availableDevices: [String] {
    Array(Set(records.map { $0.deviceName })).sorted()
  }

  private func deleteAllRecords() {
    for record in records {
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
    let recordsToDelete = records.filter { $0.deviceName == deviceName }
    for record in recordsToDelete {
      modelContext.delete(record)
    }
    try? modelContext.save()

    // Notify other components (HomeView etc.) to clear transient UI state
    NotificationCenter.default.post(
      name: NSNotification.Name("DeleteAllDataPerformed"), object: nil)
  }
}

#Preview {
  SettingsView()
    .modelContainer(for: BatteryRecord.self, inMemory: true)
}
