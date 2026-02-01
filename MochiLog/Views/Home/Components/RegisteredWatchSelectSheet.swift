import SwiftUI

/// ログ記録時に登録済みWatchから選択するシート
struct RegisteredWatchSelectSheet: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var appSettings = AppSettings.shared

  let onSelect: (String) -> Void

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(appSettings.registeredWatches, id: \.self) { watchModel in
            // Buttonではなく行全体をタップ可能にする
            HStack {
              Label {
                Text(watchModel)
              } icon: {
                Image(systemName: "applewatch")
                  .foregroundStyle(appSettings.accentColor.color)
              }
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
              let selected = watchModel
              dismiss()
              // シートを閉じた直後にコールバックを実行
              DispatchQueue.main.async {
                onSelect(selected)
              }
            }
          }
        } header: {
          Text(String(localized: "select_registered_watch", table: "Settings"))
        }
      }
      .navigationTitle(String(localized: "select_watch", table: "Settings"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "cancel", table: "Common")) {
            dismiss()
          }
        }
      }
    }
    .tint(appSettings.accentColor.color)
  }
}
