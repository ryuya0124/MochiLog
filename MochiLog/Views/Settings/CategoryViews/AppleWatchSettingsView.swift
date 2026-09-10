import SwiftUI

// MARK: - Apple Watch設定ビュー
struct AppleWatchSettingsView: View {
  @Binding var showingWatchPicker: Bool
  @ObservedObject var appSettings: AppSettings

  // 削除確認用の状態
  @State private var showingRemoveConfirmation = false
  @State private var watchToRemove: String?
  @State private var showingRemoveAllConfirmation = false

  var body: some View {
    watchList
      .alert(
        L10n.string("remove_watch", table: "Settings"),
        isPresented: $showingRemoveConfirmation
      ) {
        Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
        Button(L10n.string("remove", table: "Common"), role: .destructive) {
          if let watch = watchToRemove {
            appSettings.removeWatch(model: watch)
          }
        }
      } message: {
        if let watch = watchToRemove {
          Text(
            String(
              format: L10n.string("remove_watch_confirm_specific", table: "Settings"), watch))
        }
      }
      .alert(
        L10n.string("remove_all_watches", table: "Settings"),
        isPresented: $showingRemoveAllConfirmation
      ) {
        Button(L10n.string("cancel", table: "Common"), role: .cancel) {}
        Button(L10n.string("remove", table: "Common"), role: .destructive) {
          appSettings.unregisterAllWatches()
        }
      } message: {
        Text(L10n.string("remove_all_watches_confirm", table: "Settings"))
      }
  }

  private var watchList: some View {
    List {
      Section {
        watchShowcaseCard
          .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
          .listRowBackground(Color.clear)
      }

      Section {
        if appSettings.registeredWatches.isEmpty {
          HStack {
            Label(
              L10n.string("registered_watch", table: "Settings"),
              systemImage: "applewatch")
            Spacer()
            Text(L10n.string("not_registered", table: "Settings"))
              .foregroundStyle(.secondary)
          }
        } else {
          ForEach(appSettings.registeredWatches, id: \.self) { watchModel in
            watchRow(for: watchModel)
          }
        }

        Button(action: { showingWatchPicker = true }) {
          Label(
            L10n.string("add_watch", table: "Settings"),
            systemImage: "plus.circle"
          )
        }

        if appSettings.registeredWatches.count > 1 {
          Button(action: { showingRemoveAllConfirmation = true }) {
            Label(
              L10n.string("remove_all_watches", table: "Settings"),
              systemImage: "trash"
            )
            .foregroundStyle(.red)
          }
        }
      } header: {
        watchSectionHeader
      } footer: {
        watchSectionFooter
      }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
  }

  private func watchRow(for watchModel: String) -> some View {
    return HStack(spacing: 12) {
      Label(DeviceLibrary.localizedName(for: watchModel), systemImage: "applewatch")
      Spacer()
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button(role: .destructive) {
        watchToRemove = watchModel
        showingRemoveConfirmation = true
      } label: {
        Label(L10n.string("remove", table: "Common"), systemImage: "trash")
      }
      .tint(.red)
    }
  }

  private var watchSectionHeader: some View {
    Text(L10n.string("apple_watch_settings", table: "Settings"))
  }

  private var watchSectionFooter: some View {
    Text(watchDescriptionText)
  }

  private var watchDescriptionText: String {
    appSettings.registeredWatches.isEmpty
      ? L10n.string("watch_selection_description", table: "Settings")
      : L10n.string("multiple_watch_description", table: "Settings")
  }

  private var primaryWatchModel: String? {
    appSettings.registeredWatches.first
  }

  private var watchShowcaseCard: some View {
    VStack(spacing: 12) {
      AppleWatchMockupView(
        modelName: primaryWatchModel,
        isRegistered: primaryWatchModel != nil
      )
      .frame(maxWidth: .infinity)
      .frame(height: 240)

      VStack(alignment: .leading, spacing: 6) {
        if primaryWatchModel != nil {
          Text(L10n.string("registered", table: "Settings"))
            .font(.subheadline)
            .foregroundStyle(.green)
        }

        Text(watchDescriptionText)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color(.secondarySystemGroupedBackground))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color(uiColor: .separator).opacity(0.2), lineWidth: 1)
    )
  }
}
