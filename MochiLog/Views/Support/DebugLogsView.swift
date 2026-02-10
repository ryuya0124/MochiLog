import SwiftUI
import UIKit

struct DebugLogsView: View {
  @State private var logs: [ErrorLogEntry] = []
  @State private var showingDeleteAllConfirm = false
  @State private var selectedLog: ErrorLogEntry?
  @State private var isLoading = false
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private func reload() {
    Task {
      await MainActor.run { isLoading = true }
      let results = await Task.detached { await ErrorLogStore.shared.listLogs() }.value
      await MainActor.run {
        logs = results
        isLoading = false
        // iPad: 最初のログを自動選択
        if horizontalSizeClass == .regular && selectedLog == nil && !logs.isEmpty {
          selectedLog = logs.first
        }
      }
    }
  }

  var body: some View {
    NavigationStack {
      Group {
        if isLoading {
          VStack(spacing: 20) {
            ProgressView()
              .scaleEffect(1.5)

            Text(String(localized: "loading_logs", table: "Support"))
              .font(.system(.subheadline, design: .rounded))
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if logs.isEmpty {
          VStack(spacing: 24) {
            ZStack {
              Circle()
                .fill(
                  LinearGradient(
                    colors: [Color.green.opacity(0.6), Color.blue.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .frame(width: 100, height: 100)
                .shadow(color: Color.green.opacity(0.3), radius: 20, x: 0, y: 10)

              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
              Text(String(localized: "no_error_logs_title", table: "Support"))
                .font(.system(.title2, design: .rounded, weight: .bold))

              Text(String(localized: "no_error_logs", table: "Support"))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          if horizontalSizeClass == .regular {
            // iPad: 2カラムレイアウト（左:ログ一覧、右:詳細）
            HStack(spacing: 0) {
              // 左側：ログ一覧
              logListColumn
                .frame(width: 400)

              Divider()

              // 右側：選択されたログの詳細
              logDetailColumn
            }
          } else {
            // iPhone: 通常のList
            List {
              ForEach(logs) { log in
                Button(action: { selectedLog = log }) {
                  logRowView(for: log)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                  Button(role: .destructive) {
                    ErrorLogStore.shared.deleteLog(id: log.id)
                    reload()
                  } label: {
                    Label(String(localized: "delete", table: "Common"), systemImage: "trash")
                  }
                  .tint(.red)
                }
              }
            }
          }
        }
      }
      .navigationTitle(String(localized: "view_error_logs", table: "Support"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          if !logs.isEmpty {
            Button(role: .destructive) {
              showingDeleteAllConfirm = true
            } label: {
              Text(String(localized: "clear_all_logs", table: "Home"))
            }
          }
        }
      }
      .onAppear(perform: reload)
      .confirmationDialog(
        String(localized: "delete_all_logs_confirm", table: "Home"),
        isPresented: $showingDeleteAllConfirm,
        titleVisibility: .visible
      ) {
        Button(String(localized: "delete", table: "Common"), role: .destructive) {
          ErrorLogStore.shared.clearAll()
          reload()
        }
        Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
      }
      .fullScreenCover(item: horizontalSizeClass == .regular ? .constant(nil) : $selectedLog) {
        log in
        DebugLogDetailView(entry: log)
      }
    }
  }

  // MARK: - ログ一覧カラム（iPad）
  private var logListColumn: some View {
    List(logs, selection: $selectedLog) { log in
      Button {
        selectedLog = log
      } label: {
        logRowView(for: log, isSelected: selectedLog?.id == log.id)
      }
      .buttonStyle(.plain)
      .swipeActions(edge: .trailing) {
        Button(role: .destructive) {
          ErrorLogStore.shared.deleteLog(id: log.id)
          if selectedLog?.id == log.id {
            selectedLog = nil
          }
          reload()
        } label: {
          Label(String(localized: "delete", table: "Common"), systemImage: "trash")
        }
        .tint(.red)
      }
    }
    .listStyle(.sidebar)
  }

  // MARK: - ログ詳細カラム（iPad）
  private var logDetailColumn: some View {
    Group {
      if let log = selectedLog {
        DebugLogDetailContentView(entry: log)
      } else {
        VStack(spacing: 24) {
          ZStack {
            Circle()
              .fill(
                LinearGradient(
                  colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.4)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .frame(width: 120, height: 120)
              .shadow(color: Color.purple.opacity(0.3), radius: 20, x: 0, y: 10)

            Image(systemName: "doc.text.magnifyingglass")
              .font(.system(size: 60))
              .foregroundStyle(.white)
          }

          VStack(spacing: 8) {
            Text(String(localized: "select_log_title", table: "Support"))
              .font(.system(.title2, design: .rounded, weight: .bold))

            Text(String(localized: "select_log_message", table: "Support"))
              .font(.system(.body, design: .rounded))
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 40)
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  // MARK: - ログ行ビュー
  private func logRowView(for log: ErrorLogEntry, isSelected: Bool = false) -> some View {
    HStack(spacing: 16) {
      // 左側のアイコン（グラデーション付き）
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [Color.red.opacity(0.8), Color.orange.opacity(0.6)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 50, height: 50)
          .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)

        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 22))
          .foregroundStyle(.white)
      }

      // 中央のコンテンツ
      VStack(alignment: .leading, spacing: 8) {
        Text(log.message)
          .font(.system(.body, design: .rounded, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(2)

        HStack(spacing: 12) {
          HStack(spacing: 4) {
            Image(systemName: "calendar")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(log.timestamp, style: .date)
              .font(.system(.caption, design: .rounded))
              .foregroundStyle(.secondary)
          }

          HStack(spacing: 4) {
            Image(systemName: "clock")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(log.timestamp, style: .time)
              .font(.system(.caption, design: .rounded))
              .foregroundStyle(.secondary)
          }
        }
      }

      Spacer()

      // 右側のシェブロン
      Image(systemName: "chevron.right")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.tertiary)
    }
    .contentShape(Rectangle())
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
    )
  }
}

// MARK: - ログ詳細コンテンツビュー（iPad用、埋め込み可能）
struct DebugLogDetailContentView: View {
  let entry: ErrorLogEntry
  @State private var rawText: String? = nil
  @State private var loadingRaw = false
  @State private var shareFileURL: URL? = nil

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // ヘッダー（グラデーション付き）
        VStack(alignment: .leading, spacing: 16) {
          HStack(spacing: 16) {
            ZStack {
              Circle()
                .fill(
                  LinearGradient(
                    colors: [Color.red.opacity(0.8), Color.orange.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .frame(width: 60, height: 60)
                .shadow(color: Color.red.opacity(0.3), radius: 12, x: 0, y: 6)

              Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
              Text(String(localized: "error_log_title", table: "Support"))
                .font(.system(.title2, design: .rounded, weight: .bold))

              HStack(spacing: 12) {
                Label {
                  Text(entry.timestamp, style: .date)
                    .font(.system(.subheadline, design: .rounded))
                } icon: {
                  Image(systemName: "calendar")
                }

                Label {
                  Text(entry.timestamp, style: .time)
                    .font(.system(.subheadline, design: .rounded))
                } icon: {
                  Image(systemName: "clock")
                }
              }
              .foregroundStyle(.secondary)
            }

            Spacer()
          }
        }
        .padding(20)
        .background(
          RoundedRectangle(cornerRadius: 20)
            .fill(
              LinearGradient(
                colors: [
                  Color(.systemBackground),
                  Color(.secondarySystemGroupedBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 20)
            .strokeBorder(
              LinearGradient(
                colors: [Color.red.opacity(0.3), Color.orange.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1.5
            )
        )

        // メッセージ
        VStack(alignment: .leading, spacing: 12) {
          Label {
            Text(String(localized: "message", table: "Support"))
              .font(.system(.headline, design: .rounded, weight: .semibold))
          } icon: {
            Image(systemName: "text.bubble.fill")
              .foregroundStyle(
                LinearGradient(
                  colors: [Color.blue, Color.cyan],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
          }

          Text(entry.message)
            .font(.system(.body, design: .rounded))
            .textSelection(.enabled)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemGroupedBackground))
            )
        }
        .padding(20)
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Color(.secondarySystemGroupedBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )

        // 生テキスト
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Label {
              Text(String(localized: "details_label", table: "Support"))
                .font(.system(.headline, design: .rounded, weight: .semibold))
            } icon: {
              Image(systemName: "doc.text.fill")
                .foregroundStyle(
                  LinearGradient(
                    colors: [Color.purple, Color.pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
            }

            Spacer()

            if let url = shareFileURL {
              ShareLink(item: url) {
                HStack(spacing: 4) {
                  Image(systemName: "square.and.arrow.up")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                  Text(String(localized: "share_label", table: "Support"))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                  Capsule()
                    .fill(Color.accentColor.opacity(0.15))
                )
                .contentShape(Capsule())
              }
            }
          }

          if loadingRaw {
            ProgressView()
              .frame(maxWidth: .infinity)
              .padding(32)
          } else if let txt = rawText {
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
              Text(txt)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(Color(.tertiarySystemGroupedBackground))
            )
          } else {
            Text(String(localized: "empty_log_preview", table: "Records"))
              .foregroundStyle(.secondary)
              .font(.system(.body, design: .rounded))
              .frame(maxWidth: .infinity)
              .padding(32)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(Color(.tertiarySystemGroupedBackground))
              )
          }
        }
        .padding(20)
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Color(.secondarySystemGroupedBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        )
      }
      .padding(20)
    }
    .background(Color(.systemGroupedBackground))
    .task {
      loadingRaw = true
      rawText = await Task.detached {
        await ErrorLogStore.shared.readRawText(id: entry.id)
      }.value
      loadingRaw = false
      prepareShareFile()
    }
  }

  private func prepareShareFile() {
    // Prefer the raw .txt if available
    if let url = ErrorLogStore.shared.rawFileURL(id: entry.id) {
      shareFileURL = url
    } else if let txt = rawText ?? ErrorLogStore.shared.readRawText(id: entry.id) {
      // write a temporary .txt file to share
      let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("\(entry.id).txt")
      try? txt.write(to: tmp, atomically: true, encoding: .utf8)
      shareFileURL = tmp
    } else if let data = try? JSONEncoder().encode(entry) {
      // fallback to JSON representation
      let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("\(entry.id).json")
      try? data.write(to: tmp)
      shareFileURL = tmp
    }
  }
}

// MARK: - ログ詳細ビュー（iPhone用フルスクリーン）
struct DebugLogDetailView: View {
  let entry: ErrorLogEntry
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      DebugLogDetailContentView(entry: entry)
        .navigationTitle(String(localized: "log_details", table: "Records"))
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button(String(localized: "close", table: "Common")) { dismiss() }
          }
        }
    }
  }
}
