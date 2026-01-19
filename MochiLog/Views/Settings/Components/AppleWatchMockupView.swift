import SwiftUI

// MARK: - Apple Watchモックアップビュー（実機レベル）
struct AppleWatchMockupView: View {
  let modelName: String?
  let isRegistered: Bool

  private var isUltra: Bool {
    modelName?.lowercased().contains("ultra") ?? false
  }

  var body: some View {
    GeometryReader { geometry in
      let baseSize: CGFloat = 300  // 基準サイズ（Watchを適度な大きさで表示）
      let availableSize = min(geometry.size.width, geometry.size.height)
      let scale = availableSize / baseSize

      VStack(spacing: 0) {
        // 上部バンド
        bandTop

        // Watch本体
        ZStack {
          watchBody

          // Digital Crown（右上）
          digitalCrown
            .offset(x: 75, y: -40)

          // サイドボタン（右下）
          sideButton
            .offset(x: 75, y: 10)
        }

        // 下部バンド
        bandBottom
      }
      .scaleEffect(scale)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .shadow(color: .black.opacity(0.4), radius: 20 * scale, x: 0, y: 10 * scale)
    }
    .frame(height: 250)
  }

  // MARK: - バンド上部
  private var bandTop: some View {
    VStack(spacing: 0) {
      Rectangle()
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.15, green: 0.15, blue: 0.15),
              Color(red: 0.12, green: 0.12, blue: 0.12),
            ],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(width: 75, height: 30)
        .cornerRadius(6, corners: [.topLeft, .topRight])
        .overlay(
          // バンドの穴のディテール
          VStack(spacing: 3) {
            ForEach(0..<3) { _ in
              RoundedRectangle(cornerRadius: 1)
                .fill(Color.black.opacity(0.3))
                .frame(width: 50, height: 2)
            }
          }
        )
    }
  }

  // MARK: - バンド下部
  private var bandBottom: some View {
    Rectangle()
      .fill(
        LinearGradient(
          colors: [
            Color(red: 0.12, green: 0.12, blue: 0.12),
            Color(red: 0.15, green: 0.15, blue: 0.15),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .frame(width: 75, height: 30)
      .cornerRadius(6, corners: [.bottomLeft, .bottomRight])
      .overlay(
        // バンドの穴のディテール
        VStack(spacing: 3) {
          ForEach(0..<3) { _ in
            RoundedRectangle(cornerRadius: 1)
              .fill(Color.black.opacity(0.3))
              .frame(width: 50, height: 2)
          }
        }
      )
  }

  // MARK: - Watch本体
  private var watchBody: some View {
    ZStack {
      // 本体のケース（外側のベゼル）
      RoundedRectangle(cornerRadius: isUltra ? 22 : 32)
        .fill(
          LinearGradient(
            colors: isRegistered
              ? [
                Color(red: 0.20, green: 0.20, blue: 0.22),
                Color(red: 0.16, green: 0.16, blue: 0.18),
                Color(red: 0.14, green: 0.14, blue: 0.16),
                Color(red: 0.12, green: 0.12, blue: 0.14),
              ]
              : [
                Color(red: 0.30, green: 0.30, blue: 0.30),
                Color(red: 0.26, green: 0.26, blue: 0.26),
                Color(red: 0.24, green: 0.24, blue: 0.24),
                Color(red: 0.22, green: 0.22, blue: 0.22),
              ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 150, height: 182)
        .overlay(
          // ケースのハイライト（光沢効果）
          RoundedRectangle(cornerRadius: isUltra ? 22 : 32)
            .strokeBorder(
              LinearGradient(
                colors: [
                  Color.white.opacity(0.25),
                  Color.white.opacity(0.08),
                  Color.clear,
                  Color.black.opacity(0.3),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1.5
            )
        )
        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

      // ディスプレイ（黒い画面）
      RoundedRectangle(cornerRadius: isUltra ? 18 : 28)
        .fill(Color.black)
        .frame(width: 138, height: 170)
        .overlay(
          // ディスプレイの反射効果（ガラスの質感）
          RoundedRectangle(cornerRadius: isUltra ? 18 : 28)
            .fill(
              LinearGradient(
                colors: [
                  Color.white.opacity(0.12),
                  Color.white.opacity(0.04),
                  Color.clear,
                  Color.clear,
                  Color.white.opacity(0.02),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
        )
        .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 2)

      // 文字盤
      watchFace
    }
  }

  // MARK: - Digital Crown
  private var digitalCrown: some View {
    ZStack {
      // Crown本体（立体的な円柱）
      Capsule()
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.28, green: 0.28, blue: 0.28),
              Color(red: 0.20, green: 0.20, blue: 0.20),
              Color(red: 0.16, green: 0.16, blue: 0.16),
              Color(red: 0.14, green: 0.14, blue: 0.14),
            ],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(width: 8, height: 40)
        .shadow(color: .black.opacity(0.4), radius: 2, x: -1, y: 0)

      // Crownの溝（リアルな質感）
      VStack(spacing: 2.5) {
        ForEach(0..<10) { _ in
          Rectangle()
            .fill(Color.black.opacity(0.4))
            .frame(width: 8, height: 1.2)
        }
      }

      // Crown上部の赤いドット（Cellular モデルの特徴）
      if isRegistered {
        Circle()
          .fill(Color.red)
          .frame(width: 4, height: 4)
          .offset(y: -20)
      }

      // Crownのハイライト（金属の光沢）
      Capsule()
        .strokeBorder(
          LinearGradient(
            colors: [
              Color.white.opacity(0.2),
              Color.clear,
              Color.clear,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 0.8
        )
        .frame(width: 8, height: 40)
    }
  }

  // MARK: - サイドボタン
  private var sideButton: some View {
    Capsule()
      .fill(
        LinearGradient(
          colors: [
            Color(red: 0.24, green: 0.24, blue: 0.24),
            Color(red: 0.18, green: 0.18, blue: 0.18),
            Color(red: 0.15, green: 0.15, blue: 0.15),
          ],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(width: 5, height: 22)
      .overlay(
        Capsule()
          .strokeBorder(
            Color.white.opacity(0.15),
            lineWidth: 0.5
          )
      )
      .shadow(color: .black.opacity(0.4), radius: 1.5, x: -0.5, y: 0)
  }

  // MARK: - 文字盤（実機スタイル - Modular）
  @ViewBuilder
  private var watchFace: some View {
    ZStack {
      // 文字盤背景
      RoundedRectangle(cornerRadius: isUltra ? 18 : 28)
        .fill(Color.black)
        .frame(width: 138, height: 170)

      VStack(spacing: 8) {
        Spacer()

        // デジタル時刻表示（9:41）
        Text("9:41")
          .font(.system(size: 52, weight: .medium, design: .default))
          .foregroundStyle(
            isRegistered
              ? LinearGradient(
                colors: [Color.green, Color.green.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
              )
              : LinearGradient(
                colors: [Color.white, Color.white.opacity(0.95)],
                startPoint: .top,
                endPoint: .bottom
              )
          )
          .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)

        // 曜日・日付表示
        HStack(spacing: 6) {
          Text("月曜日")
            .font(.system(size: 13, weight: .medium))
          Text("1月20日")
            .font(.system(size: 13, weight: .regular))
        }
        .foregroundStyle(
          isRegistered
            ? Color.green.opacity(0.85)
            : Color.white.opacity(0.7)
        )

        Spacer()

        // コンプリケーション風の装飾
        HStack(spacing: 20) {
          // 左側のコンプリケーション（アクティビティ風）
          VStack(spacing: 2) {
            ZStack {
              Circle()
                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                .frame(width: 24, height: 24)
              Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.red, lineWidth: 2)
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(-90))
            }
            Text("70%")
              .font(.system(size: 8, weight: .medium))
              .foregroundStyle(Color.white.opacity(0.6))
          }

          Spacer()

          // 右側のコンプリケーション（バッテリー風）
          VStack(spacing: 2) {
            HStack(spacing: 2) {
              RoundedRectangle(cornerRadius: 1)
                .fill(Color.green)
                .frame(width: 18, height: 10)
                .overlay(
                  RoundedRectangle(cornerRadius: 1)
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )
              Rectangle()
                .fill(Color.white.opacity(0.6))
                .frame(width: 2, height: 4)
                .cornerRadius(0.5)
            }
            Text("85%")
              .font(.system(size: 8, weight: .medium))
              .foregroundStyle(Color.white.opacity(0.6))
          }
        }
        .padding(.horizontal, 24)

        Spacer()
          .frame(height: 12)
      }
      .padding(.vertical, 12)
    }
    .frame(width: 138, height: 170)
  }
}

// MARK: - 角丸ヘルパー
extension View {
  func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
    clipShape(RoundedCorner(radius: radius, corners: corners))
  }
}

struct RoundedCorner: Shape {
  var radius: CGFloat = .infinity
  var corners: UIRectCorner = .allCorners

  func path(in rect: CGRect) -> Path {
    let path = UIBezierPath(
      roundedRect: rect,
      byRoundingCorners: corners,
      cornerRadii: CGSize(width: radius, height: radius)
    )
    return Path(path.cgPath)
  }
}
