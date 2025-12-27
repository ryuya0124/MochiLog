import Charts
import SwiftData
// HomeView.swift
// 別ファイルへ分離
import SwiftUI
import UniformTypeIdentifiers

// MARK: - メインタブビュー
struct MainTabView: View {
  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    TabView(selection: $appSettings.selectedTabIndex) {
      HomeView()
        .tabItem {
          Label(String(localized: "tab_home"), systemImage: "house.fill")
        }
        .tag(0)
      AnalyticsView()
        .tabItem {
          Label(String(localized: "tab_analytics"), systemImage: "chart.line.uptrend.xyaxis")
        }
        .tag(1)
      SettingsView()
        .tabItem {
          Label(String(localized: "tab_settings"), systemImage: "gearshape.fill")
        }
        .tag(2)
    }
    .tint(appSettings.accentColor.color)
  }
}

// MARK: - ホームビュー本体
struct HomeView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Query(sort: \BatteryRecord.logDate, order: .reverse) private var records: [BatteryRecord]
  @StateObject private var appSettings = AppSettings.shared

  @State private var showingFilePicker = false
  @State var showingErrorAlert = false
  @State var errorMessage = ""
  @State var selectedRecord: BatteryRecord?
  /// iPadでナビゲーションによる詳細表示に使用する
  @State private var navigatingRecord: BatteryRecord?
  @State private var pendingParseResult: LogParser.ParseResult?
  @State private var showingWatchSelection = false
  @State var isProcessing = false
  @State private var showingMismatchAlert = false
  @State private var showingManualDevicePicker = false
  @State private var showingRegisterWatchAlert = false
  @State private var watchNameToRegister = ""
  @State private var showingParseErrorSavedAlert = false
  @State private var showingDebugLogsSheet = false
  @State private var showingReorderSheet = false

  /// 処理済みのログハッシュとタイムスタンプ（複数インスタンスで共有）

  private static var lastProcessedLogHash: Int?
  private static var lastProcessedTime: Date?

  /// 直近に追加されたログのキャッシュ（ログ日時: 追加時刻）。
  /// SwiftDataの反映ラグによる多重追加を防ぐために使用。
  private static var recentlyAddedLogs: [String: Date] = [:]

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
          UTType(filenameExtension: "syned")!,
        ],
        allowsMultipleSelection: true
      ) { result in
        Task {
          await handleFileImport(result: result)
        }
      }
      .alert(String(localized: "error"), isPresented: $showingErrorAlert) {
        Button(String(localized: "ok"), role: .cancel) {}
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
          return
        }

        // UserDefaultsをクリア（onAppearでの重複処理を防止）
        UserDefaults.standard.removeObject(forKey: "PendingSharedLogText")
        UserDefaults.standard.removeObject(forKey: "PendingSharedLogSilent")
        UserDefaults.standard.synchronize()

        // Determine whether we should process silently (don't show UI)
        let silent = (notification.userInfo?["silent"] as? Bool) ?? false
        print("[HomeView] Processing shared log, silent=\(silent)")
        processLogTextAsync(text, silent: silent)
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
        showingParseErrorSavedAlert = true
      }
      .alert(String(localized: "log_saved"), isPresented: $showingParseErrorSavedAlert) {
        Button(String(localized: "view_log")) {
          showingDebugLogsSheet = true
        }
        Button(String(localized: "ok"), role: .cancel) {}
      } message: {
        Text(String(localized: "log_saved_message"))
      }
      .sheet(isPresented: $showingDebugLogsSheet) {
        DebugLogsView()
      }
      .onAppear {
        reconcileUnknownDeviceNames()
        reconcileMissingDesignCapacities()
        // If a shared log was persisted before HomeView appeared, process it now
        // This is a fallback when the Notification observer wasn't ready
        if let pending = UserDefaults.standard.string(forKey: "PendingSharedLogText") {
          // UserDefaultsのクリアのみ行う（重複判定はMochiLogAppに任せる）
          // ただし念の為、前の処理から極端に短い場合はスキップしても良いが、
          // ここではシンプルに処理を通す
          let silent = UserDefaults.standard.bool(forKey: "PendingSharedLogSilent")
          UserDefaults.standard.removeObject(forKey: "PendingSharedLogText")
          UserDefaults.standard.removeObject(forKey: "PendingSharedLogSilent")
          UserDefaults.standard.synchronize()

          print("[HomeView] onAppear: Processing pending log, silent=\(silent)")
          processLogTextAsync(pending, silent: silent)
        }
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
            try? modelContext.save()
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
      .alert(String(localized: "register_watch_title"), isPresented: $showingRegisterWatchAlert) {
        Button(String(localized: "register")) {
          appSettings.registeredWatchModel = watchNameToRegister
        }
        Button(String(localized: "cancel"), role: .cancel) {}
      } message: {
        Text(String(localized: "register_watch_message"))
      }
      .alert(String(localized: "mismatch_warning_title"), isPresented: $showingMismatchAlert) {
        Button(String(localized: "select_manually")) {
          showingManualDevicePicker = true
        }
        Button(String(localized: "cancel"), role: .cancel) {
          pendingParseResult = nil
        }
      } message: {
        Text(String(localized: "mismatch_warning_message"))
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
            try? modelContext.save()
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
    GeometryReader { geometry in
      VStack(spacing: 16) {
        ContentUnavailableView {
          Label(String(localized: "no_data"), systemImage: "battery.0")
        } description: {
          Text(String(localized: "no_data_description"))
        } actions: {
          Button {
            withAnimation {
              appSettings.showingSampleData = true
            }
          } label: {
            Label(String(localized: "view_sample_data"), systemImage: "eye")
          }
          .buttonStyle(.borderedProminent)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
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
        Text(String(localized: "parsing_log"))
          .font(.headline)
          .foregroundColor(.white)
      }
      .padding(32)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
  }

  // --- 以下のメソッドは HomeView+Import.swift へ分離済み ---
  // handleFileImport, recursiveContentsOfFolder, extractZipContents
  // --- 以下のサブビュー/ユーティリティも RecordViews.swift, ZipArchiveHelper.swift へ分離済み ---

  // 残すべき内部ロジック
  private func processLogTextAsync(_ text: String, silent: Bool = false) {
    isProcessing = true

    let enableValidation = AppSettings.shared.enableCapacityValidation
    let threshold = AppSettings.shared.capacityValidationThreshold

    DispatchQueue.global(qos: .userInitiated).async {
      let parseResult = LogParser.parse(
        text: text,
        enableValidation: enableValidation,
        validationThreshold: threshold
      )

      DispatchQueue.main.async {
        isProcessing = false

        // UI更新（アラート表示や画面遷移）のために少し遅延させる
        // iPadではOverlayが消えるのと遷移が競合すると詳細画面が開かないことがあるため
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          if !silent {
            // Normal interactive flow: existing behavior
            if let newRecord = self.addRecordFromParseResult(parseResult) {
              self.showRecordDetail(newRecord)
            }
            return
          }

          // Silent mode flow
          self.handleSilentImport(parseResult)
        }
      }
    }
  }

  private func handleSilentImport(_ parseResult: LogParser.ParseResult) {
    // Silent mode flow: do not present UI; just insert if possible and notify result
    // Check basic parse validity
    let canCreate =
      (parseResult.logDate != nil) && (parseResult.cycleCount != nil)
      && (parseResult.nominalCapacity != nil) && (parseResult.rawCapacity != nil)

    if !canCreate {
      NotificationHelper.scheduleImportResultNotification(
        title: String(localized: "import_silent_failure"),
        body: String(localized: "parse_error")
      )
      self.redirectToSettingsAfterSilentImport()
      return
    }

    // Capacity mismatch handling
    if parseResult.isCapacityMismatch && AppSettings.shared.mismatchBehavior == .error {
      NotificationHelper.scheduleImportResultNotification(
        title: String(localized: "import_silent_failure"),
        body: String(localized: "capacity_mismatch_error")
      )
      self.redirectToSettingsAfterSilentImport()
      return
    }

    // Device resolution (moved before duplicate check)
    var deviceName = "Unknown"
    var deviceModelCodeToUse: String? =
      parseResult.detectedIdentifier ?? parseResult.deviceModelCode
    if let id = deviceModelCodeToUse,
      let resolved = DeviceLibrary.getDeviceName(for: id)
    {
      deviceName = resolved
    }

    if deviceName == "Unknown" {
      if let localId = DeviceLibrary.localModelIdentifier(),
        let resolved = DeviceLibrary.getDeviceName(for: localId)
      {
        deviceName = resolved
        deviceModelCodeToUse = localId
      }
    }

    let isWatchOS = parseResult.osVersion?.lowercased().contains("watch") ?? false
    let looksLikeWatch = deviceName.contains("Apple Watch")

    if isWatchOS || looksLikeWatch {
      if let registeredWatch = AppSettings.shared.registeredWatchModel {
        // iPad共有シートバグによるファントム重複チェック（設定無視）
        if let logDate = parseResult.logDate,
          isPhantomDuplicate(on: logDate, deviceName: registeredWatch)
        {
          // 重複通知は出さずにサイレント成功扱い（または無視）して終了
          // ただしユーザーのリクエストにより、重複通知を出す必要がある場合はここも変更検討
          // 共有シートからのサイレントインポートの場合、UIが出ないので通知で知らせる
          NotificationHelper.scheduleImportResultNotification(
            title: String(localized: "import_silent_failure"),
            body: String(localized: "duplicate_record")
          )
          self.redirectToSettingsAfterSilentImport()
          return
        }

        // Watchの場合は登録されたWatchモデル名で重複チェック（許可設定がオフの場合のみ）
        if !AppSettings.shared.allowDuplicateRecords,
          let logDate = parseResult.logDate,
          hasDuplicateRecord(on: logDate, deviceName: registeredWatch)
        {
          NotificationHelper.scheduleImportResultNotification(
            title: String(localized: "import_silent_failure"),
            body: String(localized: "duplicate_record")
          )
          self.redirectToSettingsAfterSilentImport()
          return
        }
        // Use registered watch
        let registeredModelCode =
          DeviceLibrary.getIdentifierForDeviceName(registeredWatch) ?? deviceModelCodeToUse
        let registeredDesignCap = DeviceLibrary.getCapacity(for: registeredWatch)
        let record = createRecord(
          from: parseResult,
          deviceName: registeredWatch,
          deviceModelCodeOverride: registeredModelCode,
          designCapacityOverride: registeredDesignCap
        )
        withAnimation(.snappy) {
          modelContext.insert(record)
          try? modelContext.save()
          // キャッシュに追加
          let key = "\(record.logDate.timeIntervalSince1970)_\(registeredWatch)"
          HomeView.recentlyAddedLogs[key] = Date()
        }

        // Notify success
        let body = String(
          format: String(localized: "import_silent_success_body"), registeredWatch,
          DateFormatter.localizedString(
            from: record.logDate, dateStyle: .medium, timeStyle: .short))
        NotificationHelper.scheduleImportResultNotification(
          title: String(localized: "import_silent_success"), body: body)
        self.redirectToSettingsAfterSilentImport()
        return
      } else {
        // Requires manual selection -> notify failure requiring user action
        NotificationHelper.scheduleImportResultNotification(
          title: String(localized: "import_silent_failure"),
          body: String(localized: "watch_selection_required")
        )
        self.redirectToSettingsAfterSilentImport()
        return
      }
    }

    // iPad共有シートバグによるファントム重複チェック（設定無視）
    // Watch以外のデバイスの場合も同様にチェック
    if let logDate = parseResult.logDate,
      isPhantomDuplicate(on: logDate, deviceName: deviceName)
    {
      NotificationHelper.scheduleImportResultNotification(
        title: String(localized: "import_silent_failure"),
        body: String(localized: "duplicate_record")
      )
      self.redirectToSettingsAfterSilentImport()
      return
    }

    // 通常デバイス（iPhone/iPad）の重複チェック（許可設定がオフの場合のみ）
    if !AppSettings.shared.allowDuplicateRecords,
      let logDate = parseResult.logDate,
      hasDuplicateRecord(on: logDate, deviceName: deviceName)
    {
      NotificationHelper.scheduleImportResultNotification(
        title: String(localized: "import_silent_failure"),
        body: String(localized: "duplicate_record")
      )
      self.redirectToSettingsAfterSilentImport()
      return
    }

    // Normal-device flow
    let designCap = DeviceLibrary.getCapacity(for: deviceName)
    let record = createRecord(
      from: parseResult,
      deviceName: deviceName,
      deviceModelCodeOverride: deviceModelCodeToUse,
      designCapacityOverride: designCap
    )
    withAnimation(.snappy) {
      modelContext.insert(record)
      try? modelContext.save()
      // キャッシュに追加
      let key = "\(record.logDate.timeIntervalSince1970)_\(deviceName)"
      HomeView.recentlyAddedLogs[key] = Date()
    }

    let body = String(
      format: String(localized: "import_silent_success_body"), deviceName,
      DateFormatter.localizedString(from: record.logDate, dateStyle: .medium, timeStyle: .short)
    )
    NotificationHelper.scheduleImportResultNotification(
      title: String(localized: "import_silent_success"), body: body)
    self.redirectToSettingsAfterSilentImport()
  }

  func addRecordFromParseResult(_ result: LogParser.ParseResult) -> BatteryRecord? {
    guard let logDate = result.logDate,
      result.cycleCount != nil,
      result.nominalCapacity != nil,
      result.rawCapacity != nil
    else {
      errorMessage = String(localized: "parse_error")
      showingErrorAlert = true
      return nil
    }

    if result.isCapacityMismatch {
      if appSettings.mismatchBehavior == .error {
        errorMessage = String(localized: "capacity_mismatch_error")
        showingErrorAlert = true
        return nil
      } else {
        pendingParseResult = result
        showingMismatchAlert = true
        return nil
      }
    }

    var deviceName = "Unknown"
    var deviceModelCodeToUse: String? = result.detectedIdentifier ?? result.deviceModelCode
    if let id = deviceModelCodeToUse,
      let resolved = DeviceLibrary.getDeviceName(for: id)
    {
      deviceName = resolved
    }

    if deviceName == "Unknown" {
      if let localId = DeviceLibrary.localModelIdentifier(),
        let resolved = DeviceLibrary.getDeviceName(for: localId)
      {
        deviceName = resolved
        deviceModelCodeToUse = localId
      }
    }

    let isWatchOS = result.osVersion?.lowercased().contains("watch") ?? false
    let looksLikeWatch = deviceName.contains("Apple Watch")

    if isWatchOS || looksLikeWatch {
      if let registeredWatch = appSettings.registeredWatchModel {
        // Watchの場合は登録されたWatchモデル名で重複チェック（許可設定がオフの場合のみ）
        if !appSettings.allowDuplicateRecords
          && hasDuplicateRecord(on: logDate, deviceName: registeredWatch)
        {
          errorMessage = String(localized: "duplicate_record")
          showingErrorAlert = true
          return nil
        }
        let registeredModelCode =
          DeviceLibrary.getIdentifierForDeviceName(registeredWatch) ?? deviceModelCodeToUse
        let registeredDesignCap = DeviceLibrary.getCapacity(for: registeredWatch)
        let newRecord = createRecord(
          from: result,
          deviceName: registeredWatch,
          deviceModelCodeOverride: registeredModelCode,
          designCapacityOverride: registeredDesignCap
        )
        withAnimation(.snappy) {
          modelContext.insert(newRecord)
          try? modelContext.save()
          // キャッシュに追加して直後の重複を弾く
          let key = "\(newRecord.logDate.timeIntervalSince1970)_\(registeredWatch)"
          HomeView.recentlyAddedLogs[key] = Date()
        }
        return newRecord
      }
      pendingParseResult = result
      showingWatchSelection = true
      return nil
    }

    // iPadの共有シートバグによる多重登録を防ぐための厳密な重複チェック
    // 設定に関わらず、完全に同一の日付・デバイスのレコードが既に存在する場合は弾く
    // または、直近（数秒以内）に同じデバイスで同じ日付のログが追加されている場合も弾く
    if isPhantomDuplicate(on: logDate, deviceName: deviceName) {
      print("[HomeView] Phantom duplicate detected for \(deviceName) on \(logDate)")

      // システムバグ（3秒以内のファントム連打）か、ユーザーによる手動重複かを判定
      let isRecentPhantom = isRecentDuplicate(on: logDate, deviceName: deviceName, threshold: 3.0)

      if isRecentPhantom {
        // ファントム（直近の自動連打）の場合は、サイレントに無視する（成功したフリをして何もしない）
        // これにより、1回目の正規リクエストの詳細画面遷移を阻害しない
        print("[HomeView] Silently ignoring phantom duplicate within 3.0s")
        return nil
      } else {
        // 時間が経ってからの重複は、ユーザーが間違って追加した可能性が高いので警告を出す
        errorMessage = String(localized: "duplicate_record")
        showingErrorAlert = true
        return nil
      }
    }

    // 通常デバイス（iPhone/iPad）の重複チェック（ユーザー設定に基づく）
    if !appSettings.allowDuplicateRecords && hasDuplicateRecord(on: logDate, deviceName: deviceName)
    {
      errorMessage = String(localized: "duplicate_record")
      showingErrorAlert = true
      return nil
    }

    let designCap = DeviceLibrary.getCapacity(for: deviceName)
    let newRecord = createRecord(
      from: result,
      deviceName: deviceName,
      deviceModelCodeOverride: deviceModelCodeToUse,
      designCapacityOverride: designCap
    )
    withAnimation(.snappy) {
      modelContext.insert(newRecord)
      try? modelContext.save()
      // キャッシュに追加して直後の重複を弾く
      let key = "\(newRecord.logDate.timeIntervalSince1970)_\(deviceName)"
      HomeView.recentlyAddedLogs[key] = Date()
    }
    return newRecord
  }

  private func createRecord(
    from result: LogParser.ParseResult,
    deviceName: String,
    deviceModelCodeOverride: String? = nil,
    designCapacityOverride: Int? = nil
  ) -> BatteryRecord {
    let logDate = result.logDate ?? Date()
    let modelCodeUsed = deviceModelCodeOverride ?? result.deviceModelCode
    let designCapacityUsed = designCapacityOverride ?? result.designCapacity ?? 0
    let record = BatteryRecord(
      logDate: logDate,
      deviceName: deviceName,
      deviceModelCode: modelCodeUsed,
      osVersion: result.osVersion,
      storage: result.storage,
      ram: result.ram,
      manufactureDate: nil,
      firstUseDate: result.firstUseDate,
      cycleCount: result.cycleCount ?? 0,
      designCapacity: designCapacityUsed,
      nominalCapacity: result.nominalCapacity ?? 0,
      rawCapacity: result.rawCapacity ?? 0,
      lowRateCapacity: result.lowRateCapacity,
      deflator: result.deflator,
      settingsDisplayPercent: result.settingsDisplayPercent,
      diagnosticResult: result.diagnosticResult,
      avgTemp: result.avgTemp,
      maxTemp: result.maxTemp,
      minTemp: result.minTemp,
      maxVoltage: result.maxVoltage,
      minVoltage: result.minVoltage,
      minSoC: result.dailyMinSoC,
      maxSoC: result.dailyMaxSoC
    )

    // If diagnostic result is missing but we have a design capacity, compute it from raw
    if record.diagnosticResult == nil && designCapacityUsed > 0 && record.rawCapacity > 0 {
      let rawRatio = (Double(record.rawCapacity) / Double(designCapacityUsed)) * 100.0
      if rawRatio < 80.0 {
        record.diagnosticResult = String(localized: "diag_replace_recommended")
      } else if rawRatio < 90.0 {
        record.diagnosticResult = String(localized: "diag_slightly_degraded")
      } else {
        record.diagnosticResult = String(localized: "diag_normal")
      }
    }

    return record
  }

  private func deleteRecords(_ items: [BatteryRecord]) {
    withAnimation(.snappy) {
      for item in items {
        // 選択中のレコードが削除対象なら先に選択を解除
        if let selected = selectedRecord, selected === item {
          selectedRecord = nil
        }
        modelContext.delete(item)
      }
      // 保存して Query を更新（削除が UI に反映されるようにする）
      try? modelContext.save()
    }
  }

  /// 詳細画面を表示する（iPadではナビゲーション、iPhoneではシート）
  func showRecordDetail(_ record: BatteryRecord) {
    if horizontalSizeClass == .regular {
      navigatingRecord = record
    } else {
      selectedRecord = record
    }
  }

  /// silentインポート完了後に設定アプリにリダイレクトする
  /// 「アプリを開く」がオフの場合、ユーザーはアプリを見たくないので即座に元の画面に戻す
  private func redirectToSettingsAfterSilentImport() {
    // prefs: URLスキームで設定アプリの特定の画面に遷移
    // これによりアプリがバックグラウンドに移動し、ユーザーにとってはアプリが開かなかったように見える
    if let url = URL(string: "prefs:root=Privacy&path=PROBLEM_REPORTING/DIAGNOSTIC_USAGE_DATA") {
      UIApplication.shared.open(url)
    }
  }

  private func hasDuplicateRecord(on date: Date, deviceName: String) -> Bool {
    records.contains { existing in
      // 日付を「日単位」で比較（時刻は無視）
      let sameDate = Calendar.current.isDate(existing.logDate, inSameDayAs: date)
      guard sameDate else { return false }

      // デバイス名（機種名）で比較
      return existing.deviceName == deviceName
    }
  }

  /// iPadの共有シートバグによる瞬間的な多重登録を検知する
  private func isPhantomDuplicate(on date: Date, deviceName: String) -> Bool {
    // 1. 直近のキャッシュを確認 (SwiftData反映待ちのレコード)
    let key = "\(date.timeIntervalSince1970)_\(deviceName)"
    if let addedTime = HomeView.recentlyAddedLogs[key],
      Date().timeIntervalSince(addedTime) < 5.0
    {
      return true
    }

    // 2. 既存のレコードを確認
    return records.contains { existing in
      // 完全に同一の時刻、または極めて近い時刻（バグによる連打）をチェック
      let sameDevice = existing.deviceName == deviceName
      guard sameDevice else { return false }

      // ログの日付が「秒」まで完全に一致するか確認
      // LogParserは通常秒単位まで解析するため、同一ログファイルなら一致するはず
      let exactMatch = abs(existing.logDate.timeIntervalSince(date)) < 1.0

      return exactMatch
    }
  }

  /// 直近の重複かどうかをキャッシュから判定する
  private func isRecentDuplicate(on date: Date, deviceName: String, threshold: TimeInterval) -> Bool
  {
    let key = "\(date.timeIntervalSince1970)_\(deviceName)"
    if let addedTime = HomeView.recentlyAddedLogs[key],
      Date().timeIntervalSince(addedTime) < threshold
    {
      return true
    }
    return false
  }

  private func findExistingRecord(on date: Date, deviceName: String) -> BatteryRecord? {
    records.first { existing in
      let sameDevice = existing.deviceName == deviceName
      guard sameDevice else { return false }
      return abs(existing.logDate.timeIntervalSince(date)) < 1.0
    }
  }

  private func reconcileUnknownDeviceNames() {
    var needsSave = false
    for record in records {
      guard record.deviceName == "Unknown",
        let code = record.deviceModelCode,
        let resolved = DeviceLibrary.getDeviceName(for: code)
      else {
        continue
      }
      record.deviceName = resolved
      needsSave = true
    }
    if needsSave {
      try? modelContext.save()
    }
  }

  /// 起動時にライブラリに設計容量が登録されていない既存レコードを補完する
  private func reconcileMissingDesignCapacities() {
    var needsSave = false
    for record in records {
      // 0 は「未登録・情報なし」を表す (既存のコードとの互換性維持)
      guard record.designCapacity == 0 else { continue }

      // まずは model code から解決を試みる
      if let code = record.deviceModelCode,
        let resolvedName = DeviceLibrary.getDeviceName(for: code),
        let cap = DeviceLibrary.getCapacity(for: resolvedName),
        cap > 0
      {
        record.designCapacity = cap
        // 設計容量が埋まったら診断結果を再計算する
        if record.rawCapacity > 0 {
          let rawRatio = (Double(record.rawCapacity) / Double(cap)) * 100.0
          if rawRatio < 80.0 {
            record.diagnosticResult = String(localized: "diag_replace_recommended")
          } else if rawRatio < 90.0 {
            record.diagnosticResult = String(localized: "diag_slightly_degraded")
          } else {
            record.diagnosticResult = String(localized: "diag_normal")
          }
        }
        needsSave = true
        continue
      }

      // 次に deviceName から解決できるか試す
      if let cap = DeviceLibrary.getCapacity(for: record.deviceName), cap > 0 {
        record.designCapacity = cap
        if record.rawCapacity > 0 {
          let rawRatio = (Double(record.rawCapacity) / Double(cap)) * 100.0
          if rawRatio < 80.0 {
            record.diagnosticResult = String(localized: "diag_replace_recommended")
          } else if rawRatio < 90.0 {
            record.diagnosticResult = String(localized: "diag_slightly_degraded")
          } else {
            record.diagnosticResult = String(localized: "diag_normal")
          }
        }
        needsSave = true
      }
    }
    if needsSave { try? modelContext.save() }
  }
}
