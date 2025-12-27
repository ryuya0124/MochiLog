import SwiftUI

// MARK: - サンプルデータホームビュー
/// データがない時にサンプルデータを表示するビュー
/// 共通のRecordListViewを使用してコード重複を排除
struct SampleDataHomeView: View {
  @Binding var showingSampleData: Bool
  @Binding var selectedRecord: BatteryRecord?
  let openFilePicker: () -> Void
  @StateObject private var appSettings = AppSettings.shared
  @State private var showingReorderSheet = false

  private let sampleRecords = SampleDataProvider.generateSampleRecords()

  var body: some View {
    VStack(spacing: 0) {
      // サンプルデータバナー（常に上部に固定）
      SampleDataBanner(
        onClose: {
          withAnimation {
            showingSampleData = false
          }
        },
        onAddData: openFilePicker
      )
      .padding(.horizontal, 20)
      .padding(.top, 12)
      .padding(.bottom, 8)

      // 共通のRecordListViewを使用
      RecordListView(
        records: sampleRecords,
        onRecordTap: { record in
          selectedRecord = record
        },
        onRecordDelete: nil,  // サンプルデータは削除不可
        showContextMenu: false
      )
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
        items: SampleDataProvider.sampleDeviceNames,
        onSave: { newOrder in
          appSettings.deviceSortOrder = newOrder
        }
      )
    }
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
