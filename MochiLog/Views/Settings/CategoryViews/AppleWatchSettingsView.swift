import SwiftUI

// MARK: - Apple Watch設定ビュー
struct AppleWatchSettingsView: View {
  @Binding var showingWatchPicker: Bool
  @Binding var showingRemoveWatchConfirmation: Bool
  @ObservedObject var appSettings: AppSettings

  var body: some View {
    VStack(spacing: 16) {
      // Apple Watchプレビューエリア
      GroupBox {
        VStack(spacing: 16) {
          // Watchモックアップ（リアルな表示）
          AppleWatchMockupView(
            modelName: appSettings.registeredWatchModel,
            isRegistered: appSettings.registeredWatchModel != nil
          )
          .padding(.vertical, 20)

          // 登録済みWatch情報
          VStack(spacing: 4) {
            HStack {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .opacity(appSettings.registeredWatchModel != nil ? 1 : 0)

              Text(
                appSettings.registeredWatchModel != nil
                  ? String(localized: "registered_watch", table: "Settings")
                  : String(localized: "not_registered", table: "Settings")
              )
              .font(.headline)
            }

            if let model = appSettings.registeredWatchModel {
              Text(model)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
        }
        .frame(maxWidth: .infinity)
      }

      // Watchを変更/登録ボタン
      GroupBox {
        Button(action: { showingWatchPicker = true }) {
          HStack {
            Image(systemName: "plus.circle.fill")
              .font(.title3)
              .foregroundStyle(.green)

            Text(
              appSettings.registeredWatchModel == nil
                ? String(localized: "register_watch", table: "Settings")
                : String(localized: "change_watch", table: "Settings")
            )
            .font(.headline)

            Spacer()
          }
          .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
      }

      // 登録を解除ボタン（登録済みの場合のみ表示）
      if appSettings.registeredWatchModel != nil {
        GroupBox {
          Button(role: .destructive, action: { showingRemoveWatchConfirmation = true }) {
            HStack {
              Image(systemName: "minus.circle.fill")
                .font(.title3)

              Text(String(localized: "remove_watch", table: "Settings"))
                .font(.headline)

              Spacer()
            }
            .padding(.vertical, 8)
          }
          .buttonStyle(.plain)
        }
      }

      // 説明テキスト
      Text(String(localized: "watch_selection_description", table: "Settings"))
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }
    .padding(.horizontal)
  }
}
