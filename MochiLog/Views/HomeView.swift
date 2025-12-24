// HomeView.swift
// 別ファイルへ分離
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Charts

// MARK: - メインタブビュー
struct MainTabView: View {
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      HomeView()
        .tabItem {
          Label(String(localized: "tab_home"), systemImage: "house.fill")
        }
        .tag(0)
      AnalyticsView()
        .tabItem {
          Label(String(localized: "tab_analytics"), systemImage: "chart.line.uptrend.xyaxis")
        }
        .tag(1)
      SettingsView()
        .tabItem {
          Label(String(localized: "tab_settings"), systemImage: "gearshape.fill")
        }
        .tag(2)
    }
    .tint(.green)
  }
}

// MARK: - ホームビュー本体
struct HomeView: View {
  @Environment(\.modelContext) private var modelContext
  @Query(sort: \BatteryRecord.logDate, order: .reverse) private var records: [BatteryRecord]
  @StateObject private var appSettings = AppSettings.shared

  @State private var showingFilePicker = false
  @State private var showingErrorAlert = false
  @State private var errorMessage = ""
  @State private var selectedRecord: BatteryRecord?
  @State private var pendingParseResult: LogParser.ParseResult?
  @State private var showingWatchSelection = false
  @State private var isProcessing = false
  @State private var showingMismatchAlert = false
  @State private var showingManualDevicePicker = false
  @State private var showingRegisterWatchAlert = false
  @State private var watchNameToRegister = ""

  // 本体のUIと navigation, toolbars
  var body: some View {
    // ...本体実装は ContentView.swift の HomeView 本体部分からコピペ...
  }
}
