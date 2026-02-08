---
name: Swift Common Errors
description: Swift開発でよくあるエラーと修正方法のナレッジベース
---

# Swift開発 よくあるエラーと修正方法

このskillは、MochiLog開発中に発生したエラーとその修正方法を記録します。

## エラー記録フォーマット

各エラーは以下の形式で記録:
- **日付**: エラー発生日
- **エラー内容**: エラーメッセージと状況
- **原因**: なぜエラーが発生したか
- **修正方法**: どう修正したか
- **予防策**: 今後同じエラーを防ぐ方法

---

## 記録されたエラー

### 1. 文字列補間内のエスケープエラー (2026-02-08)

**エラー内容:**
```
Cannot find ')' to match opening '(' in string interpolation
Unterminated string literal
```

**発生コード:**
```swift
print("[Performance] 処理完了: \(String(format: \"%.2f\", elapsed))ms")
```

**原因:**
文字列補間`\(...)`の内部で`\"`を使用すると、Swiftのパーサーが混乱する。

**修正方法:**
```swift
// ✅ 正解
print("[Performance] 処理完了: \(String(format: "%.2f", elapsed))ms")
```

文字列補間の**内部**では、ダブルクォートをエスケープする必要はない。

**予防策:**
- コード作成時: 文字列補間内では常に`"`を使用（`\"`を使わない）
- コードレビュー時: `grep -r 'String(format: \\"' .` で検索
- 参考: [swift-string-interpolation-guide.md](file:///Users/ryuya/Documents/MochiLog/.agent/workflows/swift-string-interpolation-guide.md)

---

### 2. extensionからprivateプロパティへのアクセスエラー (2026-02-08)

**エラー内容:**
```
'appSettings' is inaccessible due to 'private' protection level
```

**発生コード:**
```swift
struct HomeView: View {
  private let appSettings = AppSettings.shared
}

extension HomeView {
  func someMethod() {
    appSettings.someProperty // ❌ エラー
  }
}
```

**原因:**
Swiftでは、`private`なプロパティは同じファイル内でも、extension内からはアクセスできない。

**修正方法:**
```swift
struct HomeView: View {
  let appSettings = AppSettings.shared // privateを削除
}
```

または`fileprivate`を使用:
```swift
struct HomeView: View {
  fileprivate let appSettings = AppSettings.shared
}
```

**予防策:**
- extensionで使用する可能性のあるプロパティは`private`にしない
- `fileprivate`または`internal`（デフォルト）を使用

---

## 使い方

### エラー発生時
1. このファイルを開く
2. 上記のフォーマットに従って新しいエラーを記録
3. 日付順に整理

### 参照時
1. エラーメッセージで検索
2. 類似のエラーパターンを確認
3. 修正方法と予防策を適用

---

## メンテナンス

エラーが20件を超えたら:
1. カテゴリ別にファイルを分割（文字列、型、並行性など）
2. `errors/`ディレクトリを作成
3. インデックスファイルで一覧管理

---

## 関連リソース

- [swift-string-interpolation-guide.md](file:///Users/ryuya/Documents/MochiLog/.agent/workflows/swift-string-interpolation-guide.md) - 文字列補間の詳細ガイド
