import AVFoundation
import AVKit
import Combine
import SwiftUI

// MARK: - PIP動画プレーヤービュー
/// チュートリアルガイド（PIP対応）を表示するビュー
struct PIPVideoPlayerView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        // コンテンツプレビュー
        PIPTutorialContentView()
          .frame(maxWidth: .infinity)
          .frame(height: 200)  // 比率的にこれくらい
          .cornerRadius(16)
          .shadow(radius: 5)
          .padding(.horizontal)

        // 説明テキスト
        VStack(spacing: 12) {
          Text(String(localized: "pip_instruction"))
            .font(.headline)
            .multilineTextAlignment(.center)

          Text(String(localized: "pip_instruction_detail"))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal)

        Spacer()

        // アクションボタン
        VStack(spacing: 16) {
          // 設定を開くボタン
          Button(action: openSettings) {
            HStack {
              Image(systemName: "gear")
              Text(String(localized: "open_analytics_settings"))
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(14)
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
      }
      .navigationTitle(String(localized: "video_tutorial"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "close")) {
            dismiss()
          }
        }
      }
    }
  }

  /// 設定アプリの解析データ画面を開く
  private func openSettings() {
    let settingsURLString = "prefs:root=Privacy&path=PROBLEM_REPORTING/DIAGNOSTIC_USAGE_DATA"

    if let url = URL(string: settingsURLString) {
      UIApplication.shared.open(url) { success in
        if !success {
          if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
          }
        }
      }
    }
  }
}

// MARK: - 拡張版PIPビュー（削除しても良いが互換性のために残す）
struct PIPVideoPlayerFullView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    PIPVideoPlayerView()
  }
}

#Preview {
  PIPVideoPlayerView()
}

// MARK: - PIPチュートリアルコンテンツビュー
/// PIPウィンドウ内に表示するSwiftUIビュー
struct PIPTutorialContentView: View {
  @State private var currentPage = 0
  private let totalPages = 5
  private let timer = Timer.publish(every: 6.0, on: .main, in: .common).autoconnect()

  var body: some View {
    ZStack {
      Color.black.edgesIgnoringSafeArea(.all)

      TabView(selection: $currentPage) {
        // ステップ1: 設定 > プライバシーとセキュリティ
        VStack(spacing: 8) {
          Image(systemName: "hand.raised.fill")
            .font(.system(size: 40))
            .foregroundStyle(.white)
          Text("プライバシーとセキュリティ")
            .font(.headline)
            .foregroundStyle(.white)
          Text("設定アプリから選択")
            .font(.caption)
            .foregroundStyle(.gray)
        }
        .tag(0)

        // ステップ2: 解析と改善 > 共有ON
        VStack(spacing: 8) {
          Image(systemName: "chart.bar.xaxis")
            .font(.system(size: 40))
            .foregroundStyle(.white)
          Text("解析と改善")
            .font(.headline)
            .foregroundStyle(.white)
          Text("iPhone/iPad解析を共有: ON")
            .font(.subheadline)
            .bold()
            .foregroundStyle(.green)
        }
        .tag(1)

        // ステップ3: 解析データ
        VStack(spacing: 8) {
          Image(systemName: "doc.text.magnifyingglass")
            .font(.system(size: 40))
            .foregroundStyle(.white)
          Text("解析データ")
            .font(.headline)
            .foregroundStyle(.white)
          Text("Analytics-202x...を選択")
            .font(.subheadline)
            .foregroundStyle(.yellow)
        }
        .tag(2)

        // ステップ4: 共有ボタン
        VStack(spacing: 8) {
          Image(systemName: "square.and.arrow.up")
            .font(.system(size: 40))
            .foregroundStyle(.white)
          Text("右上の共有ボタン")
            .font(.headline)
            .foregroundStyle(.white)
        }
        .tag(3)

        // ステップ5: MochiLogを選択
        VStack(spacing: 8) {
          if let icon = Bundle.main.icon {
            Image(uiImage: icon)
              .resizable()
              .scaledToFit()
              .frame(width: 60, height: 60)
              .cornerRadius(12)
          } else {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 40))
              .foregroundStyle(.white)
          }
          Text("MochiLogを選択")
            .font(.headline)
            .foregroundStyle(.white)
          Text("リストにない場合は「その他」から")
            .font(.caption)
            .foregroundStyle(.gray)
        }
        .tag(4)
      }
      .tabViewStyle(.page(indexDisplayMode: .always))
    }
    .onReceive(timer) { _ in
      withAnimation {
        currentPage = (currentPage + 1) % totalPages
      }
    }
  }
}

