import SwiftUI

// MARK: - Apple Watchモックアップビュー
struct AppleWatchMockupView: View {
  let modelName: String?
  let isRegistered: Bool

  private var isUltra: Bool {
    modelName?.lowercased().contains("ultra") ?? false
  }

  var body: some View {
    ZStack {
      // Watch本体
      RoundedRectangle(cornerRadius: isUltra ? 18 : 28)
        .fill(
          LinearGradient(
            colors: isRegistered
              ? [
                Color(red: 0.2, green: 0.2, blue: 0.22), Color(red: 0.15, green: 0.15, blue: 0.17),
              ]
              : [
                Color(red: 0.3, green: 0.3, blue: 0.3), Color(red: 0.25, green: 0.25, blue: 0.25),
              ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 140, height: 170)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

      // ディスプレイ
      RoundedRectangle(cornerRadius: isUltra ? 14 : 24)
        .fill(Color.black)
        .frame(width: 130, height: 160)

      // 文字盤
      watchFace
    }
  }

  @ViewBuilder
  private var watchFace: some View {
    ZStack {
      // 時計の文字盤背景
      Circle()
        .fill(
          RadialGradient(
            colors: isRegistered
              ? [Color.green.opacity(0.3), Color.green.opacity(0.1), Color.black]
              : [Color.gray.opacity(0.2), Color.gray.opacity(0.1), Color.black],
            center: .center,
            startRadius: 20,
            endRadius: 70
          )
        )
        .frame(width: 110, height: 110)

      // 時刻表示（12:00）
      VStack(spacing: 2) {
        // 時針
        Rectangle()
          .fill(isRegistered ? Color.green : Color.white)
          .frame(width: 3, height: 25)
          .offset(y: -12.5)
          .rotationEffect(.degrees(0))

        // 分針
        Rectangle()
          .fill(isRegistered ? Color.green : Color.white)
          .frame(width: 2, height: 35)
          .offset(y: -17.5)
          .rotationEffect(.degrees(0))
      }

      // 中央のドット
      Circle()
        .fill(isRegistered ? Color.green : Color.white)
        .frame(width: 6, height: 6)
    }
    .frame(width: 110, height: 110)
  }
}
