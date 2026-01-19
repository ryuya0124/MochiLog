import SwiftUI

// MARK: - Apple Watch設定ビュー
struct AppleWatchSettingsView: View {
  @Binding var showingWatchPicker: Bool
  @Binding var showingRemoveWatchConfirmation: Bool
  @ObservedObject var appSettings: AppSettings

  // 登録されているWatch機種を取得
  private var selectedWatchModel: WatchModel {
    guard let modelName = appSettings.registeredWatchModel else {
      return .series9_41mm  // デフォルト
    }

    // モデル名から適切なWatchModelを選択
    if modelName.contains("Ultra") {
      return .ultra2
    } else if modelName.contains("45mm") {
      return .series9_45mm
    } else if modelName.contains("44mm") {
      return .se_44mm
    } else if modelName.contains("40mm") {
      return .se_40mm
    } else {
      return .series9_41mm
    }
  }

  var body: some View {
    VStack(spacing: 16) {
      // Apple Watchプレビューエリア（2列レイアウト）
      GroupBox {
        HStack(alignment: .top, spacing: 24) {
          // 左側：Watchモックアップ（40%）
          WatchFrameContainer(
            model: selectedWatchModel,
            isRegistered: appSettings.registeredWatchModel != nil
          ) {
            WatchFaceView(isRegistered: appSettings.registeredWatchModel != nil)
          }
          .frame(maxWidth: .infinity)

          // 右側：登録済みWatch情報（60%、大きめ表示）
          VStack(alignment: .leading, spacing: 16) {
            Spacer()

            HStack(spacing: 12) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.title2)
                .opacity(appSettings.registeredWatchModel != nil ? 1 : 0)

              Text(
                appSettings.registeredWatchModel != nil
                  ? String(localized: "registered_watch", table: "Settings")
                  : String(localized: "not_registered", table: "Settings")
              )
              .font(.title3)
              .fontWeight(.semibold)
            }

            if let model = appSettings.registeredWatchModel {
              Text(model)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
          }
          .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
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
