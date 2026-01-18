import SwiftUI

/// 共通のレコードリストビュー
/// サンプルデータと実データで同じレイアウトを使用するための共通コンポーネント
struct RecordListView<Header: View>: View {
  let records: [BatteryRecord]
  let onRecordTap: ((BatteryRecord) -> Void)?
  let onRecordDelete: ((BatteryRecord) -> Void)?
  let showContextMenu: Bool
  let header: Header

  @StateObject private var appSettings = AppSettings.shared
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var collapsedSections: Set<String> = []

  // MARK: - バックグラウンド計算用の状態
  @State private var isLoading = true
  @State private var cachedSections: [DeviceSection] = []
  @State private var lastRecordsHash: Int?
  @State private var lastSortOrderHash: Int?

  init(
    records: [BatteryRecord],
    onRecordTap: ((BatteryRecord) -> Void)? = nil,
    onRecordDelete: ((BatteryRecord) -> Void)? = nil,
    showContextMenu: Bool = true,
    @ViewBuilder header: () -> Header = { EmptyView() }
  ) {
    self.records = records
    self.onRecordTap = onRecordTap
    self.onRecordDelete = onRecordDelete
    self.showContextMenu = showContextMenu
    self.header = header()
  }

  var body: some View {
    ZStack {
      if isLoading && cachedSections.isEmpty {
        // 初回ローディング中
        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.2)
          Text(String(localized: "preparing_data", table: "Home"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        // コンテンツ表示
        Group {
          if horizontalSizeClass == .regular {
            iPadGridLayout
          } else {
            iPhoneLayout
          }
        }
        .animation(.snappy, value: cachedSections.map { $0.id })
      }
    }
    .onAppear {
      prepareDeviceSectionsIfNeeded()
    }
    .onChange(of: records) {
      prepareDeviceSectionsIfNeeded()
    }
    .onChange(of: appSettings.deviceSortOrder) {
      prepareDeviceSectionsIfNeeded(force: true)
    }
  }

  // MARK: - バックグラウンドでセクションを準備
  private func prepareDeviceSectionsIfNeeded(force: Bool = false) {
    // レコードの内容からハッシュを計算
    var hasher = Hasher()
    for record in records {
      hasher.combine(record.logDate)
      hasher.combine(record.deviceName)
    }
    let recordsHash = hasher.finalize()
    let sortOrderHash = appSettings.deviceSortOrder.hashValue

    // 変更がなければスキップ（ただしforceが指定されている場合は再計算）
    if !force && recordsHash == lastRecordsHash && sortOrderHash == lastSortOrderHash {
      return
    }

    isLoading = true

    // レコード情報を抽出（Sendable対応）- logDateの文字列表現をIDとして使用
    let dateFormatter = ISO8601DateFormatter()
    let recordInfos = records.map { record in
      let recordID = "\(record.deviceName)_\(dateFormatter.string(from: record.logDate))"
      return (id: recordID, deviceName: record.deviceName)
    }
    let sortOrder = appSettings.deviceSortOrder

    Task.detached(priority: .userInitiated) {
      // バックグラウンドでセクション計算
      let sections = Self.computeDeviceSections(recordInfos: recordInfos, sortOrder: sortOrder)

      await MainActor.run {
        withAnimation(.snappy) {
          cachedSections = sections
        }
        lastRecordsHash = recordsHash
        lastSortOrderHash = sortOrderHash
        isLoading = false
      }
    }
  }

  /// デバイスセクションを計算する（バックグラウンドスレッドで実行）
  nonisolated private static func computeDeviceSections(
    recordInfos: [(id: String, deviceName: String)],
    sortOrder: [String]
  ) -> [DeviceSection] {
    var sections: [DeviceSection] = []
    var indexForDevice: [String: Int] = [:]
    var recordIDsForDevice: [String: [String]] = [:]

    for info in recordInfos {
      let name = info.deviceName
      if recordIDsForDevice[name] != nil {
        recordIDsForDevice[name]?.append(info.id)
      } else {
        recordIDsForDevice[name] = [info.id]
        indexForDevice[name] = sections.count
        sections.append(DeviceSection(id: name, displayName: name, recordIDs: []))
      }
    }

    // recordIDsを設定
    sections = sections.map { section in
      DeviceSection(
        id: section.id,
        displayName: section.displayName,
        recordIDs: recordIDsForDevice[section.id] ?? []
      )
    }

    // ソート順を適用
    if !sortOrder.isEmpty {
      sections.sort { a, b in
        let indexA = sortOrder.firstIndex(of: a.id) ?? Int.max
        let indexB = sortOrder.firstIndex(of: b.id) ?? Int.max
        return indexA < indexB
      }
    }

    return sections
  }

  /// セクションIDからレコードを取得するヘルパー
  private func recordsForSection(_ section: DeviceSection) -> [BatteryRecord] {
    // デバイス名でフィルタリング（セクションIDはデバイス名）
    return records.filter { $0.deviceName == section.id }
  }

  // MARK: - iPad レイアウト（複数列表示）
  private var iPadGridLayout: some View {
    GeometryReader { geometry in
      ScrollView {
        header

        let availableWidth = geometry.size.width
        let minSectionWidth: CGFloat = 340
        let maxColumns = max(1, Int(availableWidth / minSectionWidth))
        let columnsCount = min(cachedSections.count, maxColumns)
        let outerColumns = Array(
          repeating: GridItem(.flexible(), spacing: 24, alignment: .top),
          count: max(1, columnsCount))

        LazyVGrid(columns: outerColumns, alignment: .leading, spacing: 24) {
          ForEach(cachedSections, id: \.id) { section in
            let sectionRecords = recordsForSection(section)
            VStack(alignment: .leading, spacing: 12) {
              // DisclosureGroupで折りたたみ可能に
              DisclosureGroup(
                isExpanded: Binding(
                  get: { !collapsedSections.contains(section.id) },
                  set: { isExpanded in
                    withAnimation(.snappy) {
                      if isExpanded {
                        collapsedSections.remove(section.id)
                      } else {
                        collapsedSections.insert(section.id)
                      }
                    }
                  }
                )
              ) {
                // Inner Grid: Cards within the device section
                LazyVGrid(
                  columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16
                ) {
                  ForEach(sectionRecords, id: \.logDate) { record in
                    NavigationLink(destination: RecordDetailView(record: record)) {
                      RecordRowView(record: record)
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                      if showContextMenu, let onDelete = onRecordDelete {
                        Button(role: .destructive) {
                          onDelete(record)
                        } label: {
                          Label(
                            String(localized: "delete", table: "Common"), systemImage: "trash.fill"
                          )
                          .font(.title2)
                        }
                      }
                    } preview: {
                      // プレビューでレコード情報を表示
                      RecordRowView(record: record)
                        .padding()
                        .frame(width: 300)
                    }
                    .transition(
                      .asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                      ))
                  }
                }
                .padding(.top, 8)
              } label: {
                Text(section.displayName)
                  .font(.title3)
                  .bold()
                  .foregroundStyle(.primary)
              }
              .padding()
              .background(Color(uiColor: .secondarySystemGroupedBackground))
              .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .transition(
              .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
              ))
          }
        }
        .padding(20)
      }
    }
    .background(Color(uiColor: .systemGroupedBackground))
  }

