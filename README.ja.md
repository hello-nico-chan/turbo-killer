# TurboKiller

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

TurboKiller は、対応する Intel Mac 上で Intel Turbo Boost を制御するための、無料かつオープンソースの macOS メニューバーユーティリティです。

> **現在の状態:** プレリリース版です。現在の Legacy Kext バックエンドは、System Integrity Protection（SIP）が有効な Intel Mac で動作確認されています。より広範なハードウェアおよび macOS の互換性テスト、正式な署名、Apple の公証は引き続き進行中です。

## 動作要件

- Intel Mac
- macOS 13 以降
- System Integrity Protection（SIP）を無効にする必要はありません
- Apple silicon はサポートされません

## 仕組み

TurboKiller には、固定された過去版の `DisableTurboBoost.64bits.kext` が同梱されています。

アプリは `SMAppService` を利用して特権 LaunchDaemon を登録し、XPC 経由で通信します。アプリと Helper の双方でコード署名要件を使用し、相手の身元を検証します。

root 権限で動作する Helper は次の処理を行います。

- 同梱 Kext の実行ファイルを固定 SHA-256 と照合する
- `/Library/Application Support/TurboKiller` にインストールする
- 所有権を `root:wheel` に設定する
- Kext をロードして Turbo Boost を無効にする
- Kext をアンロードして Turbo Boost を復元する

Turbo Boost Switcher を別途インストールする必要はありません。

現在の Turbo Boost 状態は UI 内部の状態ではなく、`kmutil` を使って実際にロードされている Kext の状態から判断します。

## 初回起動

新しい環境では、macOS が以下の 2 つについて個別の承認を要求する場合があります。

1. TurboKiller の特権バックグラウンド Helper
2. Legacy Turbo Boost カーネル拡張

Kext の承認後、一度だけ再起動が必要になる場合があります。

初回承認が完了した後は、通常の Turbo Boost の切り替えで管理者パスワードや再起動は必要ありません。

## セキュリティ

TurboKiller の特権インターフェースは意図的に最小限に制限されています。

Helper は任意の Shell コマンド実行機能や任意の MSR アクセスを提供せず、固定された Turbo Boost Kext の準備、ロード、アンロードに必要な操作だけを公開します。

アプリと Helper はコード署名要件を利用して相互に認証します。

特権インストールの前に、同梱 Kext の実行ファイルは SHA-256 でも検証されます。

## プロジェクト構成

`TurboKiller/`
: メニューバーアプリ、UI、状態管理、Turbo Boost コントローラー、Helper クライアント。

`TurboKillerHelper/`
: root として動作し、Kext のインストール、ロード、アンロードを担当する LaunchDaemon。

`TurboKillerHelperProtocol.swift`
: アプリと Helper が共有する XPC インターフェース。

`TurboKiller/Resources/DisableTurboBoost.64bits.kext`
: 現在のバックエンドで使用される固定済みの歴史的 Turbo Boost Kext。

`experiments/TurboKillerKext/`
: 初期の読み取り専用 Kext 実験。正式な製品には含まれません。

## ビルド

Xcode で `TurboKiller.xcodeproj` を開き、`TurboKiller` target をビルドします。

同梱されている歴史的 Kext はバイト単位で変更してはいけません。再ビルド、変更、再署名を行わないでください。

## 互換性

TurboKiller は、Apple によって非推奨となった Legacy Kernel Extension の互換経路に依存しています。

そのため、すべての Intel CPU 世代や将来のすべての macOS バージョンでの動作を保証するものではありません。

## ライセンス

TurboKiller は GNU General Public License version 2 の下で配布されます。

プロジェクトのライセンスについては `LICENSE`、同梱されている第三者コンポーネントについては `THIRD_PARTY_NOTICES.md` を参照してください。