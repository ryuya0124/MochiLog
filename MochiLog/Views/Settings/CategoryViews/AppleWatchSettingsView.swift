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
    VStack(spacing: 16) {
      // 登録済みWatchリスト
      if !appSettings.registeredWatches.isEmpty {
        GroupBox {
          VStack(spacing: 0) {
            ForEach(appSettings.registeredWatches, id: \.self) { watchModel in
              WatchListRow(
                watchModel: watchModel,
                onDelete: {
                  watchToRemove = watchModel
                  showingRemoveConfirmation = true
                }
              )

              if watchModel != appSettings.registeredWatches.last {
                Divider()
                  .padding(.leading, 44)
              }
            }
          }
        }
      } else {
        // Watch未登録時のプレースホルダー
        GroupBox {
          HStack(spacing: 16) {
            Image(systemName: "applewatch")
              .font(.system(size: 40))
              .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "not_registered", table: "Settings"))
                .font(.headline)
              Text(String(localized: "watch_selection_description", table: "Settings"))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
          }
          .padding(.vertical, 8)
        }
      }

      // Watchを追加ボタン
      GroupBox {
        Button(action: { showingWatchPicker = true }) {
          HStack {
            Image(systemName: "plus.circle.fill")
              .font(.title3)
              .foregroundStyle(.green)

            Text(String(localized: "add_watch", table: "Settings"))
              .font(.headline)

            Spacer()
          }
          .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
      }

      // すべて削除ボタン（複数登録時のみ表示）
      if appSettings.registeredWatches.count > 1 {
        GroupBox {
          Button(action: { showingRemoveAllConfirmation = true }) {
            HStack {
              Image(systemName: "trash")
                .font(.title3)
                .foregroundStyle(.red)

              Text(String(localized: "remove_all_watches", table: "Settings"))
                .font(.headline)
                .foregroundStyle(.red)

              Spacer()
            }
            .padding(.vertical, 8)
          }
          .buttonStyle(.plain)
        }
      }

      // 説明テキスト
      if !appSettings.registeredWatches.isEmpty {
        Text(String(localized: "multiple_watch_description", table: "Settings"))
          .font(.footnote)
          .foregroundStyle(.secondary)
          .padding(.horizontal)
      }
    }
    .padding(.horizontal)
    .alert(
      String(localized: "remove_watch", table: "Settings"),
      isPresented: $showingRemoveConfirmation
    ) {
      Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
      Button(String(localized: "remove", table: "Common"), role: .destructive) {
        if let watch = watchToRemove {
          appSettings.removeWatch(model: watch)
        }
      }
    } message: {
      if let watch = watchToRemove {
        Text(
          String(
            format: String(localized: "remove_watch_confirm_specific", table: "Settings"), watch))
      }
    }
    .alert(
      String(localized: "remove_all_watches", table: "Settings"),
      isPresented: $showingRemoveAllConfirmation
    ) {
      Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
      Button(String(localized: "remove", table: "Common"), role: .destructive) {
        appSettings.unregisterAllWatches()
      }
    } message: {
      Text(String(localized: "remove_all_watches_confirm", table: "Settings"))
    }
  }
}

// MARK: - Watchリスト行
struct WatchListRow: View {
  let watchModel: String
  let onDelete: () -> Void

  // モデル名からWatchModelを取得
  private var selectedWatchModel: WatchModel {
    if watchModel.contains("Ultra") {
      return .ultra2
    } else if watchModel.contains("45mm") {
      return .series9_45mm
    } else if watchModel.contains("44mm") {
      return .se_44mm
    } else if watchModel.contains("40mm") {
      return .se_40mm
    } else {
      return .series9_41mm
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      // Watchアイコン
      ZStack {
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(.systemGray5))
          .frame(width: 36, height: 44)

        Image(systemName: "applewatch")
          .font(.title3)
          .foregroundStyle(.primary)
      }

      // Watch情報
      VStack(alignment: .leading, spacing: 2) {
        Text(watchModel)
          .font(.body)
          .lineLimit(1)

        Text(String(localized: "registered", table: "Settings"))
          .font(.caption)
          .foregroundStyle(.green)
      }

      Spacer()

      // 削除ボタン
      Button(action: onDelete) {
        Image(systemName: "trash")
          .foregroundStyle(.red)
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 8)
  }
}
