import Charts
import Foundation
// RecordViews.swift
// 一覧行ビューと詳細ビュー
import SwiftUI

// MARK: - ⓘボタン付きLabeledContentラッパー
/// ラベルの横にⓘボタンを表示し、タップでポップオーバーを表示するコンポーネント
/// iPad / iPhone どちらも吹き出しスタイルで表示（UIKitブリッジ使用）
struct InfoLabeledContent<V: View>: View {
  let label: String
  let hint: String
  let valueContent: V

  @State private var isShowingInfo = false

  init(_ label: String, hint: String, @ViewBuilder value: () -> V) {
    self.label = label
    self.hint = hint
    self.valueContent = value()
  }

  var body: some View {
    LabeledContent {
      valueContent
    } label: {
      HStack(spacing: 4) {
        Text(label)
        Button {
          isShowingInfo = true
        } label: {
          // 当たり判定を広げるためフレームで透明タップ領域を確保
          Image(systemName: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .background {
          // UIKitポップオーバーのアンカービューを背面に配置してタップを妨げないようにする
          InfoPopoverAnchor(isPresented: $isShowingInfo, title: label, hint: hint)
            .allowsHitTesting(false)
        }
      }
    }
  }
}

/// Stringバリューを直接渡せるオーバーロード
extension InfoLabeledContent where V == Text {
  init(_ label: String, hint: String, value: String) {
    self.init(label, hint: hint) { Text(value) }
  }
}

// MARK: - UIKitブリッジポップオーバーアンカー
/// UIPopoverPresentationControllerを使ってiPhone/iPad両方で吹き出しポップオーバーを表示する
private struct InfoPopoverAnchor: UIViewRepresentable {
  @Binding var isPresented: Bool
  let title: String
  let hint: String

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    if isPresented && !context.coordinator.isShowing {
      showPopover(from: uiView, context: context)
    } else if !isPresented && context.coordinator.isShowing {
      context.coordinator.dismissPopover()
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(isPresented: $isPresented)
  }

  private func showPopover(from uiView: UIView, context: Context) {
    guard let windowScene = uiView.window?.windowScene,
      let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
    else { return }

    // 最前面のViewControllerを取得
    var topVC = root
    while let presented = topVC.presentedViewController {
      topVC = presented
    }

    // ポップオーバーコンテンツのビュー
    let contentView = InfoPopoverContent(title: title, hint: hint)
    let hostingVC = UIHostingController(rootView: contentView)
    hostingVC.modalPresentationStyle = .popover

    // 幅300でレイアウトしたときの自然な高さを計算してサイズを決定
    hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
    let fittingSize = hostingVC.view.systemLayoutSizeFitting(
      CGSize(width: 300, height: UIView.layoutFittingCompressedSize.height),
      withHorizontalFittingPriority: .required,
      verticalFittingPriority: .fittingSizeLevel
    )
    // 画面の半分を超えないようキャップする
    let maxHeight = UIScreen.main.bounds.height * 0.5
    hostingVC.preferredContentSize = CGSize(width: 300, height: min(fittingSize.height, maxHeight))

    if let pop = hostingVC.popoverPresentationController {
      pop.sourceView = uiView
      pop.sourceRect = uiView.bounds
      pop.permittedArrowDirections = [.up, .down, .left, .right]
      pop.delegate = context.coordinator
    }

    context.coordinator.isShowing = true
    context.coordinator.presentedVC = hostingVC
    topVC.present(hostingVC, animated: true)
  }

  // MARK: - Coordinator
  class Coordinator: NSObject, UIPopoverPresentationControllerDelegate {
    @Binding var isPresented: Bool
    var isShowing = false
    weak var presentedVC: UIViewController?

    init(isPresented: Binding<Bool>) {
      self._isPresented = isPresented
    }

    /// iPhoneでもシートに変換せずポップオーバーのまま表示する
    func adaptivePresentationStyle(
      for controller: UIPresentationController,
      traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
      return .none
    }

    /// ドラッグやタップ外で閉じたとき状態を同期
    func popoverPresentationControllerDidDismissPopover(
      _ popoverPresentationController: UIPopoverPresentationController
    ) {
      isPresented = false
      isShowing = false
    }

    func dismissPopover() {
      presentedVC?.dismiss(animated: true) { [weak self] in
        self?.isShowing = false
      }
    }
  }
}

// MARK: - ポップオーバー内コンテンツ
/// ポップオーバー吹き出し内に表示するビュー（UIKitのUIHostingControllerで表示）
private struct InfoPopoverContent: View {
  let title: String
  let hint: String

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // ── ヘッダー ──
      HStack(alignment: .center, spacing: 8) {
        Image(systemName: "info.circle.fill")
          .font(.callout)
          .foregroundStyle(.tint)
        Text(title)
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundStyle(.primary)
      }
      .padding(.horizontal, 16)
      .padding(.top, 16)
      .padding(.bottom, 10)

      Divider()

      // ── 説明文 ──
      Text(hint)
        .font(.callout)
        .foregroundStyle(.primary)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
    }
    .frame(width: 300)
  }
}

