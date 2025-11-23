<div align="center">
  <h1> this is a fork repo </h1>
  <h2> thanks for Beingpax </h2>
  <h3> https://github.com/Beingpax/VoiceInk </h3>
</div>

<div align="center">
  <img src="VoiceInk/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>VoiceInk</h1>
  <p>音声をほぼ瞬時にテキストに変換するmacOS用音声入力アプリ</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
  [![GitHub release (latest by date)](https://img.shields.io/github/v/release/Beingpax/VoiceInk)](https://github.com/Beingpax/VoiceInk/releases)
  ![GitHub all releases](https://img.shields.io/github/downloads/Beingpax/VoiceInk/total)
  ![GitHub stars](https://img.shields.io/github/stars/Beingpax/VoiceInk?style=social)
  <p>
    <a href="https://tryvoiceink.com">Website</a> •
    <a href="https://www.youtube.com/@tryvoiceink">YouTube</a>
  </p>

  <a href="https://tryvoiceink.com">
    <img src="https://img.shields.io/badge/Download%20Now-Latest%20Version-blue?style=for-the-badge&logo=apple" alt="Download VoiceInk" width="250"/>
  </a>
</div>

---

VoiceInkは、音声をほぼ瞬時にテキストに変換するネイティブmacOSアプリケーションです。すべての情報とアプリのダウンロードは[こちら](https://tryvoiceink.com)から。

![VoiceInk Mac App](https://github.com/user-attachments/assets/12367379-83e7-48a6-b52c-4488a6a04bba)

過去5ヶ月間このアプリの開発に専念した後、より良い未来のためにオープンソース化することを決定しました。

私の目標は、**macOS向けの最も効率的でプライバシーを重視した音声テキスト変換ソリューション**を作り、使うことが喜びとなるようにすることです。ソースコードは経験豊富な開発者がビルドして貢献できるようになっていますが、ライセンスを購入することで継続的な開発をサポートし、自動アップデート、優先サポート、今後の機能へのアクセスが得られます。

## 機能

- 🎙️ **高精度な文字起こし**: ローカルAIモデルが99%の精度でほぼ瞬時に音声をテキストに変換
- 🔒 **プライバシー第一**: 100%オフライン処理により、データがデバイスから外部に送信されることはありません
- ⚡ **パワーモード**: インテリジェントなアプリ検出により、使用中のアプリ/URLに基づいて事前設定した最適な設定を自動適用
- 🧠 **コンテキスト認識**: 画面の内容を理解し、コンテキストに適応するスマートAI
- 🎯 **グローバルショートカット**: クイック録音とプッシュトゥトーク機能のための設定可能なキーボードショートカット
- 📝 **個人辞書**: カスタムワード、業界用語、スマートテキスト置換でAIに独自の用語を学習させる
- 🔄 **スマートモード**: 異なる執筆スタイルやコンテキストに最適化されたAI駆動モードを瞬時に切り替え
- 🤖 **AIアシスタント**: ChatGPTのような会話型アシスタントのための組み込み音声アシスタントモード

## はじめに

### ダウンロード
[tryvoiceink.com](https://tryvoiceink.com)から無料トライアル付きの最新バージョンを入手してください。購入することで、私がVoiceInkのフルタイム開発を続け、新機能やアップデートで継続的に改善することを支援できます。

#### Homebrew
または、`brew`を使ってVoiceInkをインストールすることもできます：

```shell
brew install --cask voiceink
```

### ソースからビルド
オープンソースプロジェクトとして、[BUILDING.md](BUILDING.md)の手順に従ってVoiceInkを自分でビルドすることができます。ただし、コンパイル済みバージョンには、自動アップデート、Discordとメールによる優先サポートなどの追加特典があり、継続的な開発資金の支援にもなります。

## 必要要件

- macOS 14.0以降

## ドキュメント

- [ソースからビルド](BUILDING.md) - プロジェクトのビルド手順の詳細
- [貢献ガイドライン](CONTRIBUTING.md) - VoiceInkへの貢献方法
- [行動規範](CODE_OF_CONDUCT.md) - コミュニティ標準

## 貢献

貢献を歓迎します！ただし、すべての貢献はプロジェクトの目標とビジョンに沿ったものである必要があります。機能や修正の作業を開始する前に：

1. [貢献ガイドライン](CONTRIBUTING.md)をお読みください
2. 提案する変更について議論するためのissueを開いてください
3. メンテナーからのフィードバックをお待ちください

ビルド手順については、[ビルドガイド](BUILDING.md)をご覧ください。

## ライセンス

このプロジェクトはGNU General Public License v3.0の下でライセンスされています - 詳細は[LICENSE](LICENSE)ファイルをご覧ください。

## サポート

問題が発生した場合や質問がある場合は：
1. GitHubリポジトリの既存のissueを確認してください
2. 問題がまだ報告されていない場合は、新しいissueを作成してください
3. 環境と問題について可能な限り詳細を提供してください

## 謝辞

### コアテクノロジー
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - OpenAIのWhisperモデルの高性能推論
- [FluidAudio](https://github.com/FluidInference/FluidAudio) - Parakeetモデルの実装に使用

### 必須の依存関係
- [Sparkle](https://github.com/sparkle-project/Sparkle) - VoiceInkを最新の状態に保つ
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - ユーザーカスタマイズ可能なキーボードショートカット
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) - ログイン時の起動機能
- [MediaRemoteAdapter](https://github.com/ejbills/mediaremote-adapter) - 録音中のメディア再生制御
- [Zip](https://github.com/marmelroy/Zip) - ファイル圧縮・解凍ユーティリティ
- [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit) - 選択されたテキストを取得するための最新macOSライブラリ
- [Swift Atomics](https://github.com/apple/swift-atomics) - スレッドセーフな並行プログラミングのための低レベルアトミック操作


---

Paxによって❤️を込めて作成
