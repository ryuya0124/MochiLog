import Charts
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  // データベースへの接続
  @Environment(\.modelContext) private var modelContext
  // 日付順にデータを取得
  @Query(sort: \BatteryRecord.logDate, order: .reverse) private var records: [BatteryRecord]

  @State private var showingFilePicker = false
  @State private var showingErrorAlert = false
  @State private var errorMessage = ""
  @State private var selectedRecord: BatteryRecord?
  // Watch モデル選択用の状態
  @State private var pendingParseResult: LogParser.ParseResult?
  @State private var showingWatchSelection = false
  @State private var watchCandidates: [String] = []

  // 無引数で `ContentView()` を呼べるように明示的なイニシャライザを追加
  init() {}

  var body: some View {
    NavigationStack {
      VStack {
        if records.isEmpty {
          ContentUnavailableView(
            "データがありません", systemImage: "battery.0",
            description: Text("右上の＋ボタンからログを追加してください"))
        } else {
          // --- グラフエリア ---
          Chart {
            ForEach(records) { record in
              LineMark(
                x: .value("日付", record.logDate),
                y: .value("実容量", record.healthPercent)
              )
              .foregroundStyle(Color.green.gradient)
              .symbol(by: .value("デバイス", record.deviceName))
            }
          }
          .chartYScale(domain: 70...105)  // Y軸の範囲
          .frame(height: 180)
          .padding()

          // --- 履歴リストエリア ---
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
      .navigationTitle("MochiLog")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { showingFilePicker = true }) {
            Image(systemName: "plus")
          }
        }
      }
      // --- ファイル選択シート ---
      .fileImporter(
        isPresented: $showingFilePicker,
        allowedContentTypes: [.json, .plainText, .data],
        allowsMultipleSelection: false
      ) { result in
        handleFileImport(result: result)
      }
      .alert("エラー", isPresented: $showingErrorAlert) {
        Button("OK", role: .cancel) {}
      } message: {
        Text(errorMessage)
      }
      // 詳細シート
      .sheet(item: $selectedRecord) { record in
        RecordDetailView(record: record)
      }
      // Share Extensionからの通知を受け取る
      .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProcessSharedLog")))
      { notification in
        if let text = notification.userInfo?["text"] as? String {
          if let newRecord = addRecordFromText(text) {
            // 共有から来た場合は処理後に詳細を自動で表示
            selectedRecord = newRecord
          }
        }
      }
      .onAppear {
        reconcileUnknownDeviceNames()
      }
      // Watch モデル選択ダイアログ
      .confirmationDialog(
        "デバイスを選択してください", isPresented: $showingWatchSelection, titleVisibility: .visible
      ) {
        ForEach(watchCandidates, id: \.self) { name in
          Button(name) {
            guard let result = pendingParseResult else { return }
            let record = createRecord(from: result, deviceName: name)
            modelContext.insert(record)
            try? modelContext.save()
            // 表示用に詳細を選択
            selectedRecord = record
            // クリア
            pendingParseResult = nil
            watchCandidates = []
          }
        }
        Button("キャンセル", role: .cancel) {
          pendingParseResult = nil
          watchCandidates = []
        }
      }
    }
  }

  // ファイルからデータを読み込んで解析・保存
  private func handleFileImport(result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first else { return }

      // セキュリティスコープのアクセス開始
      guard url.startAccessingSecurityScopedResource() else {
        errorMessage = "ファイルへのアクセス権限がありません"
        showingErrorAlert = true
        return
      }
      defer { url.stopAccessingSecurityScopedResource() }

      do {
        let text = try String(contentsOf: url, encoding: .utf8)
        if let newRecord = addRecordFromText(text) {
          selectedRecord = newRecord
        }
      } catch {
        errorMessage = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
        showingErrorAlert = true
      }

    case .failure(let error):
      errorMessage = "ファイル選択エラー: \(error.localizedDescription)"
      showingErrorAlert = true
    }
  }

  // データを追加する処理
  // 処理したレコードを返す（呼び出し元で詳細表示などに使う）
  private func addRecordFromText(_ text: String) -> BatteryRecord? {
    let result = LogParser.parse(text: text)

    // 必要なデータが最低限取れているか確認
    guard let logDate = result.logDate,
      result.cycleCount != nil,
      result.nominalCapacity != nil,
      result.rawCapacity != nil
    else {
      errorMessage = "ログから日時やバッテリー情報を正しく取得できませんでした。"
      showingErrorAlert = true
      return nil
    }

    if hasDuplicateRecord(on: logDate, osVersion: result.osVersion) {
      errorMessage = "同じログ確認日時のデータがすでに存在します。"
      showingErrorAlert = true
      return nil
    }

    // 識別子 -> 機種名を優先 (boardId から検出済みであればそちらを利用)
    var deviceName = "Unknown"
    var deviceModelCodeToUse: String? = result.detectedIdentifier ?? result.deviceModelCode
    if let id = deviceModelCodeToUse,
      let resolved = DeviceLibrary.getDeviceName(for: id)
    {
      deviceName = resolved
    }

    // ログに機種識別子が無ければ、実行中デバイスの hw.machine を参照してフォールバック
    if deviceName == "Unknown" {
      if let localId = DeviceLibrary.localModelIdentifier(),
        let resolved = DeviceLibrary.getDeviceName(for: localId)
      {
        deviceName = resolved
        deviceModelCodeToUse = localId
      }
    }

    // watchOS または Apple Watch のログだった場合、ユーザーに選択を促す
    let isWatchOS = result.osVersion?.lowercased().contains("watch") ?? false
    let looksLikeWatch = deviceName.contains("Apple Watch")
    if isWatchOS || looksLikeWatch {
      // 候補リストを作成（DeviceLibrary の辞書から Apple Watch 系を抽出）
      watchCandidates = Array(Set(DeviceLibrary.deviceNames.values))
        .filter { $0.contains("Apple Watch") }
        .sorted()
      pendingParseResult = result
      showingWatchSelection = true
      return nil
    }

    // 通常のレコード作成
    let newRecord = createRecord(
      from: result, deviceName: deviceName, deviceModelCodeOverride: deviceModelCodeToUse)
    modelContext.insert(newRecord)
    try? modelContext.save()
    return newRecord
  }

  // 解析結果と選択機種名から実際の BatteryRecord を作るヘルパー
  private func createRecord(
    from result: LogParser.ParseResult, deviceName: String, deviceModelCodeOverride: String? = nil
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
      // Only treat as duplicate if both osVersion values are nil (unknown)
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
        Text(record.logDate.formatted(date: .abbreviated, time: .omitted))
          .font(.caption)
          .foregroundStyle(.secondary)
        Text("サイクル: \(record.cycleCount)回")
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
          Text("OS表示: \(display)%")
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
        // --- 基本情報 ---
        Section("デバイス情報") {
          LabeledContent("機種名", value: record.deviceName)
          if let soc = record.soc {
            LabeledContent("SoC", value: soc)
          }
          if let modelCode = record.deviceModelCode {
            LabeledContent("モデルコード", value: modelCode)
          }
          if let storage = record.storage {
            LabeledContent("ストレージ", value: storage)
          }
          if let ram = record.ram {
            LabeledContent("RAM", value: ram)
          }
          LabeledContent("ログ日付", value: record.logDate.formatted(date: .long, time: .shortened))
          if let firstUse = record.firstUseDate {
            LabeledContent("初使用日", value: firstUse.formatted(date: .long, time: .omitted))
          }
        }

        // --- バッテリー容量 ---
        Section("バッテリー容量") {
          LabeledContent("サイクル数", value: "\(record.cycleCount)回")
          LabeledContent("設計容量", value: "\(record.designCapacity) mAh")
          LabeledContent("公称容量", value: "\(record.nominalCapacity) mAh")
          LabeledContent("実測容量", value: "\(record.rawCapacity) mAh")
          if let lowRate = record.lowRateCapacity {
            LabeledContent("低レート容量", value: "\(lowRate) mAh")
          }
        }

        // --- ヘルス ---
        Section("バッテリーヘルス") {
          LabeledContent("実ヘルス") {
            Text("\(String(format: "%.1f", record.healthPercent))%")
              .foregroundStyle(healthColor(record.healthPercent))
              .bold()
          }
          if let display = record.settingsDisplayPercent {
            LabeledContent("OS表示", value: "\(display)%")
          }
          if let deflator = record.deflator {
            LabeledContent("デフレータ", value: String(format: "%.4f", deflator))
          }
          if let diag = record.diagnosticResult {
            LabeledContent("診断結果", value: diag)
          }
        }

        // --- 温度 ---
        if record.avgTemp != nil || record.maxTemp != nil || record.minTemp != nil {
          Section("温度 (日次)") {
            if let avg = record.avgTemp {
              LabeledContent("平均", value: String(format: "%.1f°C", avg))
            }
            if let max = record.maxTemp {
              LabeledContent("最大", value: String(format: "%.1f°C", max))
            }
            if let min = record.minTemp {
              LabeledContent("最小", value: String(format: "%.1f°C", min))
            }
          }
        }

        // --- 電圧 ---
        if record.maxVoltage != nil || record.minVoltage != nil {
          Section("電圧") {
            if let max = record.maxVoltage {
              LabeledContent("最大", value: String(format: "%.0f mV", max))
            }
            if let min = record.minVoltage {
              LabeledContent("最小", value: String(format: "%.0f mV", min))
            }
          }
        }

        // --- SoC ---
        if record.maxSoC != nil || record.minSoC != nil {
          Section("充電範囲 (日次)") {
            if let max = record.maxSoC {
              LabeledContent("最大SoC", value: "\(max)%")
            }
            if let min = record.minSoC {
              LabeledContent("最小SoC", value: "\(min)%")
            }
          }
        }
      }
      .navigationTitle("詳細")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("閉じる") { dismiss() }
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

#Preview {
  ContentView()
    .modelContainer(for: BatteryRecord.self, inMemory: true)
}
