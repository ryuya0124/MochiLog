import SwiftUI

// UIActivityViewControllerのSwiftUIラッパー
struct ActivityViewController: UIViewControllerRepresentable {
  let activityItems: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let controller = UIActivityViewController(
      activityItems: activityItems,
      applicationActivities: nil
    )
    return controller
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    // 更新不要
  }
}
