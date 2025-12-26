import Charts
import SwiftData
// HomeView.swift
// 別ファイルへ分離
import SwiftUI
import UniformTypeIdentifiers

// MARK: - メインタブビュー
struct MainTabView: View {
  @StateObject private var appSettings = AppSettings.shared
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
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
  @Query(sort: \BatteryRecord.logDate, order: .reverse) private var records: [BatteryRecord]
  @StateObject private var appSettings = AppSettings.shared

  @State private var showingFilePicker = false
  @State var showingErrorAlert = false
  @State var errorMessage = ""
  @State var selectedRecord: BatteryRecord?
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var pendingParseResult: LogParser.ParseResult?
  @State private var showingWatchSelection = false
  @State var isProcessing = false
  @State private var showingMismatchAlert = false
  @State private var showingManualDevicePicker = false
  @State private var showingRegisterWatchAlert = false
  @State private var watchNameToRegister = ""
  @State private var showingParseErrorSavedAlert = false
  @State private var showingDebugLogsSheet = false

  var body: some View {
    NavigationStack {
      ZStack {
        VStack {
          if records.isEmpty {
            GeometryReader { proxy in
              ScrollView {
                VStack {
                  Spacer(minLength: 0)
                  ContentUnavailableView(
                    String(localized: "no_data"),
                    systemImage: "battery.0",
                    description: Text(String(localized: "no_data_description"))
                  )
                  Spacer(minLength: 0)
                }
                .frame(minHeight: proxy.size.height)
                .frame(maxWidth: .infinity)
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
          } else {
            List {
              ForEach(deviceSections) { section in
                Section(section.displayName) {
                  ForEach(section.records) { record in
                    if horizontalSizeClass == .regular {
                      NavigationLink(destination: RecordDetailView(record: record)) {
                        RecordRowView(record: record)
                      }
                    } else {
                      RecordRowView(record: record)
                        .contentShape(Rectangle())
                        .onTapGesture {
                          selectedRecord = record
                        }
                    }
                  }
                  .onDelete { offsets in
                    let items = offsets.map { section.records[$0] }
                    deleteRecords(items)
                  }
                }
              }
            }
          }
        }
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
      .navigationTitle("MochiLog")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { showingFilePicker = true }) {
            Image(systemName: "plus")
          }
          .disabled(isProcessing)
        }
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
      .sheet(item: $selectedRecord) { record in
        RecordDetailView(record: record)
      }
      .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProcessSharedLog")))
      { notification in
        if let text = notification.userInfo?["text"] as? String {
          // Determine whether we should process silently (don't show UI)
          let silent = (notification.userInfo?["silent"] as? Bool) ?? false
          // Remove persisted fallback and process
          UserDefaults.standard.removeObject(forKey: "PendingSharedLogText")
          UserDefaults.standard.removeObject(forKey: "PendingSharedLogSilent")
          processLogTextAsync(text, silent: silent)
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
      .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ParseErrorSaved")))
      { _ in
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
        if let pending = UserDefaults.standard.string(forKey: "PendingSharedLogText") {
          let silent = UserDefaults.standard.bool(forKey: "PendingSharedLogSilent")
          UserDefaults.standard.removeObject(forKey: "PendingSharedLogText")
          UserDefaults.standard.removeObject(forKey: "PendingSharedLogSilent")
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
          modelContext.insert(record)
          try? modelContext.save()
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
          modelContext.insert(record)
          try? modelContext.save()
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

        if !silent {
          // Normal interactive flow: existing behavior
          if let newRecord = addRecordFromParseResult(parseResult) {
            selectedRecord = newRecord
          }
          return
        }

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

        // Duplicate check (after device name is resolved)
        if let logDate = parseResult.logDate,
          hasDuplicateRecord(on: logDate, deviceName: deviceName)
        {
          NotificationHelper.scheduleImportResultNotification(
            title: String(localized: "import_silent_failure"),
            body: String(localized: "duplicate_record")
          )
          self.redirectToSettingsAfterSilentImport()
          return
        }

        let isWatchOS = parseResult.osVersion?.lowercased().contains("watch") ?? false
        let looksLikeWatch = deviceName.contains("Apple Watch")

        if isWatchOS || looksLikeWatch {
          if let registeredWatch = AppSettings.shared.registeredWatchModel {
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
            modelContext.insert(record)
            try? modelContext.save()

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

        // Normal-device flow
        let designCap = DeviceLibrary.getCapacity(for: deviceName)
        let record = createRecord(
          from: parseResult,
          deviceName: deviceName,
          deviceModelCodeOverride: deviceModelCodeToUse,
          designCapacityOverride: designCap
        )
        modelContext.insert(record)
        try? modelContext.save()

        let body = String(
          format: String(localized: "import_silent_success_body"), deviceName,
          DateFormatter.localizedString(from: record.logDate, dateStyle: .medium, timeStyle: .short)
        )
        NotificationHelper.scheduleImportResultNotification(
          title: String(localized: "import_silent_success"), body: body)
        self.redirectToSettingsAfterSilentImport()
      }
    }
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

    // Duplicate check (after device name is resolved)
    if hasDuplicateRecord(on: logDate, deviceName: deviceName) {
      errorMessage = String(localized: "duplicate_record")
      showingErrorAlert = true
      return nil
    }

    let isWatchOS = result.osVersion?.lowercased().contains("watch") ?? false
    let looksLikeWatch = deviceName.contains("Apple Watch")

    if isWatchOS || looksLikeWatch {
      if let registeredWatch = appSettings.registeredWatchModel {
        let registeredModelCode =
          DeviceLibrary.getIdentifierForDeviceName(registeredWatch) ?? deviceModelCodeToUse
        let registeredDesignCap = DeviceLibrary.getCapacity(for: registeredWatch)
        let newRecord = createRecord(
          from: result,
          deviceName: registeredWatch,
          deviceModelCodeOverride: registeredModelCode,
          designCapacityOverride: registeredDesignCap
        )
        modelContext.insert(newRecord)
        try? modelContext.save()
        return newRecord
      }
      pendingParseResult = result
      showingWatchSelection = true
      return nil
    }

    let designCap = DeviceLibrary.getCapacity(for: deviceName)
    let newRecord = createRecord(
      from: result,
      deviceName: deviceName,
      deviceModelCodeOverride: deviceModelCodeToUse,
      designCapacityOverride: designCap
    )
    modelContext.insert(newRecord)
    try? modelContext.save()
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
    withAnimation {
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

  private var deviceSections: [DeviceSection] {
    var sections: [DeviceSection] = []
    var indexForDevice: [String: Int] = [:]
    for record in records {
      let name = record.deviceName
      if let index = indexForDevice[name] {
        sections[index].records.append(record)
      } else {
        indexForDevice[name] = sections.count
        sections.append(DeviceSection(id: name, displayName: name, records: [record]))
      }
    }
    return sections
  }

  private struct DeviceSection: Identifiable {
    let id: String
    let displayName: String
    var records: [BatteryRecord]
  }
}
