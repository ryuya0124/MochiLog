import SwiftUI

struct ICloudSettingsView: View {
  @ObservedObject var appSettings: AppSettings
  @EnvironmentObject var dataStore: DataStore
  @ObservedObject var syncManager = ICloudSyncManager.shared

  @State private var isSyncing: Bool = false
  @State private var showConflictAlert: Bool = false
  @State private var selectedConflict: SyncConflictItem?
  @State private var isICloudSignedIn: Bool = FileManager.default.ubiquityIdentityToken != nil

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        GroupBox {
          VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $appSettings.iCloudSyncEnabled) {
              Label(
                String(localized: "enable_icloud_sync", defaultValue: "iCloud同期を有効にする", table: "Settings"),
                systemImage: "icloud.fill"
              )
            }
            .font(.headline)
            .onChange(of: appSettings.iCloudSyncEnabled) { newValue in
              Task {
                _ = await appSettings.attemptSetICloudSyncAsync(newValue)
              }
            }

            if appSettings.iCloudSyncEnabled && !dataStore.isICloudEnabled {
              HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundColor(.orange)
                Text(String(localized: "icloud_restart_required", defaultValue: "設定を反映するにはアプリの再起動が必要です。一度アプリを上にスワイプして完全に終了し、開き直してください。", table: "Settings"))
                  .font(.footnote)
                  .foregroundColor(.orange)
              }
            }

            if appSettings.iCloudSyncEnabled && !isICloudSignedIn {
              HStack(alignment: .top, spacing: 6) {
                Image(systemName: "xmark.octagon.fill")
                  .foregroundColor(.red)
                Text(String(localized: "icloud_not_signed_in", defaultValue: "端末がiCloudにサインインしていないか、iCloud Driveが無効になっています。iOSの設定アプリから確認してください。", table: "Settings"))
                  .font(.footnote)
                  .foregroundColor(.red)
              }
            }

            if let reason = appSettings.iCloudSyncBlockedReason {
              Text(reason)
                .font(.footnote)
                .foregroundColor(.red)
            }

            Text(
              String(
                localized: "icloud_sync_footer",
                defaultValue: "iCloud同期をオンにすると、同じApple IDでサインインした複数のデバイス間でバッテリー記録を自動的に共有できます。",
                table: "Settings"
              )
            )
            .font(.subheadline)
            .foregroundColor(.secondary)

            if appSettings.iCloudSyncEnabled {
              Divider()
              
              HStack {
                Text(String(localized: "sync_status", defaultValue: "同期ステータス", table: "Settings"))
                  .font(.subheadline)
                  .foregroundColor(.primary)
                Spacer()
                // 強制同期中は syncManager のステータスに優先して「同期中」を表示
                if isSyncing {
                  HStack(spacing: 8) {
                    Text(String(localized: "status_syncing", defaultValue: "同期中...", table: "Settings"))
                      .font(.subheadline)
                      .foregroundColor(.blue)
                    ProgressView()
                  }
                } else {
                  switch syncManager.lastSyncStatus {
                  case .idle:
                    Text(String(localized: "status_idle", defaultValue: "待機中", table: "Settings"))
                      .font(.subheadline)
                      .foregroundColor(.secondary)
                  case .syncing:
                    HStack(spacing: 8) {
                      Text(String(localized: "status_syncing", defaultValue: "同期中...", table: "Settings"))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                      ProgressView()
                    }
                  case .success:
                    Text(String(localized: "status_success", defaultValue: "成功", table: "Settings"))
                      .font(.subheadline)
                      .foregroundColor(.green)
                  case .error(let message):
                    Text(message)
                      .font(.caption)
                      .foregroundColor(.red)
                      .multilineTextAlignment(.trailing)
                  }
                }
              }

              HStack {
                Text(String(localized: "last_sync_date", defaultValue: "最終同期", table: "Settings"))
                  .font(.subheadline)
                  .foregroundColor(.primary)
                Spacer()
                if appSettings.lastICloudSyncDate > 0 {
                  Text(Date(timeIntervalSince1970: appSettings.lastICloudSyncDate).formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                } else {
                  Text(String(localized: "not_synced_yet", defaultValue: "未同期", table: "Settings"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
              }
              
              // iCloud同期の説明セクション
              VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "icloud_how_sync_works_title", defaultValue: "同期の仕組みについて", table: "Settings"))
                  .font(.caption)
                  .fontWeight(.semibold)
                  .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                  Label(
                    String(localized: "icloud_sync_how1", defaultValue: "同期はアプリ起動時やバックグラウンドで自動的に行われます", table: "Settings"),
                    systemImage: "arrow.triangle.2.circlepath.icloud"
                  )
                  .font(.caption)
                  .foregroundColor(.secondary)

                  Label(
                    String(localized: "icloud_sync_how2", defaultValue: "「強制同期」はローカルの変更をiCloudにプッシュし、既に受信済みのデータを表示に反映します", table: "Settings"),
                    systemImage: "arrow.up.icloud"
                  )
                  .font(.caption)
                  .foregroundColor(.secondary)

                  Label(
                    String(localized: "icloud_sync_how3", defaultValue: "他デバイスのデータを引き出すタイミングはAppleのサーバーが决定します。数秒〜数分かかる場合があります", table: "Settings"),
                    systemImage: "clock"
                  )
                  .font(.caption)
                  .foregroundColor(.secondary)

                  Label(
                    String(localized: "icloud_sync_how4", defaultValue: "強制同期後も表示されない場合は、アプリを完全に終了（スワイプアップ）して再起動すると反映されます", table: "Settings"),
                    systemImage: "arrow.counterclockwise.icloud"
                  )
                  .font(.caption)
                  .foregroundColor(.secondary)
                }
              }
              .padding(.top, 4)
            }

            Divider()

            Button(action: forceSync) {
              HStack {
                Label(
                  String(localized: "force_sync_now", defaultValue: "今すぐ強制同期", table: "Settings"),
                  systemImage: "arrow.triangle.2.circlepath.icloud.fill"
                )
                Spacer()
                if isSyncing {
                  ProgressView()
                }
              }
            }
            .disabled(!appSettings.iCloudSyncEnabled || isSyncing)
            .padding(.vertical, 4)

            // 強制同期の説明
            VStack(alignment: .leading, spacing: 4) {
              Text(String(localized: "force_sync_description", defaultValue: "「強制同期」をタップすると、以下の処理を実行します：", table: "Settings"))
                .font(.caption)
                .foregroundColor(.secondary)

              Text(String(localized: "force_sync_action1", defaultValue: "• 未保存のローカルデータをiCloudに送信", table: "Settings"))
                .font(.caption)
                .foregroundColor(.secondary)

              Text(String(localized: "force_sync_action2", defaultValue: "• iCloudが既に受信済みのデータを画面に反映", table: "Settings"))
                .font(.caption)
                .foregroundColor(.secondary)

              Text(String(localized: "force_sync_note", defaultValue: "※ 他デバイスのデータを引き出すのは Appleのサーバー任せになります。強制同期後にデータが表示されない場合は、数分待ってからアプリを再起動してください。", table: "Settings"))
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .padding(8)
        }

        if !syncManager.unresolvedConflicts.isEmpty {
          GroupBox {
            VStack(alignment: .leading, spacing: 12) {
              Text(String(localized: "unresolved_conflicts", defaultValue: "未解決の競合", table: "Settings"))
                .font(.headline)

              Text(String(localized: "conflict_footer", defaultValue: "タップしてどちらのデータを優先するか選択してください。", table: "Settings"))
                .font(.subheadline)
                .foregroundColor(.secondary)

              Divider()

              ForEach(syncManager.unresolvedConflicts) { conflict in
                Button {
                  selectedConflict = conflict
                  showConflictAlert = true
                } label: {
                  HStack {
                    VStack(alignment: .leading, spacing: 4) {
                      Text(String(localized: "conflict_detected", defaultValue: "競合が検出されました", table: "Settings"))
                        .font(.subheadline)
                        .foregroundColor(.red)
                      Text("端末: \(conflict.localDevice) (ローカル) vs \(conflict.serverDevice) (サーバー)")
                        .font(.caption)
                        .foregroundColor(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                      .foregroundColor(.secondary)
                  }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)

                if conflict.id != syncManager.unresolvedConflicts.last?.id {
                  Divider()
                }
              }
            }
            .padding(8)
          }
        }
      }
      .padding()
    }
    .navigationTitle(String(localized: "icloud_sync", defaultValue: "iCloud同期", table: "Settings"))
    .sheet(item: $selectedConflict) { conflict in
      ConflictDetailView(conflict: conflict)
    }
    .onReceive(NotificationCenter.default.publisher(for: .NSUbiquityIdentityDidChange)) { _ in
      isICloudSignedIn = FileManager.default.ubiquityIdentityToken != nil
    }
    // CloudKitの実際の同期完了イベントに合わせてisSyncingを制御する
    .onChange(of: syncManager.lastSyncStatus) { newStatus in
      guard isSyncing else { return }
      switch newStatus {
      case .success, .error:
        // 同期完了または失敗 → UIに最新データを反映してから処理中フラグを解除
        dataStore.refreshRecords()
        // 少し待ってからもう一度 refresh（CloudKitのimportが遅延して届く場合への対策）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
          dataStore.refreshRecords()
        }
        let previousConflictCount = syncManager.unresolvedConflicts.count
        isSyncing = false
        appSettings.lastICloudSyncDate = Date().timeIntervalSince1970
        // 新たなコンフリクトが発生していたら自動表示
        if syncManager.unresolvedConflicts.count > previousConflictCount,
           let latestConflict = syncManager.unresolvedConflicts.last {
          selectedConflict = latestConflict
        }
      case .syncing, .idle:
        break
      }
    }
  }

  private func forceSync() {
    isSyncing = true
    // ローカルの未保存変更をCloudKitへプッシュ
    dataStore.save()
    // ローカルコンテキストを最新状態に更新（CloudKitが既に取り込んだデータを反映）
    dataStore.refreshRecords()
    // isSyncingの解除は .onChange(of: syncManager.lastSyncStatus) で行う
    // CloudKitが同期イベントを発火しない場合（ネットワーク不通など）のフォールバック
    // 15秒待ってもまだ同期中の場合は強制的に終了してrefreshする
    DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) {
      guard self.isSyncing else { return }
      self.dataStore.refreshRecords()
      self.isSyncing = false
    }
  }
}
