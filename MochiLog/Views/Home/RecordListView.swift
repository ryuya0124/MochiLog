import SwiftUI

/// 共通のレコードリストビュー
/// サンプルデータと実データで同じレイアウトを使用するための共通コンポーネント
struct RecordListView: View {
  let records: [BatteryRecord]
  let onRecordTap: ((BatteryRecord) -> Void)?
  let onRecordDelete: ((BatteryRecord) -> Void)?
  let showContextMenu: Bool

  @StateObject private var appSettings = AppSettings.shared
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var collapsedSections: Set<String> = []

  init(
    records: [BatteryRecord],
    onRecordTap: ((BatteryRecord) -> Void)? = nil,
    onRecordDelete: ((BatteryRecord) -> Void)? = nil,
    showContextMenu: Bool = true
  ) {
    self.records = records
    self.onRecordTap = onRecordTap
    self.onRecordDelete = onRecordDelete
    self.showContextMenu = showContextMenu
  }

  var body: some View {
    if horizontalSizeClass == .regular {
      iPadLayout
    } else {
      iPhoneLayout
    }
  }

  // MARK: - iPad レイアウト
  private var iPadLayout: some View {
    GeometryReader { geometry in
      ScrollView {
        let availableWidth = geometry.size.width
        let minSectionWidth: CGFloat = 340
        let maxColumns = max(1, Int(availableWidth / minSectionWidth))
        let columnsCount = min(deviceSections.count, maxColumns)
        let outerColumns = Array(
          repeating: GridItem(.flexible(), spacing: 24, alignment: .top),
          count: max(1, columnsCount))

        LazyVGrid(columns: outerColumns, alignment: .leading, spacing: 24) {
          ForEach(deviceSections) { section in
            VStack(alignment: .leading, spacing: 12) {
              // DisclosureGroupで折りたたみ可能に
              DisclosureGroup(
                isExpanded: Binding(
                  get: { !collapsedSections.contains(section.id) },
                  set: { isExpanded in
                    if isExpanded {
                      collapsedSections.remove(section.id)
                    } else {
                      collapsedSections.insert(section.id)
                    }
                  }
                )
              ) {
                // Inner Grid: Cards within the device section
                LazyVGrid(
                  columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16
                ) {
                  ForEach(section.records) { record in
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
                          Label(String(localized: "delete"), systemImage: "trash")
                        }
                      }
                    }
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
      ForEach(deviceSections) { section in
        Section {
          DisclosureGroup(
            isExpanded: Binding(
              get: { !collapsedSections.contains(section.id) },
              set: { isExpanded in
                if isExpanded {
                  collapsedSections.remove(section.id)
                } else {
                  collapsedSections.insert(section.id)
                }
              }
            )
          ) {
            ForEach(section.records) { record in
              RecordRowView(record: record)
                .contentShape(Rectangle())
                .onTapGesture {
                  onRecordTap?(record)
                }
            }
            .onDelete { offsets in
              if let onDelete = onRecordDelete {
                let items = offsets.map { section.records[$0] }
                items.forEach { onDelete($0) }
              }
            }
          } label: {
            Text(section.displayName)
              .font(.headline)
              .foregroundStyle(.primary)
          }
        }
      }
    }
  }

  // MARK: - デバイスセクション
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

    // Apply sort order
    let sortOrder = appSettings.deviceSortOrder
    if !sortOrder.isEmpty {
      sections.sort { (a, b) -> Bool in
        let indexA = sortOrder.firstIndex(of: a.id) ?? Int.max
        let indexB = sortOrder.firstIndex(of: b.id) ?? Int.max
        return indexA < indexB
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
