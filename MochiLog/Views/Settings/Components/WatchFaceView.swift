import SwiftUI

// MARK: - Watch文字盤サンプル（watchOSらしいデザイン）
struct WatchFaceView: View {
  let isRegistered: Bool

  var body: some View {
    ZStack {
      // 背景グラデーション（奥行き）
      LinearGradient(
        colors: [
          Color.black,
          Color(red: 0.05, green: 0.05, blue: 0.05),
          Color.black,
        ],
        startPoint: .top,
        endPoint: .bottom
      )

      VStack(spacing: 0) {
        Spacer()
          .frame(height: 40)  // 上部余白（watchOSの鉄則）

        // 1. 時刻（メイン要素）
        Text("9:41")
          .font(.system(size: 56, weight: .medium, design: .rounded))  // .rounded!
          .foregroundStyle(
            isRegistered
              ? LinearGradient(
                colors: [Color.green, Color.green.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
              )
              : LinearGradient(
                colors: [Color.white, Color.white.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
              )
          )
          .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

        Spacer()
          .frame(height: 12)

        // 2. 日付（セカンダリ要素）
        Text("月曜日 1月20日")
          .font(.system(size: 13, weight: .medium, design: .rounded))  // .rounded!
          .foregroundStyle(
            isRegistered
              ? Color.green.opacity(0.7)
              : Color.white.opacity(0.65)
          )
          .tracking(0.5)

        Spacer()

        // 3. コンプリケーション（1つのみ - バッテリー）
        VStack(spacing: 6) {
          HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 2)
              .fill(
                LinearGradient(
                  colors: [Color.green.opacity(0.9), Color.green],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .frame(width: 22, height: 11)
              .overlay(
                RoundedRectangle(cornerRadius: 2)
                  .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
              )

            // バッテリー端子
            RoundedRectangle(cornerRadius: 1)
              .fill(Color.white.opacity(0.5))
              .frame(width: 2, height: 5)
          }

          Text("85%")
            .font(.system(size: 11, weight: .semibold, design: .rounded))  // .rounded!
            .foregroundStyle(Color.white.opacity(0.6))
        }

        Spacer()
          .frame(height: 35)  // 下部余白（watchOSの鉄則）
      }
    }
  }
}
