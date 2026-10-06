# GUIアプリ

研究室で共通利用するGUIアプリの位置づけと導入先をまとめます。

実際の初期セットアップでは、各OSの手順に沿ってCLI環境の構築後に必要なGUIアプリを導入してください。

- [Windowsセットアップ](windows.md)
- [Linuxセットアップ](linux.md)
- [macOSセットアップ](macos.md)

## 対象アプリ

| アプリ | 用途 | Windows | Linux / macOS |
| --- | --- | --- | --- |
| GIMP 3.2.6 | B4論文用の画像作成 | bootstrap中に対話導入 | 手動導入 |
| KiCad 9.0系 | 回路図・PCB設計、製造データ作成 | bootstrap中に9.0.9を対話導入 | 手動導入 |
| DYNAMIXEL Wizard 2 | B3ゼミ・DYNAMIXEL設定 | 手動導入 | 手動導入 |
| Autodesk Fusion | 3D CAD | 必要な場合に手動導入 | macOSは手動導入、Linuxはネイティブ非対応 |
| Bambu Studio | Bambu Lab製3Dプリンタ用スライサー | 必要な場合に手動導入 | 必要な場合に手動導入 |

固定URL、SHA-256、インストーラー引数の確認根拠は [インストーラー・配布物の確認根拠](../reference/installer-evidence.md) に記録しています。

## DYNAMIXEL Wizard 2

公式マニュアル:

- [ROBOTIS DYNAMIXEL Wizard 2 e-Manual](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)

Windows 10 / 11 64 bit、Ubuntu 22.04 / 24.04 64 bit、macOS 13以降が公式案内の対象です。

現時点では版付き配布URL、SHA-256、無人導入用CLI引数を確認できていないため、bootstrapから自動導入しません。

導入後は次で検出を確認します。

```sh
just doctor-full
```

標準位置以外へ導入して未検出になる場合は、`DYNAMIXEL_WIZARD_PATH` に実行ファイルの絶対パスを設定します。
