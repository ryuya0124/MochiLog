import Foundation

struct DeviceLibrary {
  // モデルID (例: iPhone14,5) から設計容量 (mAh) を引く辞書
  static let designCapacities: [String: Int] = [
    // iPhone 16 Series
    "iPhone17,1": 4685,  // 16 Pro Max
    "iPhone17,2": 3582,  // 16 Pro
    "iPhone17,4": 4006,  // 16 Plus
    "iPhone17,3": 3561,  // 16

    // iPhone 15 Series
    "iPhone16,2": 4422,  // 15 Pro Max
    "iPhone16,1": 3274,  // 15 Pro
    "iPhone15,5": 4383,  // 15 Plus
    "iPhone15,4": 3349,  // 15

    // iPhone 14 Series
    "iPhone15,3": 4323,  // 14 Pro Max
    "iPhone15,2": 3200,  // 14 Pro
    "iPhone14,8": 4325,  // 14 Plus
    "iPhone14,7": 3279,  // 14

    // iPhone 13 Series
    "iPhone14,3": 4352,  // 13 Pro Max
    "iPhone14,2": 3095,  // 13 Pro
    "iPhone14,5": 3227,  // 13
    "iPhone14,4": 2406,  // 13 mini

    // iPhone 12 Series
    "iPhone13,4": 3687,  // 12 Pro Max
    "iPhone13,3": 2815,  // 12 Pro
    "iPhone13,2": 2815,  // 12
    "iPhone13,1": 2227,  // 12 mini

    // iPhone 11 Series
    "iPhone12,5": 3969,  // 11 Pro Max
    "iPhone12,3": 3046,  // 11 Pro
    "iPhone12,1": 3110,  // 11

    // iPhone SE
    "iPhone14,6": 2018,  // SE (3rd gen)
    "iPhone12,8": 1821,  // SE (2nd gen)

    // Older models (必要に応じて追加)
    "iPhone11,8": 2942,  // XR
    "iPhone11,6": 3174,  // XS Max
    "iPhone11,2": 2658,  // XS
    "iPhone10,3": 2716,  // X
    "iPhone10,6": 2716,  // X
  ]

  // モデルID から機種名を引く辞書
  static let deviceNames: [String: String] = [
    // iPhone 16 Series
    "iPhone17,1": "iPhone 16 Pro Max",
    "iPhone17,2": "iPhone 16 Pro",
    "iPhone17,4": "iPhone 16 Plus",
    "iPhone17,3": "iPhone 16",

    // iPhone 15 Series
    "iPhone16,2": "iPhone 15 Pro Max",
    "iPhone16,1": "iPhone 15 Pro",
    "iPhone15,5": "iPhone 15 Plus",
    "iPhone15,4": "iPhone 15",

    // iPhone 14 Series
    "iPhone15,3": "iPhone 14 Pro Max",
    "iPhone15,2": "iPhone 14 Pro",
    "iPhone14,8": "iPhone 14 Plus",
    "iPhone14,7": "iPhone 14",

    // iPhone 13 Series
    "iPhone14,3": "iPhone 13 Pro Max",
    "iPhone14,2": "iPhone 13 Pro",
    "iPhone14,5": "iPhone 13",
    "iPhone14,4": "iPhone 13 mini",

    // iPhone 12 Series
    "iPhone13,4": "iPhone 12 Pro Max",
    "iPhone13,3": "iPhone 12 Pro",
    "iPhone13,2": "iPhone 12",
    "iPhone13,1": "iPhone 12 mini",

    // iPhone 11 Series
    "iPhone12,5": "iPhone 11 Pro Max",
    "iPhone12,3": "iPhone 11 Pro",
    "iPhone12,1": "iPhone 11",

    // iPhone SE
    "iPhone14,6": "iPhone SE (3rd)",
    "iPhone12,8": "iPhone SE (2nd)",

    // Older models
    "iPhone11,8": "iPhone XR",
    "iPhone11,6": "iPhone XS Max",
    "iPhone11,2": "iPhone XS",
    "iPhone10,3": "iPhone X",
    "iPhone10,6": "iPhone X",
  ]

  static func getCapacity(for model: String) -> Int? {
    return designCapacities[model]
  }

  static func getDeviceName(for model: String) -> String? {
    return deviceNames[model]
  }
}
