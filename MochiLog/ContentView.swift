import SwiftUI
import SwiftData
import Charts

struct ContentView: View {
    // データベースへの接続
    @Environment(\.modelContext) private var modelContext
    // 日付順にデータを取得
    @Query(sort: \BatteryRecord.date, order: .reverse) private var records: [BatteryRecord]
    
    @State private var showingInputSheet = false
    @State private var inputText = ""

    var body: some View {
        NavigationStack {
            VStack {
                if records.isEmpty {
                    ContentUnavailableView("データがありません", systemImage: "battery.0", description: Text("右上の＋ボタンからログを追加してください"))
                } else {
                    // --- グラフエリア ---
                    Chart {
                        ForEach(records) { record in
                            LineMark(
                                x: .value("日付", record.date),
                                y: .value("実容量", record.realHealthPercent)
                            )
                            .foregroundStyle(Color.green.gradient)
                            .symbol(by: .value("デバイス", record.deviceName))
                        }
                    }
                    .chartYScale(domain: 80...105) // Y軸の範囲 (80%~105%を表示)
                    .frame(height: 200)
                    .padding()
                    
                    // --- 履歴リストエリア ---
                    List {
                        ForEach(records) { record in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("サイクル: \(record.cycleCount)回")
                                        .font(.headline)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(String(format: "%.1f", record.realHealthPercent))%")
                                        .font(.title3)
                                        .bold()
                                        .foregroundStyle(record.realHealthPercent < 80 ? .red : .green)
                                    Text("OS表示: \(Int(record.maxCapacityPercent))%")
                                        .font(.caption2)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("MochiLog")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingInputSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            // --- 簡易入力シート (Share Extension実装までのテスト用) ---
            .sheet(isPresented: $showingInputSheet) {
                NavigationStack {
                    VStack {
                        Text("解析データをここに貼り付け")
                            .font(.headline)
                            .padding(.top)
                        TextEditor(text: $inputText)
                            .border(Color.gray.opacity(0.2))
                            .padding()
                        
                        Button("解析して保存") {
                            addRecordFromText()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(inputText.isEmpty)
                        .padding()
                    }
                    .navigationTitle("ログ追加")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { showingInputSheet = false }
                        }
                    }
                }
            }
        }
    }

    // データを追加する処理
    private func addRecordFromText() {
        let result = LogParser.parse(text: inputText)
        
        // 必要なデータが最低限取れているか確認
        if let cycle = result.cycleCount,
           let maxPercent = result.maxCapacityPercent,
           let nominal = result.nominalChargeCapacity {
            
            // デザイン容量は取れなければNominalを使う(仮)
            let design = result.designCapacity ?? nominal
            
            let newRecord = BatteryRecord(
                date: Date(), // 本当はログ内の日付を取るべきですが、一旦「現在時刻」で保存
                cycleCount: cycle,
                maxCapacityPercent: maxPercent,
                realCapacitymAh: nominal,
                designCapacitymAh: design
            )
            
            modelContext.insert(newRecord)
            inputText = ""
            showingInputSheet = false
        } else {
            // エラーハンドリング（本番ではアラートを出すなど）
            print("データが見つかりませんでした")
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(records[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: BatteryRecord.self, inMemory: true)
}