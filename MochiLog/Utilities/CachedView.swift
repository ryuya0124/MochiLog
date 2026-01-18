import SwiftUI

/// コンテンツを画像としてキャッシュ・表示するビューラッパー
/// 静的なコンテンツ（スクロールしても変化しないもの）の描画負荷を軽減するために使用します。
struct SizePreferenceKey: PreferenceKey {
  static var defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
    value = nextValue()
  }
}

struct CachedView<Content: View, ID: Hashable>: View {
  let id: ID
  let content: Content
  let scale: CGFloat

  @State private var cachedImage: UIImage?
  @State private var currentSize: CGSize = .zero
  @Environment(\.colorScheme) var colorScheme

  init(
    id: ID,
    scale: CGFloat = 3.0,
    @ViewBuilder content: () -> Content
  ) {
    self.id = id
    self.scale = scale
    self.content = content()
  }

  var body: some View {
    content
      .background(
        GeometryReader { proxy in
          Color.clear
            .preference(key: SizePreferenceKey.self, value: proxy.size)
        }
      )
      .onPreferenceChange(SizePreferenceKey.self) { newSize in
        if currentSize != newSize {
          currentSize = newSize
          // サイズ変更時はキャッシュを破棄して再生成
          cachedImage = nil
          render()
        }
      }
      .opacity(cachedImage == nil ? 1 : 0)
      .overlay(
        Group {
          if let image = cachedImage {
            Image(uiImage: image)
              .resizable()
          }
        }
      )
      .id(id)
      .onChange(of: id) {
        cachedImage = nil
        render()
      }
      .onChange(of: colorScheme) {
        cachedImage = nil
        render()
      }
  }

  @MainActor
  private func render() {
    // コンテンツサイズが確定していない場合はレンダリングしない
    guard currentSize != .zero else { return }

    // ColorSchemeを適用した状態でレンダリング
    let contentWithEnv = content.environment(\.colorScheme, colorScheme)

    // ViewRendererを使用してスナップショットを作成
    // 現在のサイズ(currentSize)を指定してレンダリング
    if let image = ViewRenderer.snapshot(view: contentWithEnv, size: currentSize, scale: scale) {
      self.cachedImage = image
    }
  }
}
