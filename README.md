# lab-dev-env

XRobotLabの研究室PC向け標準開発環境です。B3は次の順に進めてください。

1. 下の表で導入するものを確認し、推奨場所にリポジトリを置く。
2. 自分のOSの手順だけを実施する: [Windows 11](#windows-11) / [macOS](#macos) / [Linux](#linux)。
3. 必要なIDEを手動導入し、共通の完了確認を行う。

## 導入するもの

表の「bootstrap」は、下のOS別手順で実行するセットアップ用ファイルです。

| 対象 | Windows 11 | macOS / Linux |
| --- | --- | --- |
| Git | 未導入ならbootstrapが導入 | セットアップ前に用意 |
| 共通ツール（コマンド）: mise、Python、Node.js/npm/npx、uv、just、gh、PlatformIO | bootstrapが導入 | bootstrapが導入 |
| Python版DYNAMIXEL SDK 4.1.0 | bootstrapが `b3/.venv` に導入 | bootstrapが `b3/.venv` に導入 |
| GIMP・KiCad 9.0系 | bootstrap中の対話インストーラーで導入 | 手動導入 |
| DYNAMIXEL Wizard 2 | 手動導入 | 手動導入 |
| VS Code・Arduino IDE 2（必要な場合） | 手動導入 | 手動導入 |

## 導入先とコマンドの実行場所

このリポジトリはセットアップ後も環境の確認・再同期に使います。一時フォルダーやダウンロードフォルダー、OneDriveなどの同期対象を避け、次の場所に置いて残してください。管理者権限が必要な場所には置きません。

| OS | 推奨場所 |
| --- | --- |
| Windows | `%USERPROFILE%\source\lab-dev-env` |
| macOS / Linux | `~/source/lab-dev-env` |

下のコード枠は、1行ずつコピーしてPowerShellまたはターミナルへ貼り付け、Enterキーを押して実行します。`$HOME` は自分のユーザーフォルダーを表すので、ユーザー名への書き換えは不要です。

`just` 本体は他の場所からも呼び出せますが、`just doctor-full` などの共通コマンドは、このリポジトリの [justfile](justfile)（実行内容を記したファイル）を使います。セットアップ後の `just` / `uv` コマンドは、`bootstrap.cmd` / `bootstrap.sh` が入っている `lab-dev-env` フォルダーへ移動してから実行します。`just` は親フォルダーの `justfile` も探すため、この中の子フォルダーからも実行できます。

## Windows 11

### 1. ZIPを取得し、決めた場所に置く

GitがないPCでも、この手順で開始できます。

1. GitHubの **Code → Download ZIP** をクリックし、ダウンロードしたZIPを右クリックして **すべて展開** を選びます。
2. **Windowsキー + E** でエクスプローラーを開き、アドレスバーへ `%USERPROFILE%` と入力してEnterキーを押します。
3. 空いている部分を右クリックし、**新規作成 → フォルダー** で `source` フォルダーを作ります。すでにあればそのフォルダーを使います。
4. 展開した中から、**`bootstrap.cmd` と `README.md` が直接入っているフォルダー**（拡張子が非表示なら `bootstrap` と `README`）を見つけ、`source` の中へコピーします。名前が `lab-dev-env-main` なら `lab-dev-env` に変更します。

展開した外側のフォルダーの中に、さらに `lab-dev-env-main` がある場合は、`bootstrap.cmd` が入っている内側を使ってください。最終的に `%USERPROFILE%\source\lab-dev-env\bootstrap.cmd` がある状態にします。

### 2. PowerShellでセットアップする

スタートメニューを開き、`PowerShell` と検索して **Windows PowerShell** を開きます。**管理者として実行しないでください。** 次を1行ずつ入力します。

```powershell
cd "$HOME\source\lab-dev-env"
.\bootstrap.cmd
```

1行目は手順1で置いたフォルダーへ移動します。2行目はセットアップを開始します。GIMPとKiCadが未導入の場合は対話インストーラーが開くので、画面に従って導入してください。

`CLIと対話式GUIセットアップが完了しました。` で始まる表示が出たら、次の手順へ進みます。`cd` で「パスが見つからない」と出た場合は、手順1の配置場所を確認してください。`bootstrap.cmd` が見つからない場合は、そのファイルが直接入っているフォルダーを配置できているか確認します。

### 3. DYNAMIXEL Wizard 2を導入する

DYNAMIXEL Wizard 2は自動導入されません。[ROBOTIS公式マニュアル](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)からWindows版を導入します。

### 4. 共通の完了確認へ進む

必要な場合は [IDEの手動導入](#ideの手動導入) を済ませ、[導入後の完了確認](#導入後の完了確認) へ進んでください。

## Linux

### 1. ターミナルを開き、Gitを確認する

アプリ一覧から **端末** または **Terminal** を開きます。

次を入力してEnterキーを押します。

```sh
git --version
```

`git version ...` と表示されれば次へ進みます。Gitが見つからない場合は、研究室の管理者に準備を依頼してください。

### 2. 推奨場所へ取得し、セットアップする

次を1行ずつ入力し、各行でEnterキーを押します。

```sh
mkdir -p "$HOME/source"
cd "$HOME/source"
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
./bootstrap.sh
```

上から順に、`source` フォルダーを作る、その中へ移動する、リポジトリを取得する、`lab-dev-env` へ移動する、セットアップを開始するコマンドです。`セットアップが完了しました。` で始まる表示が出たら、次の手順へ進みます。

`sudo` やrootでは実行しないでください。

### 3. GUIアプリを導入する

`bootstrap.sh` ではGUIアプリを導入しないため、続けて次を手動導入します。

- **GIMP**: [GIMP公式Downloads](https://www.gimp.org/downloads/)からLinux版を導入
- **KiCad 9.0系**: 研究室標準のPCB設計ツールとして導入。Ubuntuでは公式の9.0 releases PPAを使用し、その他のLinuxでは[KiCad公式Linux Downloads](https://www.kicad.org/download/arch-linux/)を参照
- **DYNAMIXEL Wizard 2**: [ROBOTIS公式マニュアル](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)からLinux版を導入

DYNAMIXELやUSBシリアル機器を使用する場合、`dialout` などのOS側設定が必要になることがあります。管理者権限が必要な作業は研究室の管理者に依頼してください。

### 4. 共通の完了確認へ進む

必要な場合は [IDEの手動導入](#ideの手動導入) を済ませ、[導入後の完了確認](#導入後の完了確認) へ進んでください。

## macOS

### 1. ターミナルを開き、Gitを確認する

**Commandキー + Space** を押し、`ターミナル` と入力してEnterキーを押します。

次を入力してEnterキーを押します。

```sh
git --version
```

`git version ...` と表示されれば次へ進みます。Gitが見つからない場合は、研究室の管理者に準備を依頼してください。

### 2. 推奨場所へ取得し、セットアップする

次を1行ずつ入力し、各行でEnterキーを押します。

```sh
mkdir -p "$HOME/source"
cd "$HOME/source"
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
./bootstrap.sh
```

上から順に、`source` フォルダーを作る、その中へ移動する、リポジトリを取得する、`lab-dev-env` へ移動する、セットアップを開始するコマンドです。`セットアップが完了しました。` で始まる表示が出たら、次の手順へ進みます。

`sudo` では実行しないでください。

### 3. GUIアプリを導入する

`bootstrap.sh` ではGUIアプリを導入しないため、続けて次を手動導入します。

- **GIMP**: [GIMP公式Downloads](https://www.gimp.org/downloads/)からmacOS版DMGを導入
- **KiCad 9.0.9**: 研究室標準のPCB設計ツールとして[KiCad公式macOS Downloads](https://www.kicad.org/download/macos/)のPrevious Releasesから9.0.9を導入
- **DYNAMIXEL Wizard 2**: [ROBOTIS公式マニュアル](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)のmacOS手順から導入

### 4. 共通の完了確認へ進む

必要な場合は [IDEの手動導入](#ideの手動導入) を済ませ、[導入後の完了確認](#導入後の完了確認) へ進んでください。

## IDEの手動導入

VS CodeとArduino IDE 2はbootstrapで自動導入されません。必要に応じて公式配布元から利用するOSの版を手動導入してください。

- **VS Code**: Windowsでは [公式Windows導入手順](https://code.visualstudio.com/docs/setup/windows) の **User Installer** を使用します。macOS / Linux版は [公式Downloads](https://code.visualstudio.com/Download) を参照してください。
- **Arduino IDE 2**: [Arduino公式Downloads](https://www.arduino.cc/en/software/) の **Arduino IDE 2** からWindows / macOS / Linux版を選択します。

IDEの使い方や拡張機能の設定はB3ゼミで扱います。

## 導入後の完了確認

OS別の手順と必要なIDEの導入を済ませたら、開いているPowerShell／ターミナルを閉じ、同じ方法で新しく開いてください。新しい画面に次を1行ずつ入力します。

**Windows PowerShell:**

```powershell
cd "$HOME\source\lab-dev-env"
just doctor-full
just b3-check
```

**macOS / Linuxのターミナル:**

```sh
cd "$HOME/source/lab-dev-env"
just doctor-full
just b3-check
```

1行目はセットアップに使った `lab-dev-env` フォルダーへ移動します。2行目は共通ツールとGIMP・KiCad・DYNAMIXEL Wizard 2の導入を調べ、3行目はB3環境からSDKが読み込めるか確認します。成功すると、それぞれ次の表示を確認できます。

```text
結果: 標準CLI準備完了（GUI検出済み）
dynamixel-sdk 4.1.0
```

`just` が見つからない場合は、セットアップの完了表示が出たことと、新しくPowerShell／ターミナルを開いたことを確認します。`[失敗]` や `準備未完了` が出た場合は表示された項目の導入を確認し、解決しなければエラー表示を添えて研究室の担当者へ相談してください。

この確認は共通ツール・GUIアプリの導入検出とSDKの読み込みが対象です。IDEの導入、GUIの起動、USBドライバー、実機通信は別途確認が必要です。

## B3でDYNAMIXEL SDKを使う

Python版SDKはこのリポジトリの `b3/.venv` に導入され、グローバルなPython環境には導入されません。コードでは `import dynamixel_sdk` として読み込みます。上の `cd` と同じ方法で `lab-dev-env` フォルダーへ移動し、B3環境を指定してPythonファイルを実行します。

```sh
uv run --locked --project b3 python path/to/script.py
```

`path/to/script.py` は実行したいPythonファイルの場所に置き換えます。例えば教材の `sample.py` を `b3` フォルダーへ置いた場合は `b3/sample.py` と指定します。`ModuleNotFoundError: No module named 'dynamixel_sdk'` が出る場合は、別のPython環境で実行していないか確認し、上記の `uv run` を使ってください。SDKが読み込めることとバージョンの確認は、実機通信の確認とは別です。

<details>
<summary>B4以上・研究用プロジェクトで使う場合（B3は読み飛ばしてOK）</summary>

卒研・修研などの別プロジェクトでSDKを使う場合は、そのリポジトリ自身の `pyproject.toml` / `uv.lock` に依存関係を宣言してください。B3共通環境を研究コードから直接使い回さない方針です。

Pythonやuvなどの共通ツールはmise、SDKはB3プロジェクトのuv依存関係として管理します。bootstrapは `uv sync --locked --project b3` でB3環境を同期します。

対象はPython版SDKの導入です。C/C++版SDKのビルドやモーターのファームウェア更新は含みません。設計判断は [B3共通環境](b3/README.md) と [ADR 0002](docs/adr/0002-toolchain-and-project-dependencies.md) を参照してください。

</details>

<details>
<summary>必要な作業だけ: 3D CAD・3Dプリンター・Docker</summary>

- 3D CADを行う場合は [Autodesk Fusion](docs/setup/fusion.md) を手動導入します。
- 研究室の3Dプリンタを使用する場合は [Bambu Studio](docs/setup/bambu-studio.md) を手動導入します。
- Dockerが必要な研究・作業では [Dockerの導入手順](docs/setup/docker.md) を実施します。

</details>

<details>
<summary>必要なときだけ: バージョン表示・再同期・別の場所からの実行</summary>

WindowsでGitを使って取得する場合は、PowerShellで次を1行ずつ実行します（ZIPで取得済みなら不要です）。

```powershell
New-Item -ItemType Directory -Force "$HOME\source" | Out-Null
cd "$HOME\source"
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
.\bootstrap.cmd
```

リポジトリのルートで、標準CLIとB3環境のDYNAMIXEL SDKのバージョンを表示します。

```sh
just versions
```

導入済み環境を再同期する場合は次を実行します。

```sh
just setup
```

別の場所からレシピを使う場合は、`just --justfile "リポジトリの絶対パス/justfile" versions` のように、実際の `justfile` の絶対パスを指定してください。

</details>

<details>
<summary>参考: 各ツールの用途（導入だけなら読み飛ばしてOK）</summary>

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

</details>

## ドキュメント

OS別の詳細手順、対象ツール、設計判断は [docs/](docs/README.md) を参照してください。