struct RecordRowView: View {
  let record: BatteryRecord
  @StateObject private var appSettings = AppSettings.shared

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(record.deviceName)
          .font(.headline)
          .foregroundColor(.primary)
        Text(record.logDate, style: .date)
          .font(.caption)
          .foregroundColor(.secondary)
        Text(
          String(
            format: String(localized: "cycle_count_format", table: "Analytics"), record.cycleCount)
        )
        .font(.caption)
        .foregroundColor(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: 4) {
        let health =
          appSettings.analysisDataSource == .nominal
          ? record.nominalHealthPercent : record.healthPercent
        Text("\(String(format: "%.1f", health))%")
          .font(.title2)
          .bold()
          .foregroundStyle(healthColor(health))
        // 動的に計算した診断結果を表示（分析基準に応じて切り替え）
        Text(record.cachedDiagnostic)
          .font(.caption2)
          .foregroundColor(.primary)
      }
    }
    .padding(.vertical, 4)
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }
}
// MARK: - Previews ✅
#if DEBUG
  struct RecordViews_Previews: PreviewProvider {
    static var previews: some View {
      let sample = BatteryRecord(
        date: Date(), cycleCount: 420, maxCapacityPercent: 90, realCapacitymAh: 3200,
        designCapacitymAh: 3500, deviceName: "iPhone 15 Pro")

      Group {
        NavigationStack {
          RecordDetailView(record: sample)
        }
        .previewDevice(PreviewDevice(rawValue: "iPad Air (5th generation)"))
        .previewDisplayName("iPad - Regular")

        NavigationStack {
          RecordDetailView(record: sample)
        }
        .previewDevice(PreviewDevice(rawValue: "iPhone 14"))
        .previewDisplayName("iPhone - Compact")
      }
    }
  }
#endif
// Small card component for iPad detail layout
struct DetailCard<Content: View>: View {
  let title: String
  let systemImage: String?
  let content: Content

  init(title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
    self.title = title
    self.systemImage = systemImage
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        if let sys = systemImage {
          ZStack {
            Circle()
              .fill(
                LinearGradient(
                  gradient: Gradient(colors: [
                    AppSettings.shared.accentColor.color.opacity(0.16),
                    Color(uiColor: .systemBackground).opacity(0.06),
                  ]),
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .frame(width: 44, height: 44)
            Image(systemName: sys)
              .foregroundStyle(AppSettings.shared.accentColor.color)
              .font(.system(size: 18, weight: .semibold))
          }
          .frame(width: 44, height: 44)
        }
        Text(title).font(.headline)
        Spacer()
      }
      content
    }
    .padding()
    .frame(minHeight: 120, maxHeight: .infinity, alignment: .top)
    .background(
      Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18)
    )
    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(uiColor: .separator).opacity(0.08)))
  }
}

struct RecordDetailView: View {
  let record: BatteryRecord
  @StateObject private var appSettings = AppSettings.shared
  @Environment(\.dismiss) private var dismiss
  @Environment(\.displayScale) private var displayScale
  @Environment(\.colorScheme) private var colorScheme

  @EnvironmentObject private var dataStore: DataStore
  @State private var shareImage: Image?
  @State private var isShowingSharingSheet = false
  @State private var shareItems: [Any] = []
  @State private var isGeneratingImage = false
  @State private var cachedChartImage: UIImage?

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  private var isMagSafe: Bool {
    record.deviceName == "iPhone Air MagSafeバッテリー"
  }

