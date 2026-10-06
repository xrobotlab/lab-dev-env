# lab-dev-env

XRobotLabの研究室PC向け標準開発環境です。

## Windows 11

### 1. リポジトリを取得してセットアップ

GitがないPCでは、GitHubの **Code → Download ZIP** からこのリポジトリを取得し、ZIPを展開して `bootstrap.cmd` を実行します。

```bat
bootstrap.cmd
```

Gitがある場合は次でも開始できます。

```bat
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
bootstrap.cmd
```

管理者として実行しないでください。GIMPとKiCadが未導入の場合は、セットアップ中に対話インストーラーが開くので画面に従って導入します。

### 2. DYNAMIXEL Wizard 2を導入

DYNAMIXEL Wizard 2は自動導入されません。[ROBOTIS公式マニュアル](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)からWindows版を導入します。

### 3. 確認

```bat
just doctor-full
```

3D CADを行う場合は[Autodesk Fusion](docs/setup/fusion.md)、研究室の3Dプリンタを使用する場合は[Bambu Studio](docs/setup/bambu-studio.md)を手動導入します。Dockerが必要な研究・作業では[Dockerの導入手順](docs/setup/docker.md)も実施します。

## Linux

### 1. リポジトリを取得してセットアップ

Gitを用意したうえで実行します。

```sh
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
./bootstrap.sh
```

`sudo` やrootでは実行しないでください。

### 2. GUIアプリを導入

`bootstrap.sh` ではGUIアプリを導入しないため、続けて次を手動導入します。

- **GIMP**: [GIMP公式Downloads](https://www.gimp.org/downloads/)からLinux版を導入
- **KiCad 9.0系**: 研究室標準のPCB設計ツールとして導入。Ubuntuでは公式の9.0 releases PPAを使用し、その他のLinuxでは[KiCad公式Linux Downloads](https://www.kicad.org/download/arch-linux/)を参照
- **DYNAMIXEL Wizard 2**: [ROBOTIS公式マニュアル](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)からLinux版を導入

DYNAMIXELやUSBシリアル機器を使用する場合、`dialout` などのOS側設定が必要になることがあります。管理者権限が必要な作業は研究室の管理者に依頼してください。

### 3. 確認

```sh
just doctor-full
```

3D CADを行う場合は[Autodesk Fusion](docs/setup/fusion.md)、研究室の3Dプリンタを使用する場合は[Bambu Studio](docs/setup/bambu-studio.md)を手動導入します。Dockerが必要な研究・作業では[Dockerの導入手順](docs/setup/docker.md)も実施します。

## macOS

### 1. リポジトリを取得してセットアップ

Gitを用意したうえで実行します。

```sh
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
./bootstrap.sh
```

`sudo` では実行しないでください。

### 2. GUIアプリを導入

`bootstrap.sh` ではGUIアプリを導入しないため、続けて次を手動導入します。

- **GIMP**: [GIMP公式Downloads](https://www.gimp.org/downloads/)からmacOS版DMGを導入
- **KiCad 9.0.9**: 研究室標準のPCB設計ツールとして[KiCad公式macOS Downloads](https://www.kicad.org/download/macos/)のPrevious Releasesから9.0.9を導入
- **DYNAMIXEL Wizard 2**: [ROBOTIS公式マニュアル](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)のmacOS手順から導入

### 3. 確認

```sh
just doctor-full
```

3D CADを行う場合は[Autodesk Fusion](docs/setup/fusion.md)、研究室の3Dプリンタを使用する場合は[Bambu Studio](docs/setup/bambu-studio.md)を手動導入します。Dockerが必要な研究・作業では[Dockerの導入手順](docs/setup/docker.md)も実施します。

## 環境の再同期

```sh
just setup
```

## ドキュメント

OS別の詳細手順、対象ツール、設計判断は [docs/](docs/README.md) を参照してください。

## 各ツールの用途

| ツール | 用途 |
| --- | --- |
| Git | ソースコードのバージョン管理、研究リポジトリの取得・更新 |
| GitHub CLI (`gh`) | GitHubのリポジトリ、Issue、Pull Requestなどをターミナルから操作 |
| mise | Python、Node.js、uv、justなどの開発ツールのバージョン管理・導入 |
| Python | 研究用スクリプト、解析、シミュレーション、B3ゼミ用コードの実行 |
| uv | Pythonの仮想環境、依存関係、lockファイル、Pythonパッケージの管理 |
| Node.js | JavaScript / TypeScript系の開発・ツール実行 |
| npm / npx | Node.jsプロジェクトの依存関係管理、npmパッケージのCLI実行 |
| just | `just setup`、`just doctor` など、研究室で共通化したコマンドの実行 |
| PlatformIO Core | マイコン向けファームウェアのビルド、ライブラリ管理、書き込み |
| DYNAMIXEL SDK | PythonからDYNAMIXELを制御するためのライブラリ |
| GIMP | B4論文などで使用する図・画像の作成、加工 |
| KiCad | 回路図・PCB設計、JLCPCBなどへ発注する製造データの作成 |
| DYNAMIXEL Wizard 2 | DYNAMIXELの検出、設定変更、診断、ファームウェア管理 |
| Autodesk Fusion | 3D CAD、機械部品・治具などの3Dモデル作成（必要な場合に手動導入） |
| Bambu Studio | Bambu Lab製3Dプリンタ向けのスライス、印刷設定、G-code確認（必要な場合に手動導入） |
| Docker | 研究室配布の論文ビルドコンテナなどを実行する場合に使用（任意導入） |
