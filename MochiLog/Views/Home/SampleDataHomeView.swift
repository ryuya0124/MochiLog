import SwiftUI

// MARK: - サンプルデータホームビュー
/// データがない時にサンプルデータを表示するビュー
struct SampleDataHomeView: View {
  @Binding var showingSampleData: Bool
  let openFilePicker: () -> Void
  @StateObject private var appSettings = AppSettings.shared
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private let sampleRecords = SampleDataProvider.generateSampleRecords()

  var body: some View {
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
        Section(section.displayName) {
          ForEach(section.records) { record in
            RecordRowView(record: record)
              .opacity(0.85)
          }
        }
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
  SampleDataHomeView(showingSampleData: .constant(true), openFilePicker: {})
}
