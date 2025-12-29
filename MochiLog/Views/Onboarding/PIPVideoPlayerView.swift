import AVFoundation
import AVKit
import Combine
import SwiftUI

// MARK: - PIPソースビュー（UIViewRepresentable）
struct PIPSourceView: UIViewRepresentable {
  let onSourceViewAvailable: (UIView) -> Void

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    DispatchQueue.main.async {
      onSourceViewAvailable(uiView)
    }
  }
}

// MARK: - PIP動画プレーヤービュー
/// チュートリアルガイド（PIP対応）を表示するビュー
struct PIPVideoPlayerView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var pipController: PIPTutorialController?
  @State private var sourceView: UIView?

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        // コンテンツプレビュー
        PIPTutorialContentView()
          .frame(maxWidth: .infinity)
          .frame(height: 200)
          .cornerRadius(16)
          .shadow(radius: 5)
          .background(
            PIPSourceView { view in
              self.sourceView = view
            }
          )
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

        // 注意書き
        Text(String(localized: "pip_note"))
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)

        Spacer()

        // アクションボタン
        VStack(spacing: 16) {
          // 設定を開くボタン
          Button(action: startPIP) {
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

  /// PIPを開始して設定アプリの解析データ画面を開く
  private func startPIP() {
    print("[PIPVideoPlayerView] startPIP called. SourceView available: \(sourceView != nil)")
    pipController = PIPTutorialController()
    pipController?.startPIPAndOpenSettings(sourceView: sourceView)
  }

  // 古いopenSettingsは不要だが、PIPTutorialControllerクラス内で使われている可能性があるので
  // PIPTutorialControllerクラス内のopenSettings定義とは別物。
  // View内のこのopenSettingsは削除して良い。

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
  private let totalPages = 7
  private let timer = Timer.publish(every: 6.0, on: .main, in: .common).autoconnect()

  var body: some View {
    ZStack {
      // 背景色：ダークモードは真っ黒、ライトモードは白
      Color(
        uiColor: UIColor { traitCollection in
          traitCollection.userInterfaceStyle == .dark ? .black : .white
        }
      ).edgesIgnoringSafeArea(.all)

      TabView(selection: $currentPage) {
        // ステップ1: 設定アプリを開く
        VStack(spacing: 8) {
          Image(systemName: "gear")
            .font(.system(size: 40))
            .foregroundStyle(.primary)
          Text(String(localized: "pip_step_open_settings"))
            .font(.headline)
            .foregroundStyle(.primary)
          Text(String(localized: "pip_step_settings_app"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .tag(0)

        // ステップ2: 設定のトップに戻る
        VStack(spacing: 8) {
          Image(systemName: "chevron.left")
            .font(.system(size: 40))
            .foregroundStyle(.blue)
          Text(String(localized: "pip_step_go_to_settings_top"))
            .font(.headline)
            .foregroundStyle(.primary)
          Text(String(localized: "pip_step_tap_back_button"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .tag(1)

        // ステップ3: プライバシーとセキュリティ
        VStack(spacing: 8) {
          Image(systemName: "hand.raised.fill")
            .font(.system(size: 40))
            .foregroundStyle(.primary)
          Text(String(localized: "pip_step_privacy_security"))
            .font(.headline)
            .foregroundStyle(.primary)
          Text(String(localized: "pip_step_menu_select"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .tag(2)

        // ステップ4: 解析と改善
        VStack(spacing: 8) {
          Image(systemName: "chart.bar.xaxis")
            .font(.system(size: 40))
            .foregroundStyle(.primary)
          Text(String(localized: "pip_step_analytics_improvements"))
            .font(.headline)
            .foregroundStyle(.primary)
          Text(String(localized: "pip_step_menu_select"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .tag(3)

        // ステップ5: 共有ON
        VStack(spacing: 8) {
          Image(systemName: "switch.2")
            .font(.system(size: 40))
            .foregroundStyle(.green)
          Text(String(localized: "pip_step_share_on"))
            .font(.headline)
            .foregroundStyle(.primary)
          Text(String(localized: "pip_step_share_analytics"))
            .font(.caption)
            .foregroundStyle(.primary)
        }
        .tag(4)

        // ステップ6: 解析データ → ログファイル選択
        VStack(spacing: 8) {
          Image(systemName: "doc.text.magnifyingglass")
            .font(.system(size: 40))
            .foregroundStyle(.primary)
          Text(String(localized: "pip_step_analytics_data"))
            .font(.headline)
            .foregroundStyle(.primary)
          Text(String(localized: "pip_step_select_log"))
            .font(.subheadline)
            .foregroundStyle(.yellow)
        }
        .tag(5)

        // ステップ7: MochiLogに共有
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
              .foregroundStyle(.green)
          }
          Text(String(localized: "pip_step_select_mochilog"))
            .font(.headline)
            .foregroundStyle(.primary)
          Text(String(localized: "pip_step_if_not_listed"))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .tag(6)
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

// MARK: - 無音オーディオプレーヤー
/// バックグラウンド動作を維持するための無音再生プレーヤー（AVPlayer版）
class SilentAudioPlayer {
  private var player: AVPlayer?
  private var playerItem: AVPlayerItem?

  func play() {
    let fileName = "silent_audio.wav"
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

    // 無音ファイルが存在しない場合は作成
    if !FileManager.default.fileExists(atPath: fileURL.path) {
      createSilentWav(at: fileURL)
    }

    let item = AVPlayerItem(url: fileURL)
    playerItem = item
    player = AVPlayer(playerItem: item)

    // 外部出力（ミラーリング・AirPlay等）を無効化
    // これにより、画面録画中やHDMI接続中でもPIPが正常に動作しやすくなる
    player?.allowsExternalPlayback = false

    // 音量は確保するが無音ファイルなので音は出ない
    // ※ミュートにするとバックグラウンド再生が停止される可能性があるためミュートしない
    player?.isMuted = false

    // ループ再生の設定
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(playerItemDidReachEnd(notification:)),
      name: .AVPlayerItemDidPlayToEndTime,
      object: item
    )

    player?.play()
  }

  func stop() {
    player?.pause()
    if let item = playerItem {
      NotificationCenter.default.removeObserver(
        self, name: .AVPlayerItemDidPlayToEndTime, object: item)
    }
    player = nil
    playerItem = nil
  }

  @objc private func playerItemDidReachEnd(notification: Notification) {
    player?.seek(to: .zero)
    player?.play()
  }

  /// 1秒間の無音WAVファイルを生成する
  private func createSilentWav(at url: URL) {
    let sampleRate: Int32 = 44100
    let duration: Int32 = 1  // seconds
    let channels: Int16 = 1
    let bitsPerSample: Int16 = 16
    let byteRate = sampleRate * Int32(channels) * Int32(bitsPerSample) / 8
    let blockAlign = channels * bitsPerSample / 8
    let dataSize = sampleRate * duration * Int32(blockAlign)
    let chunkSize = 36 + dataSize

    var data = Data()

    // RIFF Chunk
    data.append("RIFF".data(using: .ascii)!)
    data.append(withUnsafeBytes(of: chunkSize) { Data($0) })
    data.append("WAVE".data(using: .ascii)!)

    // fmt Chunk
    data.append("fmt ".data(using: .ascii)!)
    let fmtChunkSize: Int32 = 16
    data.append(withUnsafeBytes(of: fmtChunkSize) { Data($0) })
    let audioFormat: Int16 = 1  // PCM
    data.append(withUnsafeBytes(of: audioFormat) { Data($0) })
    data.append(withUnsafeBytes(of: channels) { Data($0) })
    data.append(withUnsafeBytes(of: sampleRate) { Data($0) })
    data.append(withUnsafeBytes(of: byteRate) { Data($0) })
    data.append(withUnsafeBytes(of: blockAlign) { Data($0) })
    data.append(withUnsafeBytes(of: bitsPerSample) { Data($0) })

    // data Chunk
    data.append("data".data(using: .ascii)!)
    data.append(withUnsafeBytes(of: dataSize) { Data($0) })

    // Silence payload
    data.append(Data(count: Int(dataSize)))

    try? data.write(to: url)
  }
}

// MARK: - PIPチュートリアルコントローラー
/// 設定を開くときにPIPを自動起動するコントローラー
class PIPTutorialController: NSObject, AVPictureInPictureControllerDelegate {
  private var silentPlayer: SilentAudioPlayer?
  private var pipController: AVPictureInPictureController?
  private weak var sourceView: UIView?  // 外部から渡されたUIView
  private var pipVideoCallViewController: Any?  // AVPictureInPictureVideoCallViewController
  private var pipContentViewController: UIViewController?  // UIHostingController
  private var observation: NSKeyValueObservation?

  /// PIPを開始して設定を開く
  /// - Parameter sourceView: PIPアニメーションの起点となるUIView
  func startPIPAndOpenSettings(sourceView: UIView?) {
    self.sourceView = sourceView

    // オーディオセッション設定
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("[PIP] AudioSession setup error: \(error)")
    }

    // 無音再生開始（バックグラウンド維持のため）
    silentPlayer = SilentAudioPlayer()
    silentPlayer?.play()

    // PIPコントローラー作成準備
    guard AVPictureInPictureController.isPictureInPictureSupported() else {
      print("[PIP] PIP not supported")
      cleanupAndOpenSettings()
      return
    }

    // ソースビューのチェック
    guard let sourceView = sourceView, sourceView.window != nil else {
      print("[PIP] Source view nil or not in window. Fallback to settings.")
      // ここでダミーのWindowベースPIPに切り替えることも可能だが、
      // ユーザー要望の「正攻法」に従い純粋な実装とする。
      // ただし全く起動しないのは困るので、設定だけ開く。
      cleanupAndOpenSettings()
      return
    }

    if #available(iOS 15.0, *) {
      // iOS 15以上: AVPictureInPictureVideoCallViewControllerを使用
      let pipVideoCallVC = AVPictureInPictureVideoCallViewController()
      // 21:9 アスペクト比を設定
      pipVideoCallVC.preferredContentSize = CGSize(width: 320, height: 180)
      self.pipVideoCallViewController = pipVideoCallVC

      // PIP内に表示するSwiftUI Viewを作成
      let contentView = PIPTutorialContentView()
      let hostingController = UIHostingController(rootView: contentView)
      hostingController.view.backgroundColor = .black
      hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
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
        activeVideoCallSourceView: sourceView,  // 実際のViewを使用
        contentViewController: pipVideoCallVC
      )

      pipController = AVPictureInPictureController(contentSource: contentSource)
    } else {
      // iOS 14以下: サポート対象外
      print("[PIP] iOS version too low")
      cleanupAndOpenSettings()
      return
    }

    pipController?.delegate = self
    print(
      "[PIP] Controller created. Initial possible: \(pipController?.isPictureInPicturePossible ?? false)"
    )

    // タイムアウト設定（2秒経ってもPIP開始できなければ設定へ）
    let timeoutWork = DispatchWorkItem { [weak self] in
      guard let self = self else { return }
      if self.pipController?.isPictureInPictureActive == false {
        print("[PIP] Startup timeout. Opening settings anyway.")
        self.cleanupAndOpenSettings()
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: timeoutWork)

    // KVOで監視して、準備ができ次第開始
    observation = pipController?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) {
      [weak self] controller, change in
      guard let self = self else { return }
      print("[PIP] isPossible changed to: \(controller.isPictureInPicturePossible)")

      if controller.isPictureInPicturePossible {
        // 準備完了：監視を停止して開始
        self.observation?.invalidate()
        self.observation = nil

        // 念のため少しだけ遅延させてUIレンダリングを確定させる
        DispatchQueue.main.async {
          controller.startPictureInPicture()
          print("[PIP] startPictureInPicture called")

          // アプリに戻ってきたらPIPを終了する監視を追加
          NotificationCenter.default.addObserver(
            self, selector: #selector(self.handleAppForeground),
            name: UIApplication.willEnterForegroundNotification, object: nil)

          // 少し待ってから設定を開く（PIPアニメーション開始時間を確保）
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // ここで必ずしもタイムアウトをキャンセルする必要はないが、
            // PIPが開始していればcleanupは呼ばれないようにする制御はstopPIP側では難しいので
            // isPictureInPictureActive チェックでガードする
            timeoutWork.cancel()
            self.openSettings()
          }
        }
      }
    }
  }

  /// アプリがフォアグラウンドに戻った時の処理
  @objc private func handleAppForeground() {
    print("[PIP] App entered foreground. Stopping PIP.")
    if pipController?.isPictureInPictureActive == true {
      pipController?.stopPictureInPicture()
    } else {
      stopPIP()
    }
  }

  /// クリーンアップして設定を開く
  private func cleanupAndOpenSettings() {
    NotificationCenter.default.removeObserver(self)
    silentPlayer?.stop()
    openSettings()
  }

  /// 設定を開く
  private func openSettings() {
    SettingsRedirectHelper.redirectToPrivacyAnalytics()
  }

  /// PIPを停止
  func stopPIP() {
    NotificationCenter.default.removeObserver(self)
    pipController?.stopPictureInPicture()
    silentPlayer?.stop()
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
    print("[PIP] Failed to start PIP: \(error.localizedDescription) (Error: \(error))")
    cleanupAndOpenSettings()
  }
}
