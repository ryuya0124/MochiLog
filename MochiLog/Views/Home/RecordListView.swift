import SwiftUI
import UIKit

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
  @State private var allowSectionAnimation = false

  // MARK: - ページネーション用の状態
  /// 各デバイスの表示件数（初期値: 50件）
  @State private var displayLimits: [String: Int] = [:]
  /// 1デバイスあたりの初期表示件数
  private let initialDisplayLimit = 50
  /// 「もっと読み込む」で追加する件数
  private let loadMoreCount = 50

  /// recordsから直接デバイスセクションを計算
  private var cachedSections: [DeviceSection] {
    // デバイス名を抽出（重複排除）
    let deviceNames = Array(Set(records.map { $0.deviceName }))

    // AppSettings.deviceSortOrderでソート
    let sortedNames: [String]
    if appSettings.deviceSortOrder.isEmpty {
      sortedNames = deviceNames.sorted()
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
      sortedNames = ordered
    }

    return sortedNames.map { DeviceSection(id: $0, displayName: $0, recordIDs: []) }
  }

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
      // コンテンツ表示
      Group {
        if horizontalSizeClass == .regular {
          iPadGridLayout
        } else {
          iPhoneLayout
        }
      }
      // スクロール中の不要なアニメーションを抑制
      .transaction { transaction in
        if !allowSectionAnimation {
          transaction.animation = nil
        }
      }
    }
  }

  /// セクションIDから表示するレコードを取得するヘルパー（ページネーション対応）
  private func recordsForSection(_ section: DeviceSection) -> [BatteryRecord] {
    // recordsから直接フィルタ
    let filtered = records.filter { $0.deviceName == section.id }
    // 表示件数制限を適用
    let limit = displayLimits[section.id] ?? initialDisplayLimit
    return Array(filtered.prefix(limit))
  }

  /// セクションの全レコード数を取得
  private func totalRecordsForSection(_ section: DeviceSection) -> Int {
    return records.filter { $0.deviceName == section.id }.count
  }

  /// 「もっと読み込む」ボタンを表示すべきか
  private func hasMoreRecords(_ section: DeviceSection) -> Bool {
    let limit = displayLimits[section.id] ?? initialDisplayLimit
    let total = totalRecordsForSection(section)
    return limit < total
  }

  /// 表示件数を増やす
  private func loadMoreRecords(for section: DeviceSection) {
    let currentLimit = displayLimits[section.id] ?? initialDisplayLimit
    displayLimits[section.id] = currentLimit + loadMoreCount
  }

  // MARK: - iPad レイアウト（複数列表示）
  private var iPadGridLayout: some View {
    GeometryReader { geometry in
      ScrollView {
        header
          .padding(.horizontal, 20)

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
                      allowSectionAnimation = true
                      if isExpanded {
                        collapsedSections.remove(section.id)
                      } else {
                        collapsedSections.insert(section.id)
                      }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                      allowSectionAnimation = false
                    }
                  }
                )
              ) {
                iPadDeviceSectionContent(
                  section: section,
                  sectionRecords: sectionRecords
                )
              } label: {
                Text(section.displayName)
                  .font(.title3)
                  .bold()
                  .foregroundColor(.primary)
                  .lineLimit(1)
                  .fixedSize(horizontal: true, vertical: false)
              }
              .animation(.snappy, value: collapsedSections)
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
                  allowSectionAnimation = true
                  if isExpanded {
                    collapsedSections.remove(section.id)
                  } else {
                    collapsedSections.insert(section.id)
                  }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                  allowSectionAnimation = false
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

            // もっと読み込むボタン
            if hasMoreRecords(section) {
              Button {
                withAnimation(.snappy) {
                  loadMoreRecords(for: section)
                }
              } label: {
                HStack {
                  Spacer()
                  Text(String(localized: "load_more", table: "Home"))
                    .font(.subheadline)
                  Text("(\(sectionRecords.count)/\(totalRecordsForSection(section)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                  Spacer()
                }
                .padding(.vertical, 8)
              }
              .buttonStyle(.borderless)
            }
          } label: {
            Text(section.displayName)
              .font(.headline)
              .foregroundColor(.primary)
          }
          .animation(.snappy, value: collapsedSections)
        }
        .transition(
          .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
          ))
      }
    }
  }

  // MARK: - iPadレイアウト用ヘルパービュー
  @ViewBuilder
  private func iPadDeviceSectionContent(
    section: DeviceSection,
    sectionRecords: [BatteryRecord]
  ) -> some View {
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
        .contextMenu {
          if showContextMenu, let onDelete = onRecordDelete {
            Button(role: .destructive) {
              onDelete(record)
            } label: {
              Label {
                Text(String(localized: "delete", table: "Common"))
              } icon: {
                Image(
                  uiImage: UIImage(systemName: "trash")?
                    .withTintColor(.red, renderingMode: .alwaysOriginal)
                    ?? UIImage())
              }
            }
          }
        }
        .animation(.snappy, value: collapsedSections)
      }
    }

    // もっと読み込むボタン
    if hasMoreRecords(section) {
      Button {
        withAnimation(.snappy) {
          loadMoreRecords(for: section)
        }
      } label: {
        HStack {
          Spacer()
          Text(String(localized: "load_more", table: "Home"))
            .font(.subheadline)
          Text("(\(sectionRecords.count)/\(totalRecordsForSection(section)))")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
      .padding(.top, 8)
    }
  }

  // MARK: - デバイス名表示ヘルパー（iPad用）
  /// デバイス名を種類と詳細に分割して表示を綺麗にする
  /// 例: "iPhone 16 Pro Max" → ("iPhone 16", "Pro Max")
  /// 例: "Apple Watch Ultra 2" → ("Apple Watch", "Ultra 2")
  private func splitDeviceName(_ name: String) -> (primary: String, secondary: String?) {
    // Apple Watch の場合：「Apple Watch」の後ろで分割
    if name.hasPrefix("Apple Watch") {
      let rest = String(name.dropFirst("Apple Watch".count)).trimmingCharacters(in: .whitespaces)
      return rest.isEmpty ? (name, nil) : ("Apple Watch", rest)
    }
    // iPhone / iPad の場合：ブランド名 + 最初の識別子 / 残りで分割
    for prefix in ["iPhone", "iPad"] {
      guard name.hasPrefix(prefix) else { continue }
      let rest = String(name.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
      let words = rest.split(separator: " ", maxSplits: .max, omittingEmptySubsequences: true)
      guard words.count >= 2 else { return (name, nil) }
      let primary = "\(prefix) \(words[0])"
      let secondary = words.dropFirst().joined(separator: " ")
      return (primary, secondary)
    }
    return (name, nil)
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
