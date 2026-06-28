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

        // LazyVGridは「行内の最大高さに全セルを揃える」ため、
        // セルの高さが異なると空白が発生する。
        // HStack(alignment: .top) を使うことで各カラムが完全独立し、
        // 互いの高さに引っ張られなくなる。
        HStack(alignment: .top, spacing: 24) {
          ForEach(0..<columnsCount, id: \.self) { columnIndex in
            // カラムに属するセクションを振り分け（2列なら偶数/奇数インデックス）
            let columnSections = cachedSections.indices
              .filter { $0 % columnsCount == columnIndex }
              .map { cachedSections[$0] }
            VStack(alignment: .leading, spacing: 24) {
              ForEach(columnSections, id: \.id) { section in
                let sectionRecords = recordsForSection(section)
                VStack(alignment: .leading, spacing: 16) {
                  // カスタムヘッダーでリッチなセクション表示
                  Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                      allowSectionAnimation = true
                      if collapsedSections.contains(section.id) {
                        collapsedSections.remove(section.id)
                      } else {
                        collapsedSections.insert(section.id)
                      }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                      allowSectionAnimation = false
                    }
                  } label: {
                    HStack(spacing: 12) {
                      let splitName = splitDeviceName(section.displayName)
                      
                      // エレガントなアイコン表示
                      ZStack {
                        Circle()
                          .fill(appSettings.accentColor.color.opacity(0.12))
                          .frame(width: 40, height: 40)
                        Image(systemName: splitName.primary.contains("Watch") ? "applewatch" : (splitName.primary.contains("iPad") ? "ipad" : "iphone"))
                          .foregroundStyle(appSettings.accentColor.color)
                          .font(.system(size: 18, weight: .semibold))
                      }
                      
                      VStack(alignment: .leading, spacing: 2) {
                        Text(splitName.primary)
                          .font(.title3)
                          .fontWeight(.bold)
                          .foregroundColor(.primary)
                        if let secondary = splitName.secondary {
                          Text(secondary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                      }
                      
                      Spacer()
                      
                      ZStack {
                        Circle()
                          .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                          .frame(width: 32, height: 32)
                        Image(systemName: "chevron.up")
                          .foregroundStyle(.secondary)
                          .font(.system(size: 14, weight: .bold))
                          .rotationEffect(.degrees(collapsedSections.contains(section.id) ? 180 : 0))
                      }
                    }
                    .contentShape(Rectangle())
                  }
                  .buttonStyle(.plain)
                  
                  if !collapsedSections.contains(section.id) {
                    iPadDeviceSectionContent(
                      section: section,
                      sectionRecords: sectionRecords
                    )
                  }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: collapsedSections)
                .padding(20)
                .background(
                  Color(uiColor: .secondarySystemGroupedBackground)
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .transition(
                  .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                  ))
              }
            }
            .frame(maxWidth: .infinity)
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
            ForEach(sectionRecords, id: \.id) { record in
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
    // DisclosureGroupを廃止したため、LazyVGridが自然なレイアウトで動作します
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 12) {
      ForEach(sectionRecords, id: \.id) { record in
        iPadRecordCard(record: record, section: section)
      }
    }
    .padding(.top, 8)

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

  /// iPad用個別レコードカード
  @ViewBuilder
  private func iPadRecordCard(record: BatteryRecord, section: DeviceSection) -> some View {
    NavigationLink(destination: RecordDetailView(record: record)) {
      ModerniPadRecordCard(record: record)
        .padding(16)
        .background(
          Color(uiColor: .tertiarySystemGroupedBackground)
            .shadow(color: Color.black.opacity(0.02), radius: 5, x: 0, y: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color(uiColor: .separator).opacity(0.1), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
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

// MARK: - Modern iPad Record Card
private struct ModerniPadRecordCard: View {
  let record: BatteryRecord
  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      // 左側: 日付と基本情報
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 6) {
          Image(systemName: "calendar")
            .foregroundStyle(appSettings.accentColor.color)
            .font(.caption)
          Text(record.logDate, style: .date)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
        }
        
        HStack(spacing: 12) {
          Label(
            String(format: String(localized: "cycle_count_format", table: "Analytics"), record.cycleCount),
            systemImage: "arrow.triangle.2.circlepath"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          
          Label("\(record.nominalCapacity) mAh", systemImage: "battery.100")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        Text(record.cachedDiagnostic)
          .font(.caption2)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      
      Spacer(minLength: 8)
      
      // 右側: 健康度リング
      let health = appSettings.analysisDataSource == .nominal ? record.nominalHealthPercent : record.healthPercent
      
      ZStack {
        Circle()
          .stroke(Color(uiColor: .systemGray5), lineWidth: 5)
          .frame(width: 52, height: 52)
        
        Circle()
          .trim(from: 0, to: CGFloat(min(max(health, 0), 100)) / 100.0)
          .stroke(
            healthColor(health),
            style: StrokeStyle(lineWidth: 5, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
          .frame(width: 52, height: 52)
          
        Text("\(String(format: "%.0f", health))%")
          .font(.caption2)
          .fontWeight(.bold)
          .foregroundStyle(healthColor(health))
      }
    }
  }
  
  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }
}
