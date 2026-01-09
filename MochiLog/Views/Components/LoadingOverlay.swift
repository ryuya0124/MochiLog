import SwiftUI

/// 処理中のローディングオーバーレイ
/// データ準備や計算中に表示する共通コンポーネント
struct LoadingOverlay: View {
  /// オーバーレイを表示するかどうか
  let isLoading: Bool

  /// 表示するメッセージ（省略時はデフォルトメッセージ）
  var message: String?

  var body: some View {
    if isLoading {
      ZStack {
        Color.black.opacity(0.3)
          .ignoresSafeArea()

        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.5)
            .tint(.white)
          Text(message ?? String(localized: "preparing_data", table: "Home"))
            .font(.headline)
            .foregroundColor(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
      }
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
  }
}

#Preview {
  ZStack {
    Color.gray.ignoresSafeArea()
    LoadingOverlay(isLoading: true)
  }
}
