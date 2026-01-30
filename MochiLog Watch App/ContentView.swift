//
//  ContentView.swift
//  MochiLog Watch App
//
//  Created by りゅうや on 2026/01/30.
//

import SwiftUI

/// メインコンテンツビュー - デバイス一覧を表示
struct ContentView: View {
  @EnvironmentObject var connectivityManager: WatchConnectivityManager

  var body: some View {
    NavigationStack {
      Group {
        if connectivityManager.records.isEmpty {
          emptyStateView
        } else {
          deviceListView
        }
      }
      .navigationTitle("MochiLog")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  // MARK: - デバイス一覧

  private var deviceListView: some View {
    List {
      ForEach(groupedDevices, id: \.name) { device in
        NavigationLink(
          destination: RecordListView(deviceName: device.name, records: device.records)
        ) {
          DeviceCard(device: device)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
        .listRowBackground(Color.clear)
      }

      // 最終同期情報
      if let lastSync = connectivityManager.lastSyncDate {
        Section {
          HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.2.circlepath")
              .font(.caption2)
            Text("最終同期: \(lastSync, style: .relative)")
          }
          .font(.caption2)
          .foregroundStyle(.secondary)
          .padding(.vertical, 2)
        }
        .listRowBackground(Color.clear)
      }
    }
    .listStyle(.plain)
  }

  // MARK: - 空の状態

  private var emptyStateView: some View {
    ScrollView {
      VStack(spacing: 16) {
        Spacer()
          .frame(height: 20)

        // アイコン
        ZStack {
          Circle()
            .fill(
              LinearGradient(
                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 70, height: 70)

          Image(systemName: "applewatch.watchface")
            .font(.system(size: 36))
            .foregroundStyle(
              LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
        }

        // メインメッセージ
        VStack(spacing: 8) {
          Text("データ待機中")
            .font(.headline)
            .fontWeight(.semibold)

          Text("iPhoneでバッテリーログを追加すると\n自動的に同期されます")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
        }

        // 同期ステータス
        VStack(spacing: 8) {
          if connectivityManager.isReachable {
            Label("iPhone接続中", systemImage: "checkmark.circle.fill")
              .font(.caption2)
              .foregroundStyle(.green)
          } else {
            Label("iPhone未接続", systemImage: "iphone.slash")
              .font(.caption2)
              .foregroundStyle(.orange)
          }

          if let lastSync = connectivityManager.lastSyncDate {
            Text("最終同期: \(lastSync, style: .relative)")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }

        // エラーメッセージ
        if let error = connectivityManager.syncError {
          Text(error)
            .font(.caption2)
            .foregroundStyle(.red)
            .padding(.horizontal)
            .multilineTextAlignment(.center)
        }

        // 同期ボタン
        Button {
          connectivityManager.requestDataFromiPhone()
        } label: {
          if connectivityManager.isSyncing {
            HStack(spacing: 6) {
              ProgressView()
                .scaleEffect(0.8)
              Text("同期中...")
            }
            .font(.subheadline)
            .fontWeight(.medium)
          } else {
            Label("今すぐ同期", systemImage: "arrow.triangle.2.circlepath")
              .font(.subheadline)
              .fontWeight(.medium)
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!connectivityManager.isReachable || connectivityManager.isSyncing)

        Spacer()
      }
      .padding()
    }
  }

  // MARK: - データ処理

  /// デバイスごとにグループ化されたレコード
  private var groupedDevices: [DeviceGroup] {
    let grouped = Dictionary(grouping: connectivityManager.records) { $0.deviceName }
    return grouped.map { name, records in
      let sortedRecords = records.sorted { $0.logDate > $1.logDate }
      let latestRecord = sortedRecords.first!
      return DeviceGroup(
        name: name,
        latestHealth: latestRecord.healthPercentage,
        latestCycleCount: latestRecord.cycleCount,
        records: sortedRecords
      )
    }.sorted { $0.name < $1.name }
  }
}

// MARK: - デバイスグループ

struct DeviceGroup {
  let name: String
  let latestHealth: Int
  let latestCycleCount: Int
  let records: [WatchBatteryRecord]
}

// MARK: - デバイスカード

struct DeviceCard: View {
  let device: DeviceGroup

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      // デバイス名
      Text(device.name)
        .font(.headline)
        .fontWeight(.semibold)
        .lineLimit(1)

      // メトリクス
      HStack(spacing: 12) {
        // ヘルス
        HStack(spacing: 4) {
          Image(systemName: "bolt.heart.fill")
            .font(.caption)
            .foregroundStyle(healthColor(device.latestHealth))

          Text("\(device.latestHealth)%")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(healthColor(device.latestHealth))
        }

        Divider()
          .frame(height: 12)

        // サイクル数
        HStack(spacing: 4) {
          Image(systemName: "arrow.triangle.2.circlepath")
            .font(.caption)
            .foregroundStyle(.secondary)

          Text("\(device.latestCycleCount)回")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      // レコード数
      Text("\(device.records.count)件のログ")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 6)
  }

  /// ヘルスパーセンテージに応じた色
  private func healthColor(_ health: Int) -> Color {
    if health >= 85 {
      return .green
    } else if health >= 70 {
      return .orange
    } else {
      return .red
    }
  }
}

// MARK: - プレビュー

#Preview {
  ContentView()
    .environmentObject(WatchConnectivityManager.shared)
}
