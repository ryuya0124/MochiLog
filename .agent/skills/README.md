# MochiLog Skills 使用ガイド

## 概要

`.agent/skills/` ディレクトリには、開発中に蓄積されたナレッジとベストプラクティスが保存されています。

## Skillsの自動読み込み

Antigravityは会話開始時に`.agent/skills/`内の全てのSKILL.mdファイルを自動的にスキャンします。

## 現在のSkills

### swift-common-errors
Swift開発でよくあるエラーと修正方法のナレッジベース

**使用タイミング:**
- ビルドエラーが発生したとき
- 類似のエラーパターンを確認したいとき
- 新しいエラーを記録するとき

## エラー記録ワークフロー

### 1. エラー発生時
```
ユーザー: [ビルドエラーを報告]
AI: エラーを分析して修正
```

### 2. エラー解決後
```
ユーザー: 「治った」または「修正完了」
AI: 
  1. swift-common-errors/SKILL.mdを開く
  2. 新しいエラー記録を追加
  3. 日付、原因、修正方法、予防策を記載
```

### 3. 定期的なメンテナンス
エラー記録が20件を超えたら:
- カテゴリ別にファイル分割
- インデックスファイル作成
- 古いエラーのアーカイブ

## Skill肥大化の防止策

### 自動分割スクリプト
エラー数が閾値を超えたら、自動的にカテゴリ別ファイルに分割:

```bash
# .agent/skills/swift-common-errors/scripts/organize.sh
#!/bin/bash
# エラー記録を自動的にカテゴリ別に整理
```

### カテゴリ例
- `errors/string-errors.md` - 文字列関連
- `errors/type-errors.md` - 型関連
- `errors/concurrency-errors.md` - 並行性関連
- `errors/access-control-errors.md` - アクセス制御関連

## 他のSkillの追加

新しいSkillを追加する場合:

```bash
mkdir -p .agent/skills/[skill-name]
```

SKILL.mdを作成:
```markdown
---
name: Skill Name
description: Skillの簡潔な説明
---

# Skill内容
```

## ベストプラクティス

1. **記録は具体的に**: エラーメッセージと修正コードを含める
2. **検索しやすく**: キーワードとタグを適切に使用
3. **定期的に整理**: 月1回程度レビュー
4. **重複を避ける**: 既存の記録を確認してから追加
