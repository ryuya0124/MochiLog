import SwiftUI
import UIKit

struct DebugLogsView: View {
  @State private var logs: [ErrorLogEntry] = []
  @State private var showingDeleteAllConfirm = false
  @State private var selectedLog: ErrorLogEntry?
  @State private var isLoading = false

  private func reload() {
    Task {
      await MainActor.run { isLoading = true }
      let results = await Task.detached { await ErrorLogStore.shared.listLogs() }.value
      await MainActor.run {
        logs = results
        isLoading = false
      }
    }
  }

  var body: some View {
    NavigationStack {
      Group {
        if isLoading {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if logs.isEmpty {
          Text(String(localized: "no_error_logs", table: "Support"))
            .foregroundStyle(.secondary)
        } else {
          List {
            ForEach(logs) { log in
              Button(action: { selectedLog = log }) {
                HStack {
                  VStack(alignment: .leading) {
                    Text(log.message)
                      .font(.headline)
                      .lineLimit(1)
                    Text(log.timestamp, style: .date)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                  Spacer()
                  if let preview = log.rawTextPreview {
                    Text(preview)
                      .lineLimit(2)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .fixedSize(horizontal: false, vertical: true)
                  }
                }
              }
              .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                  ErrorLogStore.shared.deleteLog(id: log.id)
                  reload()
                } label: {
                  Label(String(localized: "delete", table: "Common"), systemImage: "trash")
                }
              }
            }
          }
        }
      }
      .navigationTitle(String(localized: "view_error_logs", table: "Support"))
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
        String(localized: "delete_all_logs_confirm", table: "Home"), isPresented: $showingDeleteAllConfirm,
        titleVisibility: .visible
      ) {
        Button(String(localized: "delete", table: "Common"), role: .destructive) {
          ErrorLogStore.shared.clearAll()
          reload()
        }
        Button(String(localized: "cancel", table: "Common"), role: .cancel) {}
      }
      .sheet(item: $selectedLog) { log in
        DebugLogDetailView(entry: log)
      }
    }
  }
}

struct DebugLogDetailView: View {
  let entry: ErrorLogEntry
  @Environment(\.dismiss) private var dismiss
  @State private var rawText: String? = nil
  @State private var loadingRaw = false
  @State private var shareFileURL: URL? = nil

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          Text(entry.message).font(.headline)
          Text(entry.timestamp.description).font(.caption).foregroundStyle(.secondary)
          Divider()
          if loadingRaw {
            ProgressView()
          } else if let txt = rawText {
            Text(txt).font(.body).textSelection(.enabled)
          } else {
            Text(String(localized: "empty_log_preview", table: "Records"))
              .foregroundStyle(.secondary)
          }
        }
        .padding()
        .task {
          loadingRaw = true
          rawText = await Task.detached {
            await ErrorLogStore.shared.readRawText(id: self.entry.id)
          }.value
          loadingRaw = false
          prepareShareFile()
        }
      }
      .navigationTitle(String(localized: "log_details", table: "Records"))
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(String(localized: "close", table: "Common")) { dismiss() }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          if let url = shareFileURL {
            ShareLink(item: url) {
              Text(String(localized: "export_log", table: "Records"))
            }
          } else {
            Button(action: {}) {
              Text(String(localized: "export_log", table: "Records"))
            }
            .disabled(true)
          }
        }
      }
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
