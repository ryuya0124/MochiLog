import SwiftUI

// MARK: - Apple Watch機種定義
enum WatchModel: String, CaseIterable, Identifiable {
  case series9_41mm = "Apple Watch Series 9 (41mm)"
  case series9_45mm = "Apple Watch Series 9 (45mm)"
  case se_40mm = "Apple Watch SE (40mm)"
  case se_44mm = "Apple Watch SE (44mm)"
  case ultra2 = "Apple Watch Ultra 2 (49mm)"

  var id: String { rawValue }

  // 画面サイズ（ポイント）
  var screenSize: CGSize {
    switch self {
    case .series9_41mm, .se_40mm:
      return CGSize(width: 162, height: 197)
    case .series9_45mm, .se_44mm:
      return CGSize(width: 176, height: 215)
    case .ultra2:
      return CGSize(width: 205, height: 251)
    }
  }

  // 角丸の半径
  var cornerRadius: CGFloat {
    switch self {
    case .ultra2:
      return 27  // Ultraは角ばっている
    default:
      return 40  // Series/SEは丸い
    }
  }

  // ベゼル幅
  var bezelWidth: CGFloat {
    switch self {
    case .ultra2:
      return 7
    default:
      return 5
    }
  }

  // デバイス全体のサイズ
  var deviceSize: CGSize {
    CGSize(
      width: screenSize.width + bezelWidth * 2,
      height: screenSize.height + bezelWidth * 2
    )
  }
}
