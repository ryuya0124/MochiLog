import LinkPresentation
import SwiftUI

// UIActivityViewControllerのSwiftUIラッパー
struct ActivityViewController: UIViewControllerRepresentable {
  let activityItems: [Any]
  var thumbnailImage: UIImage?

  func makeUIViewController(context: Context) -> UIActivityViewController {
    var items: [Any] = []

    // サムネイル画像がある場合、メタデータを作成
    if let thumbnail = thumbnailImage {
      let metadata = CustomActivityItemSource(
        text: activityItems.compactMap { $0 as? String }.first ?? "",
        image: thumbnail
      )
      items.append(metadata)

      // 画像以外のアイテムを追加
      items.append(contentsOf: activityItems.filter { !($0 is UIImage) })
    } else {
      items = activityItems
    }

    let controller = UIActivityViewController(
      activityItems: items,
      applicationActivities: nil
    )
    return controller
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    // 更新不要
  }
}

// カスタムメタデータ付きアイテムソース
class CustomActivityItemSource: NSObject, UIActivityItemSource {
  let text: String
  let image: UIImage

  init(text: String, image: UIImage) {
    self.text = text
    self.image = image
    super.init()
  }

  func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController)
    -> Any
  {
    return text
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    return text
  }

  func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController)
    -> LPLinkMetadata?
  {
    let metadata = LPLinkMetadata()
    metadata.title = "MochiLog"
    metadata.iconProvider = NSItemProvider(object: image)
    metadata.imageProvider = NSItemProvider(object: image)
    return metadata
  }
}