// MARK: - Bundle Extension
extension Bundle {
  var icon: UIImage? {
    if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
      let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
      let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
      let lastIcon = iconFiles.last
    {
      return UIImage(named: lastIcon)
    }
    return nil
  }
}

// MARK: - 無音オーディオプレーヤー
/// バックグラウンド動作を維持するための無音再生プレーヤー
class SilentAudioPlayer {
  private var audioEngine: AVAudioEngine?
  private var playerNode: AVAudioPlayerNode?

  func play() {
    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()

    engine.attach(player)

    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)

    // メインミキサーに接続（音量は0ではなく極小にするか、コンテンツ自体を無音にする）
    // iOSは音量0だとバックグラウンド再生とみなさない場合があるため注意
    // しかしAVAudioEngineで再生していれば基本大丈夫
    engine.connect(player, to: engine.mainMixerNode, format: format)

    do {
      try engine.start()
      player.play()

      self.audioEngine = engine
      self.playerNode = player
    } catch {
      print("無音再生エラー: \(error)")
    }
  }

  func stop() {
    playerNode?.stop()
    audioEngine?.stop()
    playerNode = nil
    audioEngine = nil
  }
}

// MARK: - PIPチュートリアルコントローラー
/// 設定を開くときにPIPを自動起動するコントローラー
class PIPTutorialController: NSObject, AVPictureInPictureControllerDelegate {
  private var silentPlayer: SilentAudioPlayer?
  private var pipController: AVPictureInPictureController?
  private var containerWindow: UIWindow?
  private var containerView: UIView?
  private var pipVideoCallViewController: Any?  // AVPictureInPictureVideoCallViewController
  private var pipContentViewController: UIViewController?  // UIHostingController

  /// PIPを開始して設定を開く
  /// - Parameter sourceFrame: アニメーション開始位置となるフレーム（nilの場合は画面右端中央）
  func startPIPAndOpenSettings(sourceFrame: CGRect? = nil) {
    // 動画ファイルチェックは不要になったので削除

    // オーディオセッション設定
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("オーディオセッション設定エラー: \(error)")
    }

    // 無音再生開始（バックグラウンド維持のため）
    silentPlayer = SilentAudioPlayer()
    silentPlayer?.play()

