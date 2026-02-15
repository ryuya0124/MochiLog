# マイグレーションシステム

## 概要

このディレクトリには、MochiLogアプリのデータベースマイグレーション機能が含まれています。マイグレーションシステムは、アプリのバージョンアップ時に既存データを自動的に修正・更新するために使用されます。

## ファイル構成

```
Migrations/
├── README.md                              # このファイル
├── Migration.swift                        # マイグレーションプロトコル定義
├── MigrationManager.swift                 # マイグレーション管理クラス
└── Migration_v1_iPhone16e_AvgTemp.swift  # v1マイグレーション実装
```

## 使い方

### 新しいマイグレーションの追加方法

1. **新しいマイグレーションファイルを作成**

```swift
import Foundation
import SwiftData

struct Migration_v2_YourFeature: Migration {
  static let version = "v2_YourFeature"
  static let description = "あなたのマイグレーションの説明"

  static func migrate(modelContext: ModelContext) throws {
    print("[Migration \(version)] Starting migration: \(description)")

    // マイグレーション処理をここに記述
    let descriptor = FetchDescriptor<BatteryRecord>()
    let records = try modelContext.fetch(descriptor)

    for record in records {
      // データの修正処理
      // ...
    }

    print("[Migration \(version)] Completed.")
  }
}
```

2. **MigrationManager.swiftに登録**

```swift
private static let migrations: [Migration.Type] = [
  Migration_v1_iPhone16e_AvgTemp.self,
  Migration_v2_YourFeature.self,  // ← 追加
]
```

### バージョンベースのマイグレーション

特定のバージョンからのアップデート時のみマイグレーションを実行したい場合：

```swift
// アプリバージョンを取得
let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
let previousVersion = UserDefaults.standard.string(forKey: "LastKnownAppVersion")

// バージョン比較してマイグレーション実行を判定
if shouldMigrate(from: previousVersion, to: currentVersion) {
  // マイグレーション処理
}

// 現在のバージョンを保存（次回起動時のため）
UserDefaults.standard.set(currentVersion, forKey: "LastKnownAppVersion")
```

## マイグレーションの実行タイミング

マイグレーションは、アプリ起動時に`MochiLogApp.swift`の`.task`モディファイアで自動実行されます：

```swift
.task {
  MigrationManager.runPendingMigrations(modelContext: container.mainContext)
}
```

**重要**: マイグレーションは**バックグラウンドスレッド**で実行されるため、UIをブロックしません。大量のデータがある場合でも、アプリはスムーズに起動します。

## 実装済みマイグレーション

### v1: iPhone 16e容量修正 & avgTemp修正

**ファイル**: `Migration_v1_iPhone16e_AvgTemp.swift`

**実行条件**:
- **iPhone 16e容量修正**: 常に実行（designCapacity が 3961 の場合のみ）
- **avgTemp修正**: バージョン2.0.0以下からのアップデート時のみ実行

**変更内容**:
1. iPhone 16eの設計容量を 3961mAh → 4005mAh に修正
2. avgTempが10°C未満の場合、10倍に修正（2.5°C → 25.0°C）

## デバッグ機能

### マイグレーションの再実行

```swift
// 特定のマイグレーションを再実行
MigrationManager.rerunMigration(version: "v1_iPhone16e_AvgTemp", modelContext: context)
```

### 全マイグレーションフラグのリセット

```swift
// 全てのマイグレーションフラグをリセット（開発用）
MigrationManager.resetAllMigrations()
```

## 注意事項

- マイグレーションは**一度だけ実行**されます（UserDefaultsでフラグ管理）
- マイグレーションの順序は`MigrationManager.swift`の配列順で実行されます
- エラーが発生した場合、そのマイグレーションはスキップされ、次のマイグレーションが実行されます
- バージョンベースのマイグレーションは、`LastKnownAppVersion`キーで管理されます
- マイグレーションは**バックグラウンドスレッド**で実行されるため、UIに影響を与えません

## ベストプラクティス

1. **マイグレーションは冪等性を保つ**: 同じマイグレーションを複数回実行しても安全であること
2. **条件チェックを行う**: 既に修正済みのデータをスキップする（例: `designCapacity == 3961`の場合のみ修正）
3. **ログを充実させる**: マイグレーション実行状況を詳細にログ出力する
4. **バージョン管理を明確に**: マイグレーションファイル名とバージョン番号を一致させる
