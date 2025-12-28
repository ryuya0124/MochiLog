import SwiftUI

// MARK: - チュートリアルビュー
struct TutorialView: View {
  @Environment(\.dismiss) private var dismiss
  @StateObject private var appSettings = AppSettings.shared
  @State private var currentPage = 0
  @State private var showingVideoPlayer = false
  @State private var pipController: PIPTutorialController?

  private let pages: [TutorialPage] = [
    // ステップ1: ウェルカム
    TutorialPage(
      icon: "hand.wave.fill",
      iconColor: .green,
      titleKey: "tutorial_welcome",
      descriptionKey: "tutorial_welcome_description",
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
    // ステップ2: 解析を有効にする
    TutorialPage(
      icon: "chart.bar.xaxis",
      iconColor: .blue,
      titleKey: "tutorial_enable_analytics_title",
      descriptionKey: "tutorial_enable_analytics_description",
      imageName: nil,
      showSettingsButton: true,
      showVideoButton: true
    ),
    // ステップ3: ログファイルを探す
    TutorialPage(
      icon: "doc.text.magnifyingglass",
      iconColor: .orange,
      titleKey: "tutorial_find_log_title",
      descriptionKey: "tutorial_find_log_description",
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
    // ステップ4: MochiLogに共有
    TutorialPage(
      icon: "square.and.arrow.up",
      iconColor: .blue,
      titleKey: "tutorial_share_title",
      descriptionKey: "tutorial_share_description",
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
    // ステップ5: 完了
    TutorialPage(
      icon: "checkmark.circle.fill",
      iconColor: .green,
      titleKey: "tutorial_complete_title",
      descriptionKey: "tutorial_complete_description",
      imageName: nil,
      showSettingsButton: false,
      showVideoButton: false
    ),
  ]

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // ページインジケーター
        HStack(spacing: 8) {
          ForEach(0..<pages.count, id: \.self) { index in
            Circle()
              .fill(index == currentPage ? Color.green : Color.gray.opacity(0.3))
              .frame(width: 8, height: 8)
              .animation(.easeInOut, value: currentPage)
          }
        }
        .padding(.top, 20)

        // コンテンツ
        TabView(selection: $currentPage) {
          ForEach(0..<pages.count, id: \.self) { index in
            TutorialPageView(
              page: pages[index],
              onOpenSettings: { frame in openSettingsWithPIP(sourceFrame: frame) },
              onOpenVideo: { showingVideoPlayer = true }
            )
            .tag(index)
          }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))

        // ボタン
        VStack(spacing: 16) {
          if currentPage < pages.count - 1 {
            Button(action: {
              withAnimation {
                currentPage += 1
              }
            }) {
              Text(String(localized: "next"))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(14)
            }
          } else {
            Button(action: {
              appSettings.completeTutorial()
              dismiss()
            }) {
              Text(String(localized: "got_it"))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(14)
            }
          }

          if currentPage > 0 {
            Button(action: {
              withAnimation {
                currentPage -= 1
              }
            }) {
              Text(String(localized: "back"))
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
      }
      .navigationTitle(String(localized: "tutorial"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "close")) {
            dismiss()
          }
        }
      }
      .sheet(isPresented: $showingVideoPlayer) {
        PIPVideoPlayerFullView()
      }
    }
  }

  // MARK: - Private Methods

  /// 設定アプリの解析データ画面を開く（PIP動画を自動起動）
  private func openSettingsWithPIP(sourceFrame: CGRect? = nil) {
    // 動画がある場合はPIPで自動再生（mp4とmovに対応）
    if PIPTutorialController.findTutorialVideoURL() != nil {
      pipController = PIPTutorialController()
      pipController?.startPIPAndOpenSettings(sourceFrame: sourceFrame)
    } else {
      // 動画がない場合は設定のみ開く
      openAnalyticsSettings()
    }
  }

  /// 設定アプリの解析データ画面を開く
  private func openAnalyticsSettings() {
    let settingsURLString = "prefs:root=Privacy&path=PROBLEM_REPORTING/DIAGNOSTIC_USAGE_DATA"

    if let url = URL(string: settingsURLString) {
      UIApplication.shared.open(url) { success in
        if !success {
          // フォールバック: 通常の設定アプリを開く
          if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
          }
        }
      }
    }
  }
}

// MARK: - チュートリアルページデータ
struct TutorialPage {
  let icon: String
  let iconColor: Color
  let titleKey: String
  let descriptionKey: String
  let imageName: String?
  let showSettingsButton: Bool
  let showVideoButton: Bool
}

// MARK: - チュートリアルページビュー
struct TutorialPageView: View {
  let page: TutorialPage
  var onOpenSettings: ((CGRect?) -> Void)?
  var onOpenVideo: (() -> Void)?

  @State private var settingsButtonFrame: CGRect?

  var body: some View {
    VStack(spacing: 32) {
      Spacer()

      // アイコン
      ZStack {
        Circle()
          .fill(page.iconColor.opacity(0.15))
          .frame(width: 120, height: 120)

        Image(systemName: page.icon)
          .font(.system(size: 50))
          .foregroundStyle(page.iconColor)
      }

      // テキスト
      VStack(spacing: 16) {
        Text(String(localized: String.LocalizationValue(page.titleKey)))
          .font(.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)

        Text(String(localized: String.LocalizationValue(page.descriptionKey)))
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
      }

      // ボタンエリア
      VStack(spacing: 12) {
        // 動画チュートリアルボタン
        if page.showVideoButton {
          Button(action: { onOpenVideo?() }) {
            HStack {
              Image(systemName: "play.rectangle.fill")
              Text(String(localized: "watch_video_tutorial"))
            }
            .font(.subheadline)
            .foregroundColor(.blue)
          }
        }

        // 設定を開くボタン
        if page.showSettingsButton {
          Button(action: { onOpenSettings?(settingsButtonFrame) }) {
            HStack {
              Image(systemName: "gear")
              Text(String(localized: "open_analytics_settings"))
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(12)
          }
          .background(
            GeometryReader { proxy in
              Color.clear
                .onAppear {
                  settingsButtonFrame = proxy.frame(in: .global)
                }
                .onChange(of: proxy.frame(in: .global)) { newFrame in
                  settingsButtonFrame = newFrame
                }
            }
          )
          .padding(.top, 8)
        }
      }

      Spacer()
      Spacer()
    }
    .padding()
  }
}

#Preview {
  TutorialView()
}
