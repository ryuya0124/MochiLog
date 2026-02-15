import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - データ管理設定ビュー
struct DataManagementSettingsView: View {
  @Binding var showingDeleteAllConfirmation: Bool
  @Binding var showingDeleteDeviceConfirmation: Bool
  @Binding var deletingDeviceId: String?
  @ObservedObject var appSettings: AppSettings
  let availableDevices: [String]  // 外部から受け取る
  let records: [BatteryRecord]  // エクスポート用
  let modelContext: ModelContext  // インポート用

  @State private var showingExportSheet = false
  @State private var showingImportSheet = false
  @State private var showingImportAlert = false
  @State private var importResultMessage = ""
  @State private var showingExportError = false
  @State private var exportErrorMessage = ""

  var body: some View {
    VStack(spacing: 16) {
      exportSection
      importSection

      deviceSelectionSection

      if deletingDeviceId != nil {
        deleteDeviceButtonSection
      }

      deleteAllSection
    }
    .padding(.horizontal)
    .fileExporter(
      isPresented: $showingExportSheet,
      document: YAMLDocument(yaml: generateExportYAML()),
      contentType: .yaml,
      defaultFilename: DataExportService.generateFileName()
    ) { result in
      handleExportResult(result)
    }
    .fileImporter(
      isPresented: $showingImportSheet,
      allowedContentTypes: [.yaml],
      allowsMultipleSelection: false
    ) { result in
      handleImportResult(result)
    }
    .alert(
      String(localized: "import_result_title", table: "Settings"), isPresented: $showingImportAlert
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(importResultMessage)
    }
    .alert(
      String(localized: "export_error_title", table: "Settings"), isPresented: $showingExportError
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(exportErrorMessage)
    }
  }

  // MARK: - エクスポートセクション
  private var exportSection: some View {
    GroupBox {
      Button {
        showingExportSheet = true
      } label: {
        HStack(spacing: 20) {
          Image(systemName: "square.and.arrow.up.fill")
            .font(.system(size: 36))
            .foregroundStyle(.blue)
            .frame(width: 60)

          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "export_data", table: "Settings"))
              .font(.headline)
              .foregroundStyle(.primary)

            Text(String(localized: "export_data_description", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 8)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - インポートセクション
  private var importSection: some View {
    GroupBox {
      Button {
        showingImportSheet = true
      } label: {
        HStack(spacing: 20) {
          Image(systemName: "square.and.arrow.down.fill")
            .font(.system(size: 36))
            .foregroundStyle(.green)
            .frame(width: 60)

          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "import_data", table: "Settings"))
              .font(.headline)
              .foregroundStyle(.primary)

            Text(String(localized: "import_data_description", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 8)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - デバイス選択セクション
  private var deviceSelectionSection: some View {
    GroupBox {
      HStack(spacing: 20) {
        Image(systemName: "externaldrive.fill")
          .font(.system(size: 36))
          .foregroundStyle(.orange)
          .frame(width: 60)

        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(String(localized: "delete_device_data", table: "Settings"))
              .font(.headline)
            Spacer()
            Picker(
              "",
              selection: Binding(
                get: { deletingDeviceId ?? "" },
                set: { deletingDeviceId = $0.isEmpty ? nil : $0 }
              )
            ) {
              Text(String(localized: "select_device", table: "Settings"))
                .tag("")
              ForEach(availableDevices, id: \.self) { device in
                Text(device)
                  .tag(device)
              }
            }
            .pickerStyle(.menu)
          }

          Text(String(localized: "delete_device_data_description", table: "Settings"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 8)
    }
  }

  // MARK: - デバイス削除ボタンセクション
  private var deleteDeviceButtonSection: some View {
    GroupBox {
      Button(role: .destructive) {
        showingDeleteDeviceConfirmation = true
      } label: {
        HStack(spacing: 16) {
          Image(systemName: "trash.fill")
            .font(.system(size: 28))
            .frame(width: 50)
            .foregroundStyle(.red)

          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "delete_selected_device_data", table: "Settings"))
              .font(.headline)
              .foregroundStyle(.red)

            Text(String(localized: "delete_selected_device_description", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .padding(.vertical, 8)
      }
      .buttonStyle(.plain)
      .tint(.red)
    }
  }

  // MARK: - 全削除セクション
  private var deleteAllSection: some View {
    GroupBox {
      Button(role: .destructive) {
        showingDeleteAllConfirmation = true
      } label: {
        HStack(spacing: 20) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 36))
            .foregroundStyle(.red)
            .frame(width: 60)

          VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "delete_all_data", table: "Settings"))
              .font(.headline)
              .foregroundStyle(.red)

            Text(String(localized: "delete_all_data_description", table: "Settings"))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }

          Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 8)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Helper Functions

  /// エクスポート用YAMLを生成
  private func generateExportYAML() -> String {
    do {
      return try DataExportService.exportToYAML(records: records)
    } catch {
      return "# Export failed: \(error.localizedDescription)"
    }
  }

  /// エクスポート結果を処理
  private func handleExportResult(_ result: Result<URL, Error>) {
    switch result {
    case .success:
      // 成功時は特に何もしない（システムが保存完了を通知）
      break
    case .failure(let error):
      exportErrorMessage = error.localizedDescription
      showingExportError = true
    }
  }

  /// インポート結果を処理
  private func handleImportResult(_ result: Result<[URL], Error>) {
    switch result {
    case .success(let urls):
      guard let url = urls.first else { return }

      Task {
        // セキュリティスコープ付きリソースへのアクセスを開始
        guard url.startAccessingSecurityScopedResource() else {
          await MainActor.run {
            importResultMessage =
              String(
                localized: "import_error",
                table: "Settings"
              ) + ": ファイルへのアクセス権限がありません"
            showingImportAlert = true
          }
          return
        }

        defer {
          url.stopAccessingSecurityScopedResource()
        }

        do {
          let importResult = try DataImportService.importFromYAML(
            url: url,
            modelContext: modelContext,
            existingRecords: records,
            allowDuplicates: appSettings.allowDuplicateRecords
          )

          await MainActor.run {
            if importResult.hasErrors {
              importResultMessage = String(
                localized: "import_partial_success",
                table: "Settings"
              ).replacingOccurrences(of: "{imported}", with: "\(importResult.importedRecords)")
                .replacingOccurrences(of: "{skipped}", with: "\(importResult.skippedDuplicates)")
                .replacingOccurrences(of: "{errors}", with: "\(importResult.errors.count)")
            } else if importResult.skippedDuplicates > 0 {
              importResultMessage = String(
                localized: "import_success_with_duplicates",
                table: "Settings"
              ).replacingOccurrences(of: "{imported}", with: "\(importResult.importedRecords)")
                .replacingOccurrences(of: "{skipped}", with: "\(importResult.skippedDuplicates)")
            } else {
              importResultMessage = String(
                localized: "import_success",
                table: "Settings"
              ).replacingOccurrences(of: "{count}", with: "\(importResult.importedRecords)")
            }
            showingImportAlert = true
          }
        } catch {
          await MainActor.run {
            importResultMessage =
              String(
                localized: "import_error",
                table: "Settings"
              ) + ": \(error.localizedDescription)"
            showingImportAlert = true
          }
        }
      }

    case .failure(let error):
      importResultMessage =
        String(
          localized: "import_error",
          table: "Settings"
        ) + ": \(error.localizedDescription)"
      showingImportAlert = true
    }
  }
}
