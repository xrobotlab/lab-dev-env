# GUIアプリ

研究室で共通利用するGUIアプリの導入方法をまとめます。

## Windows

| アプリ | 用途 | 導入方法 |
| --- | --- | --- |
| GIMP 3.2.6 | B4論文用の画像作成 | bootstrapが配布物をSHA-256検証後、対話インストーラーを起動 |
| KiCad 9.0.9 | B3電子工作 | bootstrapが配布物をSHA-256検証後、対話インストーラーを起動 |
| DYNAMIXEL Wizard 2 | B3ゼミ・DYNAMIXEL設定 | ROBOTIS公式配布から手動導入 |

GIMPとKiCadはユーザー単位の導入を指定します。管理者権限を要求された場合は自動昇格せず、キャンセルして研究室の管理者へ相談してください。

固定URL、SHA-256、インストーラー引数の確認根拠は [インストーラー・配布物の確認根拠](../reference/installer-evidence.md) に記録しています。

## DYNAMIXEL Wizard 2

公式マニュアルとダウンロードセンターを入口として導入します。

- [ROBOTIS DYNAMIXEL Wizard 2 e-Manual](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)
- [ROBOTIS Download Center](https://www.robotis.com/service/downloadpage.php?ca_id=10)

Windows 10 / 11 64 bit、Ubuntu 22.04 / 24.04 64 bit、macOS 13以降が公式案内の対象です。

現時点では版付き配布URL、SHA-256、無人導入用CLI引数を確認できていないため、bootstrapから自動導入しません。

導入後は次で検出を確認します。

```sh
just doctor-full
```

標準位置以外へ導入して検出されない場合は、`DYNAMIXEL_WIZARD_PATH` に実行ファイルの絶対パスを設定します。

## LinuxのUSBアクセス

DYNAMIXELやUSBシリアル機器へのアクセスで `dialout` などのグループ設定が必要になる場合があります。これは管理者操作としてbootstrapから分離しています。

## macOS / LinuxのGIMP・KiCad

各OS向けの公式配布方法を利用してください。

- [GIMP Downloads](https://www.gimp.org/downloads/)
- [KiCad Download](https://www.kicad.org/download/)
