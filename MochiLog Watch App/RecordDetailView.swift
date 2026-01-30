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
        // ヘルスリング（iOS側と同じスタイル）
        HealthRingView(
          percentage: Int(record.healthPercent)
        )
        .frame(height: 120)
        .padding(.top, 8)

        // メトリクス
        VStack(spacing: 12) {
          // サイクル数
          MetricRow(
            icon: "gauge",
            label: "サイクル数",
            value: "\(record.cycleCount) 回"
          )

          // 容量情報
          VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
              Image(systemName: "battery.100")
                .font(.caption)
                .foregroundStyle(.green)

              Text("最大容量")
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Text("\(record.currentCapacity) mAh")
              .font(.headline)
              .fontWeight(.semibold)

            Text("設計: \(record.designCapacity) mAh")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color(uiColor: .systemGray6))
          )

          // 診断結果
          if !record.diagnosticResult.isEmpty {
            HStack(spacing: 8) {
              Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(.green)

              VStack(alignment: .leading, spacing: 2) {
                Text("診断結果")
                  .font(.caption2)
                  .foregroundStyle(.secondary)

                Text(record.diagnosticResult)
                  .font(.subheadline)
                  .fontWeight(.medium)
              }

              Spacer()
            }
            .padding(10)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(Color(uiColor: .systemGray6))
            )
          }

          // ログ日時
          HStack {
            Text("ログ日時")
              .font(.caption)
              .foregroundStyle(.secondary)

            Spacer()

            Text(formatDate(record.logDate))
              .font(.caption)
              .foregroundStyle(.primary)
          }
          .padding(.vertical, 4)
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

// MARK: - ヘルスリング（iOS側と同じスタイル）

struct HealthRingView: View {
  let percentage: Int

  var body: some View {
    ZStack {
      // 背景リング
      Circle()
        .stroke(Color(uiColor: .systemGray5), lineWidth: 10)

      // プログレスリング（iOS側と同じグラデーション）
      Circle()
        .trim(from: 0, to: CGFloat(percentage) / 100)
        .stroke(
          AngularGradient(
            gradient: Gradient(colors: [.green, .green]),
            center: .center
          ),
          style: StrokeStyle(lineWidth: 10, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.easeInOut, value: percentage)

      // 中央テキスト
      VStack(spacing: 2) {
        Text("\(percentage)%")
          .font(.title2)
          .fontWeight(.bold)

        Text("バッテリーヘルス")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(8)
  }
}

// MARK: - メトリクス行

struct MetricRow: View {
  let icon: String
  let label: String
  let value: String

  var body: some View {
    HStack {
      Label(label, systemImage: icon)
        .font(.caption)
        .foregroundStyle(.secondary)

      Spacer()

      Text(value)
        .font(.headline)
        .fontWeight(.semibold)
    }
    .padding(.vertical, 4)
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
        nominalHealthPercent: 95,
        healthPercent: 95,
        diagnosticResult: "正常"
      )
    )
  }
}