  var body: some View {

    Group {
      // iPad / Regular width: bento-styleカードグリッド with polished header and summary panel
      if horizontalSizeClass == .regular {
        ScrollView {
          LazyVStack(spacing: 18) {
            // Header with large circular health ring and summary info
            HStack(alignment: .center, spacing: 20) {
              // 健康リング（動的コンテンツなのでCachedView削除）
              ZStack {
                Circle()
                  .stroke(Color(uiColor: .systemGray5), lineWidth: 10)
                  .frame(width: 120, height: 120)
                Circle()
                  .trim(
                    from: 0,
                    to: CGFloat(
                      min(
                        max(
                          appSettings.analysisDataSource == .nominal
                            ? record.nominalHealthPercent : record.healthPercent, 0), 100))
                      / 100.0
                  )
                  .stroke(
                    AppSettings.shared.accentColor.color,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                  )
                  .rotationEffect(.degrees(-90))
                  .frame(width: 120, height: 120)
                VStack {
                  let health =
                    appSettings.analysisDataSource == .nominal
                    ? record.nominalHealthPercent : record.healthPercent
                  Text("\(String(format: "%.0f", health))%")
                    .font(.title)
                    .bold()
                    .foregroundStyle(healthColorLocal(health))
                }
              }
              .padding(10)

              VStack(alignment: .leading, spacing: 6) {
                Text(record.deviceName).font(.title2).bold()
                if let code = record.deviceModelCode {
                  Text(code).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(record.logDate, style: .date).font(.subheadline).foregroundStyle(.secondary)

                HStack(spacing: 12) {
                  Label(
                    String(
                      format: String(localized: "cycle_count_format", table: "Analytics"),
                      record.cycleCount),
                    systemImage: "gauge"
                  )
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  Label("\(record.nominalCapacity) mAh", systemImage: "battery.25")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }

              Spacer()

              Button {
                Task {
                  isGeneratingImage = true
                  let image: UIImage?
                  if let cached = cachedChartImage {
                    image = cached
                  } else {
                    image = await generateChartImageAsync()
                  }
                  isGeneratingImage = false
                  shareContent(text: generateShareText(), image: image)
                }
              } label: {
                if isGeneratingImage {
                  ProgressView()
                } else {
                  Label(
                    String(localized: "share", table: "Common"),
                    systemImage: "square.and.arrow.up")
                }
              }
              .buttonStyle(.borderedProminent)
              .popover(isPresented: $isShowingSharingSheet) {
                if !shareItems.isEmpty {
                  ActivityViewController(
                    activityItems: shareItems,
                    thumbnailImage: cachedChartImage
                  )
                }
              }
            }
            .padding()

            .background(
              Color(uiColor: .secondarySystemGroupedBackground),
              in: RoundedRectangle(cornerRadius: 20))

            // Device info spans full width on iPad
            DetailCard(
              title: String(localized: "device_info", table: "Records"), systemImage: "iphone"
            ) {
              VStack(alignment: .leading, spacing: 8) {
                LabeledContent(
                  String(localized: "device_name", table: "Common"), value: record.deviceName)

                if !isMagSafe {
                  if let soc = record.soc {
                    InfoLabeledContent(
                      String(localized: "soc", table: "Records"),
                      hint: String(localized: "hint_soc", table: "Records"),
                      value: soc)
                  }
                }
                
                if let modelCode = record.deviceModelCode {
                  InfoLabeledContent(
                    String(localized: "model_code", table: "Records"),
                    hint: String(localized: "hint_model_code", table: "Records"),
                    value: modelCode)
                }
                
                if !isMagSafe {
                  if record.storage != nil, let formatted = record.formattedStorage {
                    InfoLabeledContent(
                      String(localized: "storage", table: "Records"),
                      hint: String(localized: "hint_storage", table: "Records"),
                      value: formatted)
                  }
                  if record.ram != nil, let formattedRam = record.formattedRAM {
                    InfoLabeledContent(
                      String(localized: "ram", table: "Records"),
                      hint: String(localized: "hint_ram", table: "Records"),
                      value: formattedRam)
                  }
                }
                
                LabeledContent(
                  String(localized: "log_date", table: "Records"), value: record.logDate,
                  format: .dateTime.year().month().day())
                if let firstUse = record.firstUseDate {
                  InfoLabeledContent(
                    String(localized: "first_use_date", table: "Records"),
                    hint: String(localized: "hint_first_use_date", table: "Records")
                  ) {
                    Text(firstUse, format: .dateTime.year().month().day())
                  }
                }
              }
              .padding(.vertical, 4)
            }

            // Battery capacity spans full width to avoid cut-off
            DetailCard(
              title: String(localized: "battery_capacity", table: "Analytics"),
              systemImage: "battery.100"
            ) {
              VStack(alignment: .leading, spacing: 8) {
                InfoLabeledContent(
                  String(localized: "cycle_count", table: "Analytics"),
                  hint: String(localized: "hint_cycle_count", table: "Records"),
                  value: String(
                    format: String(localized: "cycle_count_format", table: "Analytics"),
                    record.cycleCount))
                if record.designCapacity > 0 {
                  InfoLabeledContent(
                    String(localized: "design_capacity", table: "Analytics"),
                    hint: String(localized: "hint_design_capacity", table: "Records"),
                    value: "\(record.designCapacity) mAh (100%)")
                } else {
                  InfoLabeledContent(
                    String(localized: "design_capacity", table: "Analytics"),
                    hint: String(localized: "hint_design_capacity", table: "Records"),
                    value: String(localized: "unknown", table: "Common"))
                }
                InfoLabeledContent(
                  String(localized: "nominal_capacity", table: "Analytics"),
                  hint: String(localized: "hint_nominal_capacity", table: "Records")
                ) {
                  HStack(spacing: 8) {
                    Text("\(record.nominalCapacity) mAh")
                    let nominalPercent =
                      record.designCapacity > 0
                      ? (Double(record.nominalCapacity) / Double(record.designCapacity)) * 100.0
                      : record.realHealthPercent
                    Text("(\(String(format: "%.1f%%", nominalPercent)))")
                      .foregroundStyle(healthColorLocal(nominalPercent))
                  }
                }
                if !isMagSafe {
                  InfoLabeledContent(
                    String(localized: "raw_capacity", table: "Analytics"),
                    hint: String(localized: "hint_raw_capacity", table: "Records")
                  ) {
                    HStack(spacing: 8) {
                      Text("\(record.rawCapacity) mAh")
                      let health =
                        appSettings.analysisDataSource == .nominal
                        ? record.nominalHealthPercent : record.healthPercent
                      Text("(\(String(format: "%.1f%%", record.healthPercent)))")
                        .foregroundStyle(healthColorLocal(health))
                    }
                  }
                  if let lowRate = record.lowRateCapacity {
                    let lowRateRatio = record.designCapacity > 0 ? (Double(lowRate) / Double(record.designCapacity)) * 100.0 : 0.0
                    InfoLabeledContent(
                      String(localized: "low_rate_capacity", table: "Records"),
                      hint: String(localized: "hint_low_rate_capacity", table: "Records"),
                      value: "\(lowRate) mAh (\(String(format: "%.1f%%", lowRateRatio)))"
                    )
                  }
                  if let display = record.settingsDisplayPercent {
                    InfoLabeledContent(
                      String(localized: "os_display", table: "Records"),
                      hint: String(localized: "hint_os_display", table: "Records"),
                      value: "\(min(display, 100))%")
                  }
                }

                Divider().padding(.vertical, 6)

                if let deflator = record.deflator {
                  InfoLabeledContent(
                    String(localized: "deflator", table: "Records"),
                    hint: String(localized: "hint_deflator", table: "Records"),
                    value: String(format: "%.1f%%", deflator)
                  )
                }
                InfoLabeledContent(
                  String(localized: "diagnostic_result", table: "Records"),
                  hint: String(localized: "hint_diagnostic_result", table: "Records"),
                  value: record.cachedDiagnostic)
                if !isMagSafe {
                  if let displayDiagnostic = settingsDisplayDiagnosticMessage(
                    record.settingsDisplayPercent)
                  {
                    InfoLabeledContent(
                      String(localized: "settings_display_diagnostic", table: "Records"),
                      hint: String(localized: "hint_settings_display_diagnostic", table: "Records"),
                      value: displayDiagnostic
                    )
                  }
                }
                Text(String(localized: "not_official_note", table: "Records"))
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
              .padding(.vertical, 4)
            }

            // Remaining cards in grid
            LazyVGrid(
              columns: [GridItem(.adaptive(minimum: 280, maximum: 500), spacing: 20)],
              alignment: .leading,
              spacing: 20
            ) {
              // Temperature (optional)
              if record.avgTemp != nil || record.maxTemp != nil || record.minTemp != nil {
                DetailCard(
                  title: String(localized: "temperature_daily", table: "Records"),
                  systemImage: "thermometer"
                ) {
                  VStack(alignment: .leading, spacing: 8) {
                    if let avg = record.avgTemp {
                      InfoLabeledContent(
                        String(localized: "average", table: "Analytics"),
                        hint: String(localized: "hint_temperature", table: "Records"),
                        value: String(format: "%.1f°C", avg))
                    }
                    if let max = record.maxTemp {
                      InfoLabeledContent(
                        String(localized: "maximum", table: "Analytics"),
                        hint: String(localized: "hint_temperature", table: "Records"),
                        value: String(format: "%.1f°C", max))
                    }
                    if let min = record.minTemp {
                      InfoLabeledContent(
                        String(localized: "minimum", table: "Analytics"),
                        hint: String(localized: "hint_temperature", table: "Records"),
                        value: String(format: "%.1f°C", min))
                    }
                  }
                  .padding(.vertical, 4)
                }
              }

              // Voltage (optional)
              if record.maxVoltage != nil || record.minVoltage != nil {
                DetailCard(
                  title: String(localized: "voltage", table: "Records"), systemImage: "bolt.fill"
                ) {
                  VStack(alignment: .leading, spacing: 8) {
                    if let max = record.maxVoltage {
                      InfoLabeledContent(
                        String(localized: "maximum", table: "Analytics"),
                        hint: String(localized: "hint_voltage", table: "Records"),
                        value: String(format: "%.0f mV", max))
                    }
                    if let min = record.minVoltage {
                      InfoLabeledContent(
                        String(localized: "minimum", table: "Analytics"),
                        hint: String(localized: "hint_voltage", table: "Records"),
                        value: String(format: "%.0f mV", min))
                    }
                  }
                  .padding(.vertical, 4)
                }
              }

              // Charge range (optional)
              if record.maxSoC != nil || record.minSoC != nil {
                DetailCard(
                  title: String(localized: "charge_range_daily", table: "Records"),
                  systemImage: "battery.75"
                ) {
                  VStack(alignment: .leading, spacing: 8) {
                    if let max = record.maxSoC {
                      InfoLabeledContent(
                        String(localized: "max_soc", table: "Records"),
                        hint: String(localized: "hint_charge_range", table: "Records"),
                        value: "\(max)%")
                    }
                    if let min = record.minSoC {
                      InfoLabeledContent(
                        String(localized: "min_soc", table: "Records"),
                        hint: String(localized: "hint_charge_range", table: "Records"),
                        value: "\(min)%")
                    }
                  }
                  .padding(.vertical, 4)
                }
              }
            }
            .padding(.vertical, 18)
          }
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
      } else {
        // Compact width (iPhone): 既存の List ベース UI
        List {
          Section(String(localized: "device_info", table: "Records")) {
            LabeledContent(
              String(localized: "device_name", table: "Common"), value: record.deviceName)

            if !isMagSafe {
              if let soc = record.soc {
                InfoLabeledContent(
                  String(localized: "soc", table: "Records"),
                  hint: String(localized: "hint_soc", table: "Records"),
                  value: soc)
              }
            }
            
            if let modelCode = record.deviceModelCode {
              InfoLabeledContent(
                String(localized: "model_code", table: "Records"),
                hint: String(localized: "hint_model_code", table: "Records"),
                value: modelCode)
            }
            
            if !isMagSafe {
              if record.storage != nil, let formatted = record.formattedStorage {
                InfoLabeledContent(
                  String(localized: "storage", table: "Records"),
                  hint: String(localized: "hint_storage", table: "Records"),
                  value: formatted)
              }
              if record.ram != nil, let formattedRam = record.formattedRAM {
                InfoLabeledContent(
                  String(localized: "ram", table: "Records"),
                  hint: String(localized: "hint_ram", table: "Records"),
                  value: formattedRam)
              }
            }
            
            LabeledContent(
              String(localized: "log_date", table: "Records"), value: record.logDate,
              format: .dateTime.year().month().day())
            if let firstUse = record.firstUseDate {
              InfoLabeledContent(
                String(localized: "first_use_date", table: "Records"),
                hint: String(localized: "hint_first_use_date", table: "Records")
              ) {
                Text(firstUse, format: .dateTime.year().month().day())
              }
            }
          }

          Section(String(localized: "battery_capacity", table: "Analytics")) {
            InfoLabeledContent(
              String(localized: "cycle_count", table: "Analytics"),
              hint: String(localized: "hint_cycle_count", table: "Records"),
              value: String(
                format: String(localized: "cycle_count_format", table: "Analytics"),
                record.cycleCount))
            if record.designCapacity > 0 {
              InfoLabeledContent(
                String(localized: "design_capacity", table: "Analytics"),
                hint: String(localized: "hint_design_capacity", table: "Records"),
                value: "\(record.designCapacity) mAh (100%)")
            } else {
              InfoLabeledContent(
                String(localized: "design_capacity", table: "Analytics"),
                hint: String(localized: "hint_design_capacity", table: "Records"),
                value: String(localized: "unknown", table: "Common"))
            }
            InfoLabeledContent(
              String(localized: "nominal_capacity", table: "Analytics"),
              hint: String(localized: "hint_nominal_capacity", table: "Records")
            ) {
              HStack(spacing: 8) {
                Text("\(record.nominalCapacity) mAh")
                let nominalPercent =
                  record.designCapacity > 0
                  ? (Double(record.nominalCapacity) / Double(record.designCapacity)) * 100.0
                  : record.realHealthPercent
                Text("(\(String(format: "%.1f%%", nominalPercent)))")
                  .foregroundStyle(healthColorLocal(nominalPercent))
              }
            }
            if !isMagSafe {
              InfoLabeledContent(
                String(localized: "raw_capacity", table: "Analytics"),
                hint: String(localized: "hint_raw_capacity", table: "Records")
              ) {
                HStack(spacing: 8) {
                  Text("\(record.rawCapacity) mAh")
                  let health =
                    appSettings.analysisDataSource == .nominal
                    ? record.nominalHealthPercent : record.healthPercent
                  Text("(\(String(format: "%.1f%%", record.healthPercent)))")
                    .foregroundStyle(healthColorLocal(health))
                }
              }
              if let lowRate = record.lowRateCapacity {
                let lowRateRatio = record.designCapacity > 0 ? (Double(lowRate) / Double(record.designCapacity)) * 100.0 : 0.0
                InfoLabeledContent(
                  String(localized: "low_rate_capacity", table: "Records"),
                  hint: String(localized: "hint_low_rate_capacity", table: "Records"),
                  value: "\(lowRate) mAh (\(String(format: "%.1f%%", lowRateRatio)))"
                )
              }
              if let display = record.settingsDisplayPercent {
                InfoLabeledContent(
                  String(localized: "os_display", table: "Records"),
                  hint: String(localized: "hint_os_display", table: "Records"),
                  value: "\(min(display, 100))%")
              }
            }

            if let deflator = record.deflator {
              InfoLabeledContent(
                String(localized: "deflator", table: "Records"),
                hint: String(localized: "hint_deflator", table: "Records"),
                value: String(format: "%.1f%%", deflator))
            }
            InfoLabeledContent(
              String(localized: "diagnostic_result", table: "Records"),
              hint: String(localized: "hint_diagnostic_result", table: "Records"),
              value: record.dynamicDiagnosticResult)
            if !isMagSafe {
              if let displayDiagnostic = settingsDisplayDiagnosticMessage(
                record.settingsDisplayPercent)
              {
                InfoLabeledContent(
                  String(localized: "settings_display_diagnostic", table: "Records"),
                  hint: String(localized: "hint_settings_display_diagnostic", table: "Records"),
                  value: displayDiagnostic)
              }
            }
            Text(String(localized: "not_official_note", table: "Records"))
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          if record.avgTemp != nil || record.maxTemp != nil || record.minTemp != nil {
            Section(String(localized: "temperature_daily", table: "Records")) {
              if let avg = record.avgTemp {
                InfoLabeledContent(
                  String(localized: "average", table: "Analytics"),
                  hint: String(localized: "hint_temperature", table: "Records"),
                  value: String(format: "%.1f°C", avg))
              }
              if let max = record.maxTemp {
                InfoLabeledContent(
                  String(localized: "maximum", table: "Analytics"),
                  hint: String(localized: "hint_temperature", table: "Records"),
                  value: String(format: "%.1f°C", max))
              }
              if let min = record.minTemp {
                InfoLabeledContent(
                  String(localized: "minimum", table: "Analytics"),
                  hint: String(localized: "hint_temperature", table: "Records"),
                  value: String(format: "%.1f°C", min))
              }
            }
          }

          if record.maxVoltage != nil || record.minVoltage != nil {
            Section(String(localized: "voltage", table: "Records")) {
              if let max = record.maxVoltage {
                InfoLabeledContent(
                  String(localized: "maximum", table: "Analytics"),
                  hint: String(localized: "hint_voltage", table: "Records"),
                  value: String(format: "%.0f mV", max))
              }
              if let min = record.minVoltage {
                InfoLabeledContent(
                  String(localized: "minimum", table: "Analytics"),
                  hint: String(localized: "hint_voltage", table: "Records"),
                  value: String(format: "%.0f mV", min))
              }
            }
          }

          if record.maxSoC != nil || record.minSoC != nil {
            Section(String(localized: "charge_range_daily", table: "Records")) {
              if let max = record.maxSoC {
                InfoLabeledContent(
                  String(localized: "max_soc", table: "Records"),
                  hint: String(localized: "hint_charge_range", table: "Records"),
                  value: "\(max)%")
              }
              if let min = record.minSoC {
                InfoLabeledContent(
                  String(localized: "min_soc", table: "Records"),
                  hint: String(localized: "hint_charge_range", table: "Records"),
                  value: "\(min)%")
              }
            }
          }
        }
      }
    }
    .navigationTitle(String(localized: "detail", table: "Records"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if horizontalSizeClass != .regular {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(String(localized: "close", table: "Common")) {
            dismiss()
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            Task {
              isGeneratingImage = true
              let image: UIImage?
              if let cached = cachedChartImage {
                image = cached
              } else {
                image = await generateChartImageAsync()
              }
              isGeneratingImage = false
              shareContent(text: generateShareText(), image: image)
            }
          } label: {
            if isGeneratingImage {
              ProgressView()
            } else {
              Image(systemName: "square.and.arrow.up")
            }
          }
        }
      }
    }
    .sheet(
      isPresented: Binding(
        get: { horizontalSizeClass == .compact && isShowingSharingSheet },
        set: { if !$0 { isShowingSharingSheet = false } }
      )
    ) {
      if !shareItems.isEmpty {
        ActivityViewController(
          activityItems: shareItems,
          thumbnailImage: cachedChartImage
        )
      }
    }
    .onAppear {
      // 共有ボタンを押す前に画像を事前生成してキャッシュ
      Task.detached(priority: .userInitiated) {
        let image = await generateChartImageAsync()
        await MainActor.run {
          cachedChartImage = image
        }
      }
    }

  }

  // Generate share text for the record
  private func generateShareText() -> String {
    let health =
      appSettings.analysisDataSource == .nominal
      ? record.nominalHealthPercent : record.healthPercent
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.locale = Locale.current

    // タイトル
    var text = String(localized: "share_title", table: "Records")
    text += "\n\n"

    // デバイス名（モデルコードは表示しない）
    text += "\(record.deviceName)\n"

    // 記録日付
    text += "\(dateFormatter.string(from: record.logDate))\n\n"

    // バッテリー最大容量
    text +=
      "\(String(localized: "battery_health", table: "Records")): \(String(format: "%.1f", health))%\n"
    text += "\(record.cachedDiagnostic)\n\n"

    // 使用期間（初使用日がある場合）
    if let firstUse = record.firstUseDate {
      let calendar = Calendar.current
      let components = calendar.dateComponents([.day], from: firstUse, to: record.logDate)
      if let days = components.day {
        text += "\(String(localized: "share_usage_period", table: "Records")): "

        if days >= 365 {
          let years = days / 365
          let remainingDays = days % 365
          text += String(
            format: String(localized: "share_years_days", table: "Records"),
            years, remainingDays
          )
        } else {
          text += String(
            format: String(localized: "share_days", table: "Records"),
            days
          )
        }
        text += "\n"
      }
    }

    // サイクルカウント
    text += String(
      format:
        "\(String(localized: "cycle_count", table: "Analytics")): \(String(localized: "cycle_count_format", table: "Analytics"))",
      record.cycleCount
    )
    text += "\n"

    // 実測容量
    text +=
      "\(String(localized: "raw_capacity", table: "Analytics")): \(record.rawCapacity) mAh"
    text += "\n"

    // 公称容量
    text +=
      "\(String(localized: "nominal_capacity", table: "Analytics")): \(record.nominalCapacity) mAh"
    text += "\n"

    // 設計容量（ある場合）
    if record.designCapacity > 0 {
      text +=
        "\(String(localized: "design_capacity", table: "Analytics")): \(record.designCapacity) mAh"
      text += "\n"
    }

    // フッター（アプリ名とハッシュタグ）
    text += String(localized: "share_footer", table: "Records")

    return text
  }

  // グラフ画像を非同期生成（UIスレッドをブロックしない）
  @MainActor
  private func generateChartImageAsync() async -> UIImage? {
    let deviceName = record.deviceName
    let deviceRecords = dataStore.fetchRecords(for: deviceName)

    guard !deviceRecords.isEmpty else { return nil }

    let calendar = Calendar.current
    let now = Date()

    // 分析タブと同じレンジを使用（AppSettingsから取得）
    let range: RangePreset
    if let savedRangeString = appSettings.selectedChartRange,
      let savedRange = RangePreset(rawValue: savedRangeString)
    {
      range = savedRange
    } else {
      // 自動レンジ: データ期間に基づいて計算
      let pastRecords = deviceRecords.filter { $0.logDate <= now }
      guard let first = pastRecords.min(by: { $0.logDate < $1.logDate })?.logDate,
        let last = pastRecords.max(by: { $0.logDate < $1.logDate })?.logDate
      else { return nil }

      let days = calendar.dateComponents([.day], from: first, to: last).day ?? 0
      if days <= 7 {
        range = .oneWeek
      } else if days <= 14 {
        range = .twoWeeks
      } else if days <= 30 {
        range = .oneMonth
      } else if days <= 90 {
        range = .threeMonths
      } else if days <= 180 {
        range = .sixMonths
      } else if days <= 365 {
        range = .oneYear
      } else if days <= 730 {
        range = .twoYears
      } else {
        range = .threeYears
      }
    }

    // 最新のレコード日付を終了日として使用
    guard let windowEnd = deviceRecords.max(by: { $0.logDate < $1.logDate })?.logDate else {
      return nil
    }

    let startDate = ChartWindowNavigator.windowStart(
      for: windowEnd, range: range, allRecords: deviceRecords)
    let startDay = calendar.startOfDay(for: startDate)
    let endDay = calendar.startOfDay(for: windowEnd)

    let visibleRecords = deviceRecords.filter { record in
      let d = calendar.startOfDay(for: record.logDate)
      return d >= startDay && d <= endDay
    }

    let dataSource = appSettings.analysisDataSource
    let accentColor = appSettings.accentColor
    let scale = displayScale
    let scheme = colorScheme

    // バックグラウンドスレッドで重い処理を実行
    return await Task.detached(priority: .userInitiated) {
      await MainActor.run {
        // グラフチャート部分のみをレンダリング（ヘッダーやコントロールなし）
        let chartView = Chart {
          ForEach(visibleRecords, id: \.logDate) { record in
            let capacity =
              dataSource == .nominal
              ? record.nominalCapacity
              : record.rawCapacity

            LineMark(
              x: .value("Date", record.logDate),
              y: .value("Capacity", capacity)
            )
            .foregroundStyle(accentColor.color)
            .lineStyle(StrokeStyle(lineWidth: 3))
            .interpolationMethod(.catmullRom)

            PointMark(
              x: .value("Date", record.logDate),
              y: .value("Capacity", capacity)
            )
            .foregroundStyle(accentColor.color)
            .symbolSize(60)
          }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
          AxisMarks(position: .leading, values: .automatic) { value in
            AxisGridLine()
              .foregroundStyle(Color.gray.opacity(0.3))
            AxisValueLabel {
              if let intValue = value.as(Int.self) {
                Text("\(intValue)mAh")
                  .foregroundStyle(scheme == .dark ? .white : .black)
                  .font(.system(size: 14, weight: .medium))
              }
            }
          }
        }
        .chartXScale(domain: startDay...endDay)
        .chartXAxis {
          AxisMarks(values: .automatic) { value in
            AxisGridLine()
              .foregroundStyle(Color.gray.opacity(0.3))
            AxisValueLabel(format: .dateTime.month().day())
              .foregroundStyle(scheme == .dark ? .white : .black)
              .font(.system(size: 14, weight: .medium))
          }
        }
        .frame(width: 800, height: 480)
        .padding(24)
        .background(colorScheme == .dark ? Color.black : Color.white)
        .environment(\.colorScheme, colorScheme)

        return ViewRenderer.snapshot(view: chartView, scale: scale)
      }
    }.value
  }

  // 共有処理
  private func shareContent(text: String, image: UIImage?) {
    var items: [Any] = []
    if let image = image {
      items.append(image)
    }
    items.append(text)

    shareItems = items

    // 次のrunloopで共有シートを表示（ActivityViewControllerの初回初期化を待つ）
    DispatchQueue.main.async {
      self.isShowingSharingSheet = true
    }
  }

  // Local helper that uses accent color for 'good' state when available
  private func healthColorLocal(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }

  private func healthColor(_ percent: Double) -> Color {
    if percent < 80 { return .red }
    if percent < 90 { return .orange }
    return .green
  }

  private func settingsDisplayDiagnosticMessage(_ percent: Int?) -> String? {
    guard let p = percent else { return nil }
    if p >= 100 {
      // 100%以上：正常（良好）
      return String(
        format: String(localized: "settings_display_diagnostic_high", table: "Records"), p)
    }
    if p >= 90 {
      // 90%以上100%未満：やや劣化
      return String(
        format: String(localized: "settings_display_diagnostic_slight", table: "Records"), p)
    }
    if p >= 80 {
      // 80%以上90%未満：中間（劣化傾向）
      return String(
        format: String(localized: "settings_display_diagnostic_normal", table: "Records"), p)
    }
    // 80%未満：交換を検討
    return String(format: String(localized: "settings_display_diagnostic_low", table: "Records"), p)
  }
}
