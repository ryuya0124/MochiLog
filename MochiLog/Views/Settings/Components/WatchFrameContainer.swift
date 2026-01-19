import SwiftUI

// MARK: - Watch本体コンテナ
struct WatchFrameContainer<Content: View>: View {
  let model: WatchModel
  let isRegistered: Bool
  @ViewBuilder let content: () -> Content

  var body: some View {
    GeometryReader { geometry in
      let baseHeight: CGFloat = 250
      let scale = baseHeight / model.deviceSize.height

      ZStack {
        // 側面の影（立体感の基礎）
        RoundedRectangle(cornerRadius: model.cornerRadius)
          .fill(Color.black)
          .frame(
            width: model.deviceSize.width + 2,
            height: model.deviceSize.height + 2
          )
          .blur(radius: 3)
          .offset(x: 1, y: 2)

        // Watch本体ベゼル（複数のグラデーションレイヤー）
        ZStack {
          // 基本レイヤー
          RoundedRectangle(cornerRadius: model.cornerRadius)
            .fill(
              LinearGradient(
                colors: isRegistered
                  ? [
                    Color(red: 0.22, green: 0.22, blue: 0.24),
                    Color(red: 0.18, green: 0.18, blue: 0.20),
                    Color(red: 0.14, green: 0.14, blue: 0.16),
                    Color(red: 0.12, green: 0.12, blue: 0.14),
                  ]
                  : [
                    Color(red: 0.30, green: 0.30, blue: 0.30),
                    Color(red: 0.26, green: 0.26, blue: 0.26),
                    Color(red: 0.22, green: 0.22, blue: 0.22),
                    Color(red: 0.20, green: 0.20, blue: 0.20),
                  ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(
              width: model.deviceSize.width,
              height: model.deviceSize.height
            )

          // 側面のハイライト（立体感を強調）
          RoundedRectangle(cornerRadius: model.cornerRadius)
            .strokeBorder(
              LinearGradient(
                colors: [
                  Color.white.opacity(0.25),
                  Color.white.opacity(0.10),
                  Color.clear,
                  Color.clear,
                  Color.black.opacity(0.4),
                ],
                startPoint: UnitPoint(x: 0.2, y: 0.2),
                endPoint: UnitPoint(x: 0.8, y: 0.8)
              ),
              lineWidth: 1.5
            )
            .frame(
              width: model.deviceSize.width,
              height: model.deviceSize.height
            )
        }
        .shadow(color: .black.opacity(0.6), radius: 8, x: 0, y: 4)  // 近い影
        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)  // 遠い影

        // 画面エリア（コンテンツ）
        RoundedRectangle(cornerRadius: model.cornerRadius - 4)
          .fill(Color.black)
          .frame(
            width: model.screenSize.width,
            height: model.screenSize.height
          )
          .overlay(
            content()
              .frame(
                width: model.screenSize.width,
                height: model.screenSize.height
              )
              .clipShape(RoundedRectangle(cornerRadius: model.cornerRadius - 4))
          )
          .overlay(
            // ガラスの反射効果（より強調）
            RoundedRectangle(cornerRadius: model.cornerRadius - 4)
              .fill(
                LinearGradient(
                  colors: [
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.05),
                    Color.clear,
                    Color.clear,
                    Color.white.opacity(0.03),
                  ],
                  startPoint: UnitPoint(x: 0.2, y: 0.2),
                  endPoint: UnitPoint(x: 0.8, y: 0.8)
                )
              )
          )
          .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)

        // Digital Crown（右上）
        digitalCrown
          .offset(
            x: model.deviceSize.width / 2 + 3,
            y: -model.deviceSize.height * 0.25
          )

        // サイドボタン（右下）
        sideButton
          .offset(
            x: model.deviceSize.width / 2 + 2,
            y: model.deviceSize.height * 0.05
          )
      }
      .scaleEffect(scale)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    .frame(height: 250)
  }

  // MARK: - Digital Crown
  private var digitalCrown: some View {
    Capsule()
      .fill(
        LinearGradient(
          colors: [
            Color(red: 0.26, green: 0.26, blue: 0.26),
            Color(red: 0.18, green: 0.18, blue: 0.18),
          ],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(width: 6, height: 32)
      .overlay(
        // 溝のディテール
        VStack(spacing: 2) {
          ForEach(0..<8) { _ in
            Rectangle()
              .fill(Color.black.opacity(0.3))
              .frame(width: 6, height: 1)
          }
        }
      )
      .overlay(
        // 赤いドット（Cellularモデル）
        Circle()
          .fill(isRegistered ? Color.red : Color.clear)
          .frame(width: 3, height: 3)
          .offset(y: -16)
      )
  }

  // MARK: - サイドボタン
  private var sideButton: some View {
    Capsule()
      .fill(
        LinearGradient(
          colors: [
            Color(red: 0.24, green: 0.24, blue: 0.24),
            Color(red: 0.16, green: 0.16, blue: 0.16),
          ],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(width: 4, height: 18)
  }
}