  // MARK: - iPhone レイアウト
  private var iPhoneLayout: some View {
    List {
      header
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

      ForEach(cachedSections, id: \.id) { section in
        let sectionRecords = recordsForSection(section)
        Section {
          DisclosureGroup(
            isExpanded: Binding(
              get: { !collapsedSections.contains(section.id) },
              set: { isExpanded in
                withAnimation(.snappy) {
                  if isExpanded {
                    collapsedSections.remove(section.id)
                  } else {
                    collapsedSections.insert(section.id)
                  }
                }
              }
            )
          ) {
            ForEach(sectionRecords, id: \.logDate) { record in
              RecordRowView(record: record)
                .contentShape(Rectangle())
                .onTapGesture {
                  onRecordTap?(record)
                }
                .transition(
                  .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                  ))
            }
            .onDelete { offsets in
              if let onDelete = onRecordDelete {
                let items = offsets.map { sectionRecords[$0] }
                items.forEach { onDelete($0) }
              }
            }
          } label: {
            Text(section.displayName)
              .font(.headline)
              .foregroundStyle(.primary)
          }
        }
        .transition(
          .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
          ))
      }
    }
  }

  // MARK: - デバイスセクション構造体
  private struct DeviceSection: Identifiable, Equatable {
    let id: String
    let displayName: String
    let recordIDs: [String]

    static func == (lhs: DeviceSection, rhs: DeviceSection) -> Bool {
      lhs.id == rhs.id && lhs.recordIDs == rhs.recordIDs
    }
  }
}
