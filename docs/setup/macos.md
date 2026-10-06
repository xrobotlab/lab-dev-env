# macOSセットアップ

`bootstrap.sh` はCLIとB3共通Python環境を構築します。

GUIアプリは自動導入されないため、GIMP、KiCad、DYNAMIXEL Wizard 2を続けて手動導入します。

## 1. リポジトリを取得してbootstrapを実行

```sh
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
./bootstrap.sh
```

`sudo` では実行しないでください。

## 2. GIMPを導入

[GIMP公式Downloads](https://www.gimp.org/downloads/)から、MacのCPUに合うDMGをダウンロードして導入します。

- Apple Silicon: ARM64版
- Intel Mac: x86_64版

GIMP公式はmacOS 11以降を対象に3.2.6のDMGを配布しています。

## 3. KiCad 9.0.9を導入

研究室内でPCB設計ツールを統一するため、KiCad 9.0.9を標準として使用します。

[KiCad公式macOS Downloads](https://www.kicad.org/download/macos/) の **Previous Releases** から9.0.9を取得して導入します。

## 4. DYNAMIXEL Wizard 2を導入

[ROBOTIS DYNAMIXEL Wizard 2 e-Manual](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)のmacOS手順に従って導入します。

ROBOTISの現行案内ではmacOS 13以降が対応対象です。

## 5. 用途に応じて追加ソフトを導入

- 3D CADを行う場合: [Autodesk Fusion](fusion.md)
- 研究室の3Dプリンタを使用する場合: [Bambu Studio](bambu-studio.md)
- 論文ビルドコンテナなどでDockerを使用する場合: [Docker](docker.md)

## 6. 確認

```sh
just doctor-full
```

GIMP、KiCad、DYNAMIXEL Wizard 2まで検出されることを確認します。
