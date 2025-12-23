import Charts
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - メインタブビュー
struct MainTabView: View {
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
    .tint(.green)
  }
}

// MARK: - ホームビュー
struct HomeView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \BatteryRecord.logDate, order: .reverse) private var records: [BatteryRecord]
  @StateObject private var appSettings = AppSettings.shared

  @State private var showingFilePicker = false
  @State private var showingErrorAlert = false
  @State private var errorMessage = ""
  @State private var selectedRecord: BatteryRecord?
  @State private var pendingParseResult: LogParser.ParseResult?
  @State private var showingWatchSelection = false
  @State private var isProcessing = false

  @State private var showingMismatchAlert = false
  @State private var showingManualDevicePicker = false

  @State private var showingRegisterWatchAlert = false
  @State private var watchNameToRegister = ""

  var body: some View {
    NavigationStack {
      ZStack {
        VStack {
          if records.isEmpty {
            ContentUnavailableView(
              String(localized: "no_data"),
              systemImage: "battery.0",
              description: Text(String(localized: "no_data_description"))
            )
          } else {
            List {
              ForEach(deviceSections) { section in
                Section(section.displayName) {
                  ForEach(section.records) { record in
                    RecordRowView(record: record)
                      .contentShape(Rectangle())
                      .onTapGesture {
                        selectedRecord = record
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

        // 処理中オーバーレイ
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
        allowedContentTypes: [.json, .plainText, .data],
        allowsMultipleSelection: false
      ) { result in
        handleFileImport(result: result)
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
          processLogTextAsync(text)
        }
      }
      .onAppear {
        reconcileUnknownDeviceNames()
      }
      .sheet(isPresented: $showingWatchSelection) {
        HierarchicalDevicePickerView(initialCategory: .watch, lockCategory: true) {
          name, identifier in
          guard let result = pendingParseResult else { return }
          let record = createRecord(
            from: result,
            deviceName: name,
            deviceModelCodeOverride: identifier
          )
          modelContext.insert(record)
          try? modelContext.save()
          selectedRecord = nil  // シートを閉じるために一旦nilにする
          pendingParseResult = nil

          // 未登録の場合は登録を促す
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
            deviceModelCodeOverride: identifier
          )
          modelContext.insert(record)
          try? modelContext.save()
          selectedRecord = nil  // シートを閉じるために一旦nilにする
          pendingParseResult = nil

          // Watchが選択され、かつ未登録の場合は登録を促す
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

  // MARK: - ファイルインポート処理
  private func handleFileImport(result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first else { return }

      guard url.startAccessingSecurityScopedResource() else {
        errorMessage = String(localized: "file_access_denied")
        showingErrorAlert = true
        return
      }

      do {
        let text = try String(contentsOf: url, encoding: .utf8)
        url.stopAccessingSecurityScopedResource()
        processLogTextAsync(text)
      } catch {
        url.stopAccessingSecurityScopedResource()
        errorMessage = "\(String(localized: "file_read_error")): \(error.localizedDescription)"
        showingErrorAlert = true
      }

    case .failure(let error):
      errorMessage = "\(String(localized: "file_select_error")): \(error.localizedDescription)"
      showingErrorAlert = true
    }
  }

  private func processLogTextAsync(_ text: String) {
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
        if let newRecord = addRecordFromParseResult(parseResult) {
          selectedRecord = newRecord
        }
      }
    }
  }

  private func addRecordFromParseResult(_ result: LogParser.ParseResult) -> BatteryRecord? {
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
        // 手動選択フローへ
        pendingParseResult = result
        showingMismatchAlert = true
        return nil
      }
    }

    if hasDuplicateRecord(on: logDate, osVersion: result.osVersion) {
      errorMessage = String(localized: "duplicate_record")
      showingErrorAlert = true
      return nil
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

    // watchOS または Apple Watch のログだった場合
    let isWatchOS = result.osVersion?.lowercased().contains("watch") ?? false
    let looksLikeWatch = deviceName.contains("Apple Watch")

    if isWatchOS || looksLikeWatch {
      // 登録済みのApple Watchがあれば自動で使用
      if let registeredWatch = appSettings.registeredWatchModel {
        let newRecord = createRecord(
          from: result,
          deviceName: registeredWatch,
          deviceModelCodeOverride: deviceModelCodeToUse
        )
        modelContext.insert(newRecord)
        try? modelContext.save()
        return newRecord
      }

      // 未登録の場合は選択ダイアログを表示
      pendingParseResult = result
      showingWatchSelection = true
      return nil
    }

    let newRecord = createRecord(
      from: result,
      deviceName: deviceName,
      deviceModelCodeOverride: deviceModelCodeToUse
    )
    modelContext.insert(newRecord)
    try? modelContext.save()
    return newRecord
  }

  private func createRecord(
    from result: LogParser.ParseResult,
    deviceName: String,
    deviceModelCodeOverride: String? = nil
  ) -> BatteryRecord {
    let logDate = result.logDate ?? Date()
    let modelCodeUsed = deviceModelCodeOverride ?? result.deviceModelCode

    return BatteryRecord(
      logDate: logDate,
      deviceName: deviceName,
      deviceModelCode: modelCodeUsed,
      osVersion: result.osVersion,
      storage: result.storage,
      ram: result.ram,
      manufactureDate: nil,
      firstUseDate: result.firstUseDate,
      cycleCount: result.cycleCount ?? 0,
      designCapacity: result.designCapacity ?? (result.nominalCapacity ?? 0),
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
  }

  private func deleteRecords(_ items: [BatteryRecord]) {
    withAnimation {
      items.forEach { modelContext.delete($0) }
    }
  }

  private func hasDuplicateRecord(on date: Date, osVersion: String?) -> Bool {
    records.contains { existing in
      let sameDate =
        Calendar.current.compare(existing.logDate, to: date, toGranularity: .second) == .orderedSame
      guard sameDate else { return false }
      if let existingVersion = existing.osVersion, let newVersion = osVersion {
        return existingVersion == newVersion
      }
      return existing.osVersion == nil && osVersion == nil
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

// MARK: - 一覧の行ビュー
struct RecordRowView: View {
  let record: BatteryRecord

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(record.deviceName)
          .font(.headline)
        Text(record.logDate, style: .date)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(String(format: String(localized: "cycle_count_format"), record.cycleCount))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        Text("\(String(format: "%.1f", record.healthPercent))%")
          .font(.title2)
          .bold()
          .foregroundStyle(healthColor(record.healthPercent))
        if let display = record.settingsDisplayPercent {
          Text("\(String(localized: "os_display")): \(display)%")
            .font(.caption2)
            .foregroundStyle(.gray)
        }
        if let diag = record.diagnosticResult {
          Text(diag)
            .font(.caption2)
        }
      }
    }
    .padding(.vertical, 4)
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }
}

// MARK: - 詳細ビュー
struct RecordDetailView: View {
  let record: BatteryRecord
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section(String(localized: "device_info")) {
          LabeledContent(String(localized: "device_name"), value: record.deviceName)
          if let soc = record.soc {
            LabeledContent(String(localized: "soc"), value: soc)
          }
          if let modelCode = record.deviceModelCode {
            LabeledContent(String(localized: "model_code"), value: modelCode)
          }
          if let storage = record.storage {
            LabeledContent(String(localized: "storage"), value: storage)
          }
          if let ram = record.ram {
            LabeledContent(String(localized: "ram"), value: ram)
          }
          LabeledContent(
            String(localized: "log_date"), value: record.logDate,
            format: .dateTime.year().month().day())
          if let firstUse = record.firstUseDate {
            LabeledContent(
              String(localized: "first_use_date"), value: firstUse,
              format: .dateTime.year().month().day())
          }
        }

        Section(String(localized: "battery_capacity")) {
          LabeledContent(
            String(localized: "cycle_count"),
            value: String(format: String(localized: "cycle_count_format"), record.cycleCount))
          LabeledContent(
            String(localized: "design_capacity"), value: "\(record.designCapacity) mAh")
          LabeledContent(
            String(localized: "nominal_capacity"), value: "\(record.nominalCapacity) mAh")
          LabeledContent(String(localized: "raw_capacity"), value: "\(record.rawCapacity) mAh")
          if let lowRate = record.lowRateCapacity {
            LabeledContent(String(localized: "low_rate_capacity"), value: "\(lowRate) mAh")
          }
        }

        Section(String(localized: "battery_health")) {
          LabeledContent(String(localized: "real_health")) {
            Text("\(String(format: "%.1f", record.healthPercent))%")
              .foregroundStyle(healthColor(record.healthPercent))
              .bold()
          }
          if let display = record.settingsDisplayPercent {
            LabeledContent(String(localized: "os_display"), value: "\(display)%")
          }
          if let deflator = record.deflator {
            LabeledContent(String(localized: "deflator"), value: String(format: "%.1f%%", deflator))
          }
          if let diag = record.diagnosticResult {
            LabeledContent(String(localized: "diagnostic_result"), value: diag)
          }
        }

        if record.avgTemp != nil || record.maxTemp != nil || record.minTemp != nil {
          Section(String(localized: "temperature_daily")) {
            if let avg = record.avgTemp {
              LabeledContent(String(localized: "average"), value: String(format: "%.1f°C", avg))
            }
            if let max = record.maxTemp {
              LabeledContent(String(localized: "maximum"), value: String(format: "%.1f°C", max))
            }
            if let min = record.minTemp {
              LabeledContent(String(localized: "minimum"), value: String(format: "%.1f°C", min))
            }
          }
        }

        if record.maxVoltage != nil || record.minVoltage != nil {
          Section(String(localized: "voltage")) {
            if let max = record.maxVoltage {
              LabeledContent(String(localized: "maximum"), value: String(format: "%.0f mV", max))
            }
            if let min = record.minVoltage {
              LabeledContent(String(localized: "minimum"), value: String(format: "%.0f mV", min))
            }
          }
        }

        if record.maxSoC != nil || record.minSoC != nil {
          Section(String(localized: "charge_range_daily")) {
            if let max = record.maxSoC {
              LabeledContent(String(localized: "max_soc"), value: "\(max)%")
            }
            if let min = record.minSoC {
              LabeledContent(String(localized: "min_soc"), value: "\(min)%")
            }
          }
        }
      }
      .navigationTitle(String(localized: "detail"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "close")) { dismiss() }
        }
      }
    }
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }
}

// MARK: - ContentView (互換性のため残す)
struct ContentView: View {
  var body: some View {
    MainTabView()
  }
}

#Preview {
  ContentView()
    .modelContainer(for: BatteryRecord.self, inMemory: true)
}
