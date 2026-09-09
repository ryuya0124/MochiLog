import SwiftUI

struct GeneralSettingsView: View {
  @ObservedObject var appSettings: AppSettings

  var body: some View {
    List {
      Section {
        RecordInfoToggle()
        RenderingSettingsRow()
        Picker(selection: $appSettings.accentColor) {
          ForEach(AppSettings.ThemeColor.allCases) { theme in
            Text(theme.localizedName).tag(theme)
          }
        } label: {
          Label(L10n.string("accent_color", table: "Settings"), systemImage: "paintpalette")
        }
        .pickerStyle(.menu)
      } header: {
        Text(L10n.string("general", table: "Settings"))
      } footer: {
        Text(L10n.string("accent_color_description", table: "Settings"))
      }

      if #available(iOS 17, *) {
        Section {
          ICloudSettingsContentView(appSettings: appSettings)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
        } header: {
          Text(L10n.string("icloud_sync_settings", defaultValue: "iCloud Sync", table: "Settings"))
        }
      }

      Section {
        Button {
          appSettings.showingSampleData = true
          appSettings.selectedTabIndex = 0
        } label: {
          Label(L10n.string("view_sample_data", table: "Home"), systemImage: "eye")
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
      } footer: {
        Text(L10n.string("sample_data_description", table: "Settings"))
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Color(uiColor: .systemGroupedBackground))
    .groupBoxStyle(SettingsCardGroupBoxStyle())
    .environment(\.defaultMinListRowHeight, 52)
  }
}

struct RecordInfoToggle: View {
  @AppStorage("showRecordInfoButtons") private var showInfoButtons = false

  var body: some View {
    Toggle(isOn: $showInfoButtons) {
      VStack(alignment: .leading, spacing: 4) {
        Text(L10n.string("show_record_info", table: "Settings"))
        Text(L10n.string("show_record_info_description", table: "Settings"))
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .accessibilityIdentifier("settings.recordInfo")
  }
}