    // 現在のウィンドウシーンを取得
    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
      let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow })
    else {
      openSettings()
      return
    }

    // コンテナViewを作成（PIPアニメーションの起点）
    let frame: CGRect
    if let sourceFrame = sourceFrame {
      frame = sourceFrame
    } else {
      let screenBounds = keyWindow.bounds
      frame = CGRect(x: screenBounds.width - 1, y: screenBounds.height / 2, width: 1, height: 1)
    }

    containerView = UIView(frame: frame)
    containerView?.alpha = 0.01  // 不可視にする
    containerView?.backgroundColor = .clear

    if let containerView = containerView {
      // 最背面に配置
      keyWindow.insertSubview(containerView, at: 0)
    }

    // PIPコントローラー作成
    guard AVPictureInPictureController.isPictureInPictureSupported(),
      let containerView = containerView
    else {
      self.cleanupAndOpenSettings()
      return
    }

    if #available(iOS 15.0, *) {
      // iOS 15以上: AVPictureInPictureVideoCallViewControllerを使用
      let pipVideoCallVC = AVPictureInPictureVideoCallViewController()
      pipVideoCallVC.preferredContentSize = CGSize(width: 320, height: 180)
      self.pipVideoCallViewController = pipVideoCallVC

      // PIP内に表示するSwiftUI Viewを作成
      let contentView = PIPTutorialContentView()
      let hostingController = UIHostingController(rootView: contentView)
      hostingController.view.backgroundColor = .black
      self.pipContentViewController = hostingController

      // HostingControllerをVideoCallVCに追加
      // 注: AVPictureInPictureVideoCallViewControllerはUIViewControllerなのでaddChild可能
      // ただし view に追加するのが重要
      hostingController.view.translatesAutoresizingMaskIntoConstraints = false
      pipVideoCallVC.view.addSubview(hostingController.view)

      NSLayoutConstraint.activate([
        hostingController.view.topAnchor.constraint(equalTo: pipVideoCallVC.view.topAnchor),
        hostingController.view.bottomAnchor.constraint(equalTo: pipVideoCallVC.view.bottomAnchor),
        hostingController.view.leadingAnchor.constraint(equalTo: pipVideoCallVC.view.leadingAnchor),
        hostingController.view.trailingAnchor.constraint(
          equalTo: pipVideoCallVC.view.trailingAnchor),
      ])

      // ContentSourceを作成
      let contentSource = AVPictureInPictureController.ContentSource(
        activeVideoCallSourceView: containerView,  // ここがアニメーション起点
        contentViewController: pipVideoCallVC
      )

      pipController = AVPictureInPictureController(contentSource: contentSource)
    } else {
      // iOS 14以下: サポート対象外（動画なしPIPはiOS 15以降）
      self.cleanupAndOpenSettings()
      return
    }

    pipController?.delegate = self

    // 少し待ってからPIPを開始
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      guard let self = self else { return }

      if self.pipController?.isPictureInPicturePossible == true {
        self.pipController?.startPictureInPicture()

        // 設定を開く
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          self.openSettings()
        }
      } else {
        self.cleanupAndOpenSettings()
      }
    }
  }

  /// クリーンアップして設定を開く
  private func cleanupAndOpenSettings() {
    silentPlayer?.stop()
    openSettings()
  }

  /// 設定を開く
  private func openSettings() {
    let settingsURLString = "prefs:root=Privacy&path=PROBLEM_REPORTING/DIAGNOSTIC_USAGE_DATA"

    if let url = URL(string: settingsURLString) {
      UIApplication.shared.open(url) { success in
        if !success {
          if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
          }
        }
      }
    }
  }

  /// チュートリアル動画のURLを探す（互換性のために残すが使用しない）
  static func findTutorialVideoURL() -> URL? {
    // 常にnilを返すことで、UI側の条件分岐でもし動画が必要なら修正が必要だが、
    // 今回はController側で動画不要にしたので、呼び出し元も修正する必要がある。
    // ただし、TutorialView側でこのメソッドを使ってボタン表示制御をしているので、
    // trueを返すように偽装するか、TutorialViewを修正するか。
    // ユーザー要望的に「動画ファイル不要」なので、このメソッドは「動画機能有効」を意味するtrueを返したいがURLはnil。
    // なのでシグネチャを変えるか、ダミーURLを返すか。
    // ここではダミーURLを返して、呼び出し元の「nilじゃなければボタン出す」ロジックを通す。
    return URL(string: "file:///dummy.mp4")
  }

  /// PIPを停止
  func stopPIP() {
    pipController?.stopPictureInPicture()
    silentPlayer?.stop()
    containerView?.removeFromSuperview()
    containerView = nil
    pipController = nil
    pipContentViewController = nil
    pipVideoCallViewController = nil
  }

  // MARK: - AVPictureInPictureControllerDelegate

  func pictureInPictureControllerWillStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    print("PIP開始")
  }

  func pictureInPictureControllerDidStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    print("PIP終了")
    stopPIP()
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    print("PIP開始エラー: \(error)")
    cleanupAndOpenSettings()
  }
}
