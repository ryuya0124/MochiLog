import Foundation
import SwiftData

@Model
final class BatteryRecord {
    var date: Date
    var cycleCount: Int
    var maxCapacityPercent: Double // OS表示上の最大容量(%)
    var realCapacitymAh: Int       // 実際の容量(mAh)
    var designCapacitymAh: Int     // 設計上の容量(mAh)
    var deviceName: String         // デバイス名 (例: iPhone 15 Pro)
    
    // 計算プロパティ: 実際の劣化率を計算
    var realHealthPercent: Double {
        guard designCapacitymAh > 0 else { return 0.0 }
        return (Double(realCapacitymAh) / Double(designCapacitymAh)) * 100.0
    }

    init(date: Date, cycleCount: Int, maxCapacityPercent: Double, realCapacitymAh: Int, designCapacitymAh: Int, deviceName: String = "iPhone") {
        self.date = date
        self.cycleCount = cycleCount
        self.maxCapacityPercent = maxCapacityPercent
        self.realCapacitymAh = realCapacitymAh
        self.designCapacitymAh = designCapacitymAh
        self.deviceName = deviceName
    }
}