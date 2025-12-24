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
  @State private var showingDonation = false
  @State private var showingPrivacyPolicy = false
  @State private var showingTermsOfUse = false
  @State private var isAdvancedExpanded = false

  // iCloud トグル用ローカル状態とエラー表示
  @State private var localICloudToggle: Bool = false
  @State private var showingICloudErrorAlert = false
  @State private var iCloudErrorMessage: String = ""

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

          Button(action: { showingDonation = true }) {
            Label(String(localized: "donation_title"), systemImage: "heart.fill")
          }
          Button(action: { showingPrivacyPolicy = true }) {
            Label(String(localized: "privacy_policy"), systemImage: "hand.raised.fill")
          }

          Button(action: { showingTermsOfUse = true }) {
            Label(String(localized: "terms_of_use"), systemImage: "doc.plaintext")
          }
        }

        // MARK: - データ管理
        Section(String(localized: "data_management")) {
          Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
            Label(String(localized: "delete_all_data"), systemImage: "trash.fill")
          }
          .disabled(records.isEmpty)
        }

        // MARK: - 同期
        Section(String(localized: "sync")) {
          Toggle(String(localized: "enable_icloud_sync"), isOn: $localICloudToggle)
            .onChange(of: localICloudToggle) { newValue in
              let result = appSettings.attemptSetICloudSync(newValue)
              switch result {
              case .success:
                // OK
                break
              case .failure(let err):
                // Revert toggle and show error
                localICloudToggle = appSettings.iCloudSyncEnabled
                iCloudErrorMessage = err.errorDescription ?? String(localized: "icloud_sync_failed")
                showingICloudErrorAlert = true
              }
            }

          if let blocked = appSettings.iCloudSyncBlockedReason {
            Text(blocked)
              .font(.caption)
              .foregroundColor(.red)
          }
        }

        // MARK: - 高度な設定
        Section {
          DisclosureGroup(String(localized: "advanced_settings"), isExpanded: $isAdvancedExpanded) {
            VStack(spacing: 16) {
              Toggle(
                String(localized: "enable_capacity_validation"),
                isOn: $appSettings.enableCapacityValidation
              )
              .padding(.top, 8)

              if appSettings.enableCapacityValidation {
                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Text(String(localized: "validation_threshold"))
                    Spacer()
                    Text(String(format: "%.1f x", appSettings.capacityValidationThreshold))
                      .monospacedDigit()
                      .foregroundStyle(.secondary)
                  }
                  Slider(value: $appSettings.capacityValidationThreshold, in: 2...20, step: 0.5)
                }

                Picker(
                  String(localized: "mismatch_behavior"), selection: $appSettings.mismatchBehavior
                ) {
                  ForEach(AppSettings.MismatchBehavior.allCases) { behavior in
                    Text(behavior.localizedName).tag(behavior)
                  }
                }
              }

              Text(String(localized: "validation_threshold_description"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(String(localized: "icloud_storage_threshold"))
                  Spacer()
                  Text(String(format: "%.0f MB", appSettings.iCloudStorageThresholdMB))
                    .foregroundStyle(.secondary)
                }
                Slider(value: $appSettings.iCloudStorageThresholdMB, in: 10...1024, step: 10)
              }

              if let blocked = appSettings.iCloudSyncBlockedReason {
                Text(blocked)
                  .font(.caption)
                  .foregroundColor(.red)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
            }
          }
        }

        // MARK: - アプリ情報
        Section {
          LabeledContent(String(localized: "app_version"), value: appVersion)
        }
      }
      .navigationTitle(String(localized: "settings"))
      .onAppear { localICloudToggle = appSettings.iCloudSyncEnabled }
      .sheet(isPresented: $showingWatchPicker) {
        HierarchicalDevicePickerView(initialCategory: .watch, lockCategory: true) {
          name, identifier in
          appSettings.registerWatch(model: name)
        }
      }
      .sheet(isPresented: $showingTutorial) {
        TutorialView()
      }
      .sheet(isPresented: $showingSupportForm) {
        SupportFormView()
      }
      .sheet(isPresented: $showingDonation) {
        DonationView()
      }
      .sheet(isPresented: $showingPrivacyPolicy) {
        PrivacyPolicyView()
      }
      .sheet(isPresented: $showingTermsOfUse) {
        TermsOfUseView()
      }
      .alert(String(localized: "delete_all_data"), isPresented: $showingDeleteConfirmation) {
        Button(String(localized: "cancel"), role: .cancel) {}
        Button(String(localized: "delete"), role: .destructive) {
          deleteAllRecords()
        }
      } message: {
        Text(String(localized: "delete_all_data_confirm"))
      }
      .alert(String(localized: "icloud_sync_failed"), isPresented: $showingICloudErrorAlert) {
        Button(String(localized: "ok"), role: .cancel) {}
      } message: {
        Text(iCloudErrorMessage)
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

#Preview {
  SettingsView()
    .modelContainer(for: BatteryRecord.self, inMemory: true)
}
