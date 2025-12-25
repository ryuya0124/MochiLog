# MochiLog
MochiLog は Apple Watch と iPhone のバッテリー・サイクル情報を記録・可視化する軽量な iOS/iPadOS アプリです。

## ✨ 主な特徴

- バッテリーレコードの保存・一覧表示
- デバイス別のフィルタリング（検索可能なデバイス選択）
- 日次・週次・月次のチャート表示（自動単位選択）
- チャートのウィンドウ移動（前／次）や期間切替
- ローカライズ対応（日本語／英語）

## 🛠️ 動作環境 / 要件

- Xcode 26 以上（Swift 5 / iOS 17 SDK を想定）
- macOS（開発マシン）

## ▶️ ビルドと実行

1. リポジトリをクローン:

```sh
git clone https://github.com/ryuya0124/MochiLog.git
cd MochiLog
```

2. Xcode でプロジェクトを開き、ターゲットを選んでビルド・実行します。

またはコマンドラインからビルド:

```sh
xcodebuild -project MochiLog.xcodeproj -scheme MochiLog -configuration Debug build
```

> 注意: 実機での実行には有効な署名とプロビジョニングプロファイルが必要です。

## 🧪 テスト / 検証

- 単体テストは現時点で限定的です。主要な機能は手動で UI を確認してください。

## 🤝 貢献方法

1. Issue を立てるか、Pull Request を送ってください。
2. 変更点は簡潔にまとめ、可能ならテストを追加してください。

## 📄 ライセンス

このプロジェクトは `LICENSE` に従います。

## 🔗 参考 / 連絡先

- リポジトリ: https://github.com/ryuya0124/MochiLog