# lab-dev-env

XRobotLabの研究室PC向け標準開発環境です。

## 導入先とコマンドの実行場所

このリポジトリはセットアップ後も環境の確認・再同期に使います。一時フォルダーやダウンロードフォルダー、OneDriveなどの同期対象を避け、通常権限で書き込めるユーザー領域に残してください。推奨する配置場所は次のとおりです。

| OS | 推奨場所 |
| --- | --- |
| Windows | `%USERPROFILE%\source\lab-dev-env` |
| macOS / Linux | `~/source/lab-dev-env` |

セットアップ後の `just` 本体は他の場所からも呼び出せますが、`just setup`、`just doctor-full`、`just versions` などのレシピは、このリポジトリの [justfile](justfile) を使います。本文の `just` / `uv` コマンドは、セットアップ後にターミナルを再起動してからリポジトリのルート（`lab-dev-env`）で実行してください。

Windowsでは次のように移動します。

```bat
cd /d "%USERPROFILE%\source\lab-dev-env"
just versions
```

macOS / Linuxでは次のように移動します。

```sh
cd "$HOME/source/lab-dev-env"
just versions
```

`just` は親ディレクトリの `justfile` も探すため、このリポジトリの子ディレクトリからも実行できます。別の場所で使う場合は上記のように移動するか、`just --justfile "リポジトリの絶対パス/justfile" versions` のように、実際の `justfile` の絶対パスを指定してください。`just versions` は標準CLIとB3環境のDYNAMIXEL SDKのバージョンを表示します。

## Windows 11

### 1. リポジトリを取得してセットアップ

GitがないPCでは、GitHubの **Code → Download ZIP** からこのリポジトリを取得します。ZIP内のフォルダーを `%USERPROFILE%\source\lab-dev-env` に配置してください（`lab-dev-env-main` という名前なら `lab-dev-env` に変更）。配置したフォルダーで `bootstrap.cmd` を実行します。

```bat
cd /d "%USERPROFILE%\source\lab-dev-env"
bootstrap.cmd
```

Gitがある場合は次でも開始できます。

```bat
if not exist "%USERPROFILE%\source" mkdir "%USERPROFILE%\source"
cd /d "%USERPROFILE%\source"
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
mkdir -p "$HOME/source"
cd "$HOME/source"
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
mkdir -p "$HOME/source"
cd "$HOME/source"
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

## B3でDYNAMIXEL SDKを使う

bootstrapは `uv sync --locked --project b3` により、Python版の `dynamixel-sdk==4.1.0` を、このリポジトリ内の `b3/.venv` に導入します。Pythonやuvなどの共通ツールはmise、SDKはB3プロジェクトのuv依存関係として管理します。SDKはグローバルなPython環境には導入されません。

セットアップ後にターミナルを再起動し、このリポジトリのルート（`lab-dev-env`）で実行します。コードでは `import dynamixel_sdk` として読み込みます。

```sh
just b3-check
uv run --locked --project b3 python path/to/script.py
```

`path/to/script.py` は、リポジトリのルートからの相対パス、または絶対パスに置き換えます。`ModuleNotFoundError: No module named 'dynamixel_sdk'` が出る場合は、別のPython環境で実行していないか確認し、上記の `uv run` でB3環境を指定してください。`just b3-check` はSDKのimportとバージョン表示を確認するもので、実機通信を確認するものではありません。

対象はPython版SDKの導入です。C/C++版SDKのビルド、USBドライバー、DYNAMIXEL Wizard 2の導入、モーターのファームウェア更新は含みません。

卒研・修研などの別プロジェクトでSDKを使う場合は、そのリポジトリ自身の `pyproject.toml` / `uv.lock` に依存関係を宣言してください。詳細は [B3共通環境](b3/README.md) と [ADR 0002](docs/adr/0002-toolchain-and-project-dependencies.md) を参照してください。

## IDEの手動導入

VS CodeとArduino IDE 2はbootstrapで自動導入されません。必要に応じて公式配布元から利用するOSの版を手動導入してください。

- **VS Code**: Windowsでは [公式Windows導入手順](https://code.visualstudio.com/docs/setup/windows) の **User Installer** を使用します。macOS / Linux版は [公式Downloads](https://code.visualstudio.com/Download) を参照してください。
- **Arduino IDE 2**: [Arduino公式Downloads](https://www.arduino.cc/en/software/) の **Arduino IDE 2** からWindows / macOS / Linux版を選択します。

IDEの使い方や拡張機能の設定はB3ゼミで扱います。

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
