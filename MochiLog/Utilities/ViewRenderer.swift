import SwiftUI

/// SwiftUIビューを画像にレンダリングするユーティリティ
@MainActor
struct ViewRenderer {
  /// SwiftUIビューをUIImageにスナップショット
  /// - Parameters:
  ///   - view: レンダリングするSwiftUIビュー
  ///   - size: レンダリングサイズ（オプション）
  ///   - scale: 画像のスケール（デフォルト3.0で高解像度）
  /// - Returns: レンダリングされたUIImage、失敗時はnil
  static func snapshot<Content: View>(
    view: Content,
    size: CGSize? = nil,
    scale: CGFloat = 3.0
  ) -> UIImage? {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale

    // サイズが指定されている場合は設定
    if let size = size {
      renderer.proposedSize = ProposedViewSize(size)
    }

    return renderer.uiImage
  }
}
