import SwiftUI

// MARK: - サンプルデータホームビュー
/// データがない時にサンプルデータを表示するビュー
struct SampleDataHomeView: View {
  @Binding var showingSampleData: Bool
  @Binding var selectedRecord: BatteryRecord?
  let openFilePicker: () -> Void
  @StateObject private var appSettings = AppSettings.shared
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @State private var collapsedSections: Set<String> = []
  @State private var showingReorderSheet = false

  private let sampleRecords = SampleDataProvider.generateSampleRecords()

  var body: some View {
    if horizontalSizeClass == .regular {
      GeometryReader { geometry in
        ScrollView {
          VStack(spacing: 20) {
            SampleDataBanner(
              onClose: {
                withAnimation {
                  showingSampleData = false
                }
              },
              onAddData: openFilePicker
            )

            // Outer Grid: Divide space among devices
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
                  Text(section.displayName)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                  // Inner Grid: Cards within the device section
                  LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16)
                  {
                    ForEach(section.records) { record in
                      NavigationLink(destination: RecordDetailView(record: record)) {
                        RecordRowView(record: record)
                          .padding()
                          .background(Color(uiColor: .secondarySystemGroupedBackground))
                          .clipShape(RoundedRectangle(cornerRadius: 12))
                      }
                      .buttonStyle(.plain)
                    }
                  }
                }
              }
            }
          }
          .padding(20)
        }
      }
      .background(Color(uiColor: .systemGroupedBackground))
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { showingReorderSheet = true }) {
            Image(systemName: "arrow.up.arrow.down")
          }
        }
      }
      .sheet(isPresented: $showingReorderSheet) {
        DeviceReorderView(
          items: deviceSections.map { $0.id },
          onSave: { newOrder in
            appSettings.deviceSortOrder = newOrder
          }
        )
      }
    } else {
      // サンプルデータリスト（バナーもリスト内でスクロール）
      List {
        // サンプルデータバナー（リストの一部としてスクロール）
        Section {
          SampleDataBanner(
            onClose: {
              withAnimation {
                showingSampleData = false
              }
            },
            onAddData: openFilePicker
          )
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
        }

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
                  .opacity(0.85)
                  .contentShape(Rectangle())
                  .onTapGesture {
                    selectedRecord = record
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
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: { showingReorderSheet = true }) {
            Image(systemName: "arrow.up.arrow.down")
          }
        }
      }
      .sheet(isPresented: $showingReorderSheet) {
        DeviceReorderView(
          items: deviceSections.map { $0.id },
          onSave: { newOrder in
            appSettings.deviceSortOrder = newOrder
          }
        )
      }
    }
  }

  private var deviceSections: [DeviceSection] {
    var sections: [DeviceSection] = []
    var indexForDevice: [String: Int] = [:]
    for record in sampleRecords {
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

// MARK: - サンプルデータバナー
struct SampleDataBanner: View {
  let onClose: () -> Void
  let onAddData: () -> Void
  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "eye.fill")
        .foregroundStyle(appSettings.accentColor.color)

      VStack(alignment: .leading, spacing: 2) {
        Text(String(localized: "sample_data_viewing"))
          .font(.subheadline)
          .fontWeight(.medium)
        Text(String(localized: "sample_data_hint"))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button(String(localized: "add_data")) {
        onAddData()
      }
      .font(.caption)
      .buttonStyle(.borderedProminent)

      Button {
        onClose()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
}

#Preview {
  SampleDataHomeView(
    showingSampleData: .constant(true), selectedRecord: .constant(nil), openFilePicker: {})
}
