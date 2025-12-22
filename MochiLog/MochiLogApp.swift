import SwiftUI
import SwiftData

@main
struct MochiLogApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // ここ重要！これがないとクラッシュします
        .modelContainer(for: BatteryRecord.self)
    }
}