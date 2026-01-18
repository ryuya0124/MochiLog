import SwiftUI

/// コンテンツを画像としてキャッシュ・表示するビューラッパー
/// 静的なコンテンツ（スクロールしても変化しないもの）の描画負荷を軽減するために使用します。
struct CachedView<Content: View, ID: Hashable>: View {
  let id: ID
  let content: Content
  let scale: CGFloat

  @State private var cachedImage: UIImage?

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
    Group {
      if let image = cachedImage {
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fit)
      } else {
        // 画像生成前は元のViewを表示しつつ、レンダリングを試みる
        content
          .onAppear {
            render()
          }
      }
    }
    .id(id)  // IDが変わったら再生成
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
    // すでにキャッシュがあれば何もしない
    guard cachedImage == nil else { return }

    // ColorSchemeを適用した状態でレンダリング
    let contentWithEnv = content.environment(\.colorScheme, colorScheme)

    // ViewRendererを使用してスナップショットを作成
    // サイズはコンテンツのintrinsicサイズになる
    if let image = ViewRenderer.snapshot(view: contentWithEnv, scale: scale) {
      self.cachedImage = image
    }
  }
}
