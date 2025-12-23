import SwiftData
import SwiftUI

// MARK: - 設定ビュー
struct SettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var records: [BatteryRecord]
  @StateObject private var appSettings = AppSettings.shared

  @State private var showingWatchPicker = false
  @State private var showingDeleteConfirmation = false
  @State private var showingTutorial = false
  @State private var showingSupportForm = false

  private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "\(version) (\(build))"
  }

  var body: some View {
    NavigationStack {
      List {
        // MARK: - Apple Watch 設定
        Section {
          HStack {
            Label(String(localized: "registered_watch"), systemImage: "applewatch")
            Spacer()
            Text(appSettings.registeredWatchModel ?? String(localized: "not_registered"))
              .foregroundStyle(.secondary)
          }

          Button(action: { showingWatchPicker = true }) {
            Label(
              appSettings.registeredWatchModel == nil
                ? String(localized: "register_watch")
                : String(localized: "change_watch"),
              systemImage: "plus.circle"
            )
          }

          if appSettings.registeredWatchModel != nil {
            Button(role: .destructive, action: { appSettings.unregisterWatch() }) {
              Label(String(localized: "remove_watch"), systemImage: "minus.circle")
            }
          }
        } header: {
          Text(String(localized: "apple_watch_settings"))
        } footer: {
          Text(String(localized: "watch_selection_description"))
        }

        // MARK: - サポート
        Section(String(localized: "support")) {
          Button(action: { showingTutorial = true }) {
            Label(String(localized: "view_tutorial"), systemImage: "book.fill")
          }

          Button(action: { showingSupportForm = true }) {
            Label(String(localized: "contact_support"), systemImage: "envelope.fill")
          }

          Link(destination: URL(string: "https://google.com")!) {
            Label(String(localized: "privacy_policy"), systemImage: "hand.raised.fill")
          }
        }

        // MARK: - データ管理
        Section(String(localized: "data_management")) {
          Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
            Label(String(localized: "delete_all_data"), systemImage: "trash.fill")
          }
          .disabled(records.isEmpty)
        }

        // MARK: - アプリ情報
        Section {
          LabeledContent(String(localized: "app_version"), value: appVersion)
        }
      }
      .navigationTitle(String(localized: "settings"))
      .sheet(isPresented: $showingWatchPicker) {
        WatchPickerView(appSettings: appSettings)
      }
      .sheet(isPresented: $showingTutorial) {
        TutorialView()
      }
      .sheet(isPresented: $showingSupportForm) {
        SupportFormView()
      }
      .alert(String(localized: "delete_all_data"), isPresented: $showingDeleteConfirmation) {
        Button(String(localized: "cancel"), role: .cancel) {}
        Button(String(localized: "delete"), role: .destructive) {
          deleteAllRecords()
        }
      } message: {
        Text(String(localized: "delete_all_data_confirm"))
      }
    }
  }

  private func deleteAllRecords() {
    for record in records {
      modelContext.delete(record)
    }
    try? modelContext.save()
  }
}

// MARK: - Apple Watch 選択ビュー
struct WatchPickerView: View {
  @ObservedObject var appSettings: AppSettings
  @Environment(\.dismiss) private var dismiss
  @State private var searchText = ""

  private var filteredModels: [String] {
    let models = appSettings.availableWatchModels()
    if searchText.isEmpty {
      return models
    }
    return models.filter { $0.localizedCaseInsensitiveContains(searchText) }
  }

  var body: some View {
    NavigationStack {
      List(filteredModels, id: \.self) { model in
        Button(action: {
          appSettings.registerWatch(model: model)
          dismiss()
        }) {
          HStack {
            Text(model)
              .foregroundStyle(.primary)
            Spacer()
            if appSettings.registeredWatchModel == model {
              Image(systemName: "checkmark")
                .foregroundStyle(.green)
            }
          }
        }
      }
      .searchable(text: $searchText, prompt: String(localized: "search"))
      .navigationTitle(String(localized: "select_device"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "cancel")) { dismiss() }
        }
      }
    }
  }
}

#Preview {
  SettingsView()
    .modelContainer(for: BatteryRecord.self, inMemory: true)
}
