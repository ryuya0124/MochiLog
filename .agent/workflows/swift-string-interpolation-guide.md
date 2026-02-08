---
description: Swift文字列補間でのエスケープエラー防止ガイド
---

# Swift文字列補間でのエスケープエラー防止

## 問題の概要

Swiftのprint文などで文字列補間を使用する際、`String(format:)`内でダブルクォートをエスケープしようとすると、以下のようなビルドエラーが発生する:

```
Cannot find ')' to match opening '(' in string interpolation
Unterminated string literal
```

## よくある間違い

❌ **誤り**：
```swift
print("[Performance] 処理完了: \(String(format: \"%.2f\", elapsed))ms")
```

このコードは、文字列補間`\(...)`の中で`\"`を使おうとしているため、Swiftのパーサーがうまく解釈できず、エラーになります。

## 正しい書き方

✅ **正解**：
```swift
print("[Performance] 処理完了: \(String(format: "%.2f", elapsed))ms")
```

文字列補間`\(...)`の**内部**では、ダブルクォートをエスケープする必要はありません。

## 理由

Swiftの文字列補間では、`\(...)`の内部は独立したSwift式として評価されます。そのため、内部の文字列リテラルは通常通り`"`で記述します。

## チェックリスト

文字列補間を含むprint文を書く際は、以下を確認:

- [ ] `\(...)`の内部で`\"`を使っていないか
- [ ] `String(format:)`の引数は`"`で囲んでいるか（`\"`ではない）
- [ ] ビルド前に同様のパターンのコードを検索して確認

## 検索方法

同様のエラーを見つけるには、以下のパターンで検索:

```bash
grep -r 'String(format: \\"' .
```

該当があれば修正が必要です。

## 参考例

### 他の文字列補間パターン

```swift
// ✅ 正しい例
print("値: \(value), フォーマット: \(String(format: "%.2f", number))")
print("結果: \(result ? "成功" : "失敗")")

// ❌ 間違った例  
print("値: \(value), フォーマット: \(String(format: \"%.2f\", number))")
print("結果: \(result ? \"成功\" : \"失敗\")")
```

## 今後の対応

1. **コードレビュー時の確認項目に追加**
2. **SwiftLintルールの追加を検討**（該当ルールがあれば）
3. **テンプレートやスニペットの使用**

## 関連リソース

- Swift String Interpolation公式ドキュメント
- SwiftLintルール: `string_interpolation`
