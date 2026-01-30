//
//  RecordDetailView.swift
//  MochiLog Watch App
//
//  Created by りゅうや on 2026/01/30.
//

import SwiftUI

/// バッテリーレコードの詳細ビュー
struct RecordDetailView: View {
  let record: WatchBatteryRecord

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // ヘルスリング
        HealthRingView(percentage: record.healthPercentage)
          .frame(height: 120)
          .padding(.top, 8)

        // メトリクス
        VStack(spacing: 12) {
          // サイクル数
          MetricCard(
            icon: "arrow.triangle.2.circlepath",
            title: "サイクル数",
            value: "\(record.cycleCount)",
            color: .blue
          )

          // 容量情報
          MetricCard(
            icon: "battery.100.bolt",
            title: "最大容量",
            value: "\(record.currentCapacity) mAh",
            subtitle: "設計: \(record.designCapacity) mAh",
            color: .green
          )

          // 診断結果
          if !record.diagnosticResult.isEmpty {
            DiagnosticCard(result: record.diagnosticResult, health: record.healthPercentage)
          }

          // ログ日時
          InfoRow(label: "ログ日時", value: formatDate(record.logDate))
        }
      }
      .padding(.horizontal, 8)
      .padding(.bottom, 16)
    }
    .navigationTitle(record.deviceName)
    .navigationBarTitleDisplayMode(.inline)
  }

  /// 日付をフォーマット
  private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "M/d HH:mm"
    return formatter.string(from: date)
  }
}

// MARK: - ヘルスリング

struct HealthRingView: View {
  let percentage: Int

  var body: some View {
    ZStack {
      // 背景リング
      Circle()
        .stroke(Color.gray.opacity(0.2), lineWidth: 12)

      // プログレスリング
      Circle()
        .trim(from: 0, to: CGFloat(percentage) / 100)
        .stroke(
          healthGradient,
          style: StrokeStyle(lineWidth: 12, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.easeInOut, value: percentage)

      // 中央テキスト
      VStack(spacing: 2) {
        Text("\(percentage)%")
          .font(.title2)
          .fontWeight(.bold)
          .foregroundStyle(healthColor)

        Text("バッテリーヘルス")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(8)
  }

  /// ヘルスカラー
  private var healthColor: Color {
    if percentage >= 85 {
      return .green
    } else if percentage >= 70 {
      return .orange
    } else {
      return .red
    }
  }

  /// ヘルスグラデーション
  private var healthGradient: LinearGradient {
    if percentage >= 85 {
      return LinearGradient(
        colors: [.green, .green.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    } else if percentage >= 70 {
      return LinearGradient(
        colors: [.orange, .yellow],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    } else {
      return LinearGradient(
        colors: [.red, .orange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    }
  }
}

// MARK: - メトリクスカード

struct MetricCard: View {
  let icon: String
  let title: String
  let value: String
  var subtitle: String? = nil
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      // アイコン + タイトル
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.caption)
          .foregroundStyle(color)

        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      // 値
      Text(value)
        .font(.headline)
        .fontWeight(.semibold)

      // サブタイトル
      if let subtitle = subtitle {
        Text(subtitle)
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.gray.opacity(0.1))
    )
  }
}

// MARK: - 診断カード

struct DiagnosticCard: View {
  let result: String
  let health: Int

  var body: some View {
    HStack(spacing: 8) {
      // アイコン
      Image(systemName: statusIcon)
        .font(.title3)
        .foregroundStyle(statusColor)

      // テキスト
      VStack(alignment: .leading, spacing: 2) {
        Text("診断結果")
          .font(.caption2)
          .foregroundStyle(.secondary)

        Text(result)
          .font(.subheadline)
          .fontWeight(.medium)
      }

      Spacer()
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(statusColor.opacity(0.1))
    )
  }

  /// ステータスアイコン
  private var statusIcon: String {
    if health >= 85 {
      return "checkmark.circle.fill"
    } else if health >= 70 {
      return "exclamationmark.triangle.fill"
    } else {
      return "xmark.circle.fill"
    }
  }

  /// ステータスカラー
  private var statusColor: Color {
    if health >= 85 {
      return .green
    } else if health >= 70 {
      return .orange
    } else {
      return .red
    }
  }
}

// MARK: - 情報行

struct InfoRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)

      Spacer()

      Text(value)
        .font(.caption)
        .foregroundStyle(.primary)
    }
    .padding(.vertical, 4)
    .padding(.horizontal, 12)
  }
}

// MARK: - プレビュー

#Preview {
  NavigationStack {
    RecordDetailView(
      record: WatchBatteryRecord(
        id: UUID().uuidString,
        deviceName: "iPhone 15 Pro",
        logDate: Date(),
        cycleCount: 120,
        healthPercentage: 95,
        diagnosticResult: "正常",
        designCapacity: 3274,
        currentCapacity: 3110
      )
    )
  }
}
