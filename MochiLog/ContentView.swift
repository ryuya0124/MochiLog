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
            ForEach(records) { record in
              RecordRowView(record: record)
                .contentShape(Rectangle())
                .onTapGesture {
                  selectedRecord = record
                }
            }
            .onDelete(perform: deleteItems)
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
          addRecordFromText(text)
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
        addRecordFromText(text)
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
  private func addRecordFromText(_ text: String) {
    let result = LogParser.parse(text: text)

    // 必要なデータが最低限取れているか確認
    guard let cycle = result.cycleCount,
      let nominal = result.nominalCapacity,
      let raw = result.rawCapacity
    else {
      errorMessage = "ログデータの解析に失敗しました。バッテリー情報が含まれていません。"
      showingErrorAlert = true
      return
    }

    // デバイス名を取得
    let deviceName = DeviceLibrary.getDeviceName(for: result.deviceModelCode ?? "") ?? "Unknown"

    let newRecord = BatteryRecord(
      logDate: result.logDate ?? Date(),
      deviceName: deviceName,
      deviceModelCode: result.deviceModelCode,
      storage: result.storage,
      ram: result.ram,
      manufactureDate: nil,
      firstUseDate: result.firstUseDate,
      cycleCount: cycle,
      designCapacity: result.designCapacity ?? nominal,
      nominalCapacity: nominal,
      rawCapacity: raw,
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

    modelContext.insert(newRecord)
  }

  private func deleteItems(offsets: IndexSet) {
    withAnimation {
      for index in offsets {
        modelContext.delete(records[index])
      }
    }
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
