# lab-dev-env

XRobotLabの研究室PC向け標準開発環境です。B3は次の順に進めてください。

1. 下の表で導入するものを確認する。
2. 自分のOSの手順だけを実施する: [Windows 11](#windows-11) / [macOS](#macos) / [Linux](#linux)。
3. 表示された標準GUIの手動導入を済ませ、共通の完了確認を行う。

## 導入するもの

表の「bootstrap」は、下のOS別手順で実行するセットアップ用ファイルです。

| 対象 | Windows 11 | macOS / Linux |
| --- | --- | --- |
| Git | 未導入ならbootstrapが導入 | セットアップ前に用意 |
| 共通ツール（コマンド）: mise、Python、Node.js/npm/npx、uv、just、gh、PlatformIO | bootstrapが導入 | bootstrapが導入 |
| Python版DYNAMIXEL SDK 4.1.0 | bootstrapが `b3/.venv` に導入 | bootstrapが `b3/.venv` に導入 |
| GIMP・KiCad・VS Code | wingetで不足分をユーザー単位で導入 | macOSは既存HomebrewでGIMP・VS Codeを導入、KiCadとLinuxは手動 |
| Arduino IDE 2・Bambu Studio | wingetのportable形式で不足分を導入 | macOSは既存Homebrewで導入、Linuxは手動 |
| DYNAMIXEL Wizard 2 | 手動導入 | 手動導入 |
| Docker・Autodesk Fusion（任意） | 必要な場合だけ手動導入 | 必要な場合だけ手動導入（FusionのLinuxネイティブ版はなし） |

標準GUIは上記6本です。GUIの版は固定せず、導入済みアプリは保持します。bootstrapの再実行で既存アプリを更新しません。パッケージ管理ツールが未準備、適用できるユーザー単位の配布物がない、または通常権限で扱えない場合は公式の手動手順が表示されます。任意導入はDockerとFusionだけです。

## 導入先とコマンドの実行場所

このリポジトリはセットアップ後も環境の確認・再同期に使います。WindowsのZIP版はbootstrapが次の場所へ自動コピーするため、自分でフォルダーを作成・移動する必要はありません。展開元は残ります。macOS / Linuxは下のOS別手順で取得します。

| OS | セットアップに使う場所 |
| --- | --- |
| Windows（ZIP版） | `%USERPROFILE%\source\lab-dev-env`（自動配置） |
| macOS / Linux | `~/source/lab-dev-env` |

セットアップ後はこの場所を残してください。Gitで取得したWindowsの作業コピーは、履歴を保つため取得した場所をそのまま使います。

下のコード枠は、1行ずつコピーしてPowerShellまたはターミナルへ貼り付け、Enterキーを押して実行します。`$HOME` は自分のユーザーフォルダーを表すので、ユーザー名への書き換えは不要です。

`just` 本体は他の場所からも呼び出せますが、`just doctor-full` などの共通コマンドは、このリポジトリの [justfile](justfile)（実行内容を記したファイル）を使います。セットアップ後の `just` / `uv` コマンドは、`bootstrap.cmd` / `bootstrap.sh` が入っている `lab-dev-env` フォルダーへ移動してから実行します。`just` は親フォルダーの `justfile` も探すため、この中の子フォルダーからも実行できます。

## Windows 11

### 1. ZIPを取得し、展開する

GitがないPCでも、この手順で開始できます。[研究室の公式GitHubリポジトリ](https://github.com/xrobotlab/lab-dev-env)を開き、`xrobotlab/lab-dev-env` と、案内されたブランチ（指定がなければ `main`）であることを確認します。**Code → Download ZIP** をクリックし、ダウンロードしたZIPを右クリックして **すべて展開** を選びます。

### 2. bootstrap.cmdをダブルクリックする

この操作で **「開いているファイル - セキュリティの警告」** が出て、「発行元を確認できませんでした」や「不明な発行元」と表示される場合があります。上記の公式リポジトリ・ブランチから取得したZIPで、警告のファイル名が **`bootstrap.cmd`**、名前欄の場所が**自分で展開したフォルダー**と一致することを確認できた場合は、**実行(R)** を選びます。

別のファイル名や想定外の取得元、ここで説明したものと異なる警告の場合は操作を止め、表示を添えて研究室の担当者へ相談してください。

展開した中の **`bootstrap.cmd`**（拡張子が非表示なら `bootstrap`）を通常のダブルクリックで開きます。ZIPの中から直接開かず、**すべて展開した後**に実行してください。**管理者として実行しないでください。**

必要なファイルが `%USERPROFILE%\source\lab-dev-env` へ自動コピーされ、その場所でPowerShellのセットアップ画面が開きます。手動での配置やコマンド入力は不要です。

wingetが利用できる場合、未導入のGIMP・KiCad・VS Codeは別ウィンドウに対話インストーラーが開きます。Arduino IDE 2・Bambu Studioはユーザー領域へportable形式で導入します。**インストールが終わるまでセットアップ画面を閉じないでください。** 画面に従ってユーザー単位で導入します。完了画面ではアプリの起動を選ばずに閉じます。起動した場合は、そのアプリも閉じるとセットアップが続きます。

**`完了。この画面を閉じて構いません。`** と出たら、Enterキーで閉じて次へ進みます。**`標準GUIの手動確認が必要`** と出た場合は、表示された公式手順へ進みます。エラー時は完了とは表示されません。表示を控え、原因を解消してから配置先の `bootstrap.cmd` を開いて再実行してください。

「配置先は既に存在します」と出た場合は上書きされていません。既存フォルダー内の `bootstrap.cmd` を使ってください。既存フォルダーが何のものか分からない場合は削除せず、研究室の担当者へ相談してください。

### 3. DYNAMIXEL Wizard 2を導入する

DYNAMIXEL Wizard 2は自動導入されません。[ROBOTIS公式マニュアル](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)からWindows版を導入します。

### 4. 共通の完了確認へ進む

未検出の標準GUIを [公式配布元](#標準guiの公式配布元) から導入し、[導入後の完了確認](#導入後の完了確認) へ進んでください。

## Linux

<details>
<summary>Linux利用者のみ: セットアップ手順を開く</summary>

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

上から順に、`source` フォルダーを作る、その中へ移動する、リポジトリを取得する、`lab-dev-env` へ移動する、セットアップを開始するコマンドです。CLIが導入されると、標準GUIの結果が表示されます。手動確認が必要と表示された項目を次の手順で導入します。

`sudo` やrootでは実行しないでください。

### 3. GUIアプリを導入する

Linuxでは標準GUIを手動導入します。次の3本に加え、[公式配布元](#標準guiの公式配布元)からVS Code・Arduino IDE 2・Bambu Studioも導入してください。

- **GIMP**: [GIMP公式Downloads](https://www.gimp.org/downloads/)からLinux版を導入
- **KiCad**: [KiCad公式Downloads](https://www.kicad.org/download/)から利用ディストリビューション向けの安定版を導入（9.0系への制限はありません）
- **DYNAMIXEL Wizard 2**: [ROBOTIS公式マニュアル](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)からLinux版を導入

DYNAMIXELやUSBシリアル機器を使用する場合、`dialout` などのOS側設定が必要になることがあります。管理者権限が必要な作業は研究室の管理者に依頼してください。

### 4. 共通の完了確認へ進む

未検出の標準GUIを [公式配布元](#標準guiの公式配布元) から導入し、[導入後の完了確認](#導入後の完了確認) へ進んでください。

</details>

## macOS

<details>
<summary>macOS利用者のみ: セットアップ手順を開く</summary>

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

上から順に、`source` フォルダーを作る、その中へ移動する、リポジトリを取得する、`lab-dev-env` へ移動する、セットアップを開始するコマンドです。CLIが導入されると、標準GUIの結果が表示されます。手動確認が必要と表示された項目を次の手順で導入します。

`sudo` では実行しないでください。

### 3. GUIアプリを導入する

既存のHomebrewが通常権限の導入制御に対応している場合、GIMP・VS Code・Arduino IDE 2・Bambu Studioの不足分を `~/Applications` に導入します。Homebrew自体はbootstrapで導入しません。未準備なら[公式配布元](#標準guiの公式配布元)から導入してください。

KiCadのHomebrew定義は共有領域への配置を含むため、自動導入しません。次を手動導入します。

- **KiCad**: [KiCad公式macOS Downloads](https://www.kicad.org/download/macos/)から安定版を導入
- **DYNAMIXEL Wizard 2**: [ROBOTIS公式マニュアル](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)のmacOS手順から導入

### 4. 共通の完了確認へ進む

未検出の標準GUIを [公式配布元](#標準guiの公式配布元) から導入し、[導入後の完了確認](#導入後の完了確認) へ進んでください。

</details>

## 標準GUIの公式配布元

自動導入が利用できない項目、未検出の項目は次から導入します。すでに導入済みなら版を変更する必要はありません。独自の場所への導入と検出の指定は [GUIアプリ](docs/setup/gui-apps.md) を参照してください。

- **GIMP**: [公式Downloads](https://www.gimp.org/downloads/)
- **KiCad**: [公式Downloads](https://www.kicad.org/download/)
- **Bambu Studio**: [公式Downloads](https://bambulab.com/en/download/studio)
- **DYNAMIXEL Wizard 2**: [ROBOTIS公式マニュアル](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)
- **VS Code**: Windowsでは [公式Windows導入手順](https://code.visualstudio.com/docs/setup/windows) の **User Installer** を使用します。macOS / Linux版は [公式Downloads](https://code.visualstudio.com/Download) を参照してください。
- **Arduino IDE 2**: [Arduino公式Downloads](https://www.arduino.cc/en/software/) の **Arduino IDE 2** からWindows / macOS / Linux版を選択します。

IDEの使い方や拡張機能の設定はB3ゼミで扱います。

## 導入後の完了確認

OS別の手順と標準GUI6本の導入を済ませたら、新しいPowerShell／ターミナルを開いてください。Windowsではスタートメニューで `PowerShell` を検索し、**Windows PowerShell** を通常権限で開きます。macOS / Linuxは上のOS別手順と同じ方法でターミナルを開きます。次を1行ずつ入力します。

WindowsのGit作業コピーを使った場合は、下の1行目を実際に取得したフォルダーのパスへ置き換えます。

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

1行目はセットアップに使った `lab-dev-env` フォルダーへ移動します。2行目は共通ツールと標準GUI6本の導入を調べ、3行目はB3環境からSDKが読み込めるか確認します。成功すると、それぞれ次の表示を確認できます。

```text
結果: 標準CLI準備完了（GUI検出済み）
dynamixel-sdk 4.1.0
```

`just` が見つからない場合は、セットアップの完了表示が出たことと、新しくPowerShell／ターミナルを開いたことを確認します。`[失敗]` や `準備未完了` が出た場合は表示された項目の導入を確認し、解決しなければエラー表示を添えて研究室の担当者へ相談してください。

この確認は共通ツール・GUIアプリの導入検出とSDKの読み込みが対象です。GUIの起動、USBドライバー、実機通信は別途確認が必要です。

## B3でDYNAMIXEL SDKを使う

Python版SDKはこのリポジトリの `b3/.venv` に導入され、グローバルなPython環境には導入されません。コードでは `import dynamixel_sdk` として読み込みます。上の `cd` と同じ方法で `lab-dev-env` フォルダーへ移動し、B3環境を指定してPythonファイルを実行します。

```sh
uv run --locked --project b3 python path/to/script.py
```

`path/to/script.py` は実行したいPythonファイルの場所に置き換えます。例えば教材の `sample.py` を `b3` フォルダーへ置いた場合は `b3/sample.py` と指定します。`ModuleNotFoundError: No module named 'dynamixel_sdk'` が出る場合は、別のPython環境で実行していないか確認し、上記の `uv run` を使ってください。SDKが読み込めることとバージョンの確認は、実機通信の確認とは別です。

エディターから実行する場合も、Windowsでは `b3\.venv\Scripts\python.exe`、macOS / Linuxでは `b3/.venv/bin/python` をPython環境として選択します。

<details>
<summary>B4以上・研究用プロジェクトで使う場合（B3は読み飛ばしてOK）</summary>

卒研・修研などの別プロジェクトでSDKを使う場合は、そのリポジトリ自身の `pyproject.toml` / `uv.lock` に依存関係を宣言してください。B3共通環境を研究コードから直接使い回さない方針です。

Pythonやuvなどの共通ツールはmise、SDKはB3プロジェクトのuv依存関係として管理します。bootstrapは `uv sync --locked --project b3` でB3環境を同期します。

対象はPython版SDKの導入です。C/C++版SDKのビルドやモーターのファームウェア更新は含みません。設計判断は [B3共通環境](b3/README.md) と [ADR 0002](docs/adr/0002-toolchain-and-project-dependencies.md) を参照してください。

</details>

<details>
<summary>必要な作業だけ: 3D CAD・Docker</summary>

- 3D CADを行う場合は [Autodesk Fusion](docs/setup/fusion.md) を手動導入します。
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

SDKが見つからない場合に、B3環境のPythonの場所とSDKの版を確認するコマンドです。エディターのPython環境がこの実行先と一致するか確認してください。

```sh
uv run --locked --project b3 python -c "import sys; from importlib.metadata import version; print(sys.executable); print(version('dynamixel-sdk'))"
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
| VS Code | 研究用コードや設定ファイルを編集するコードエディター（標準GUI） |
| Arduino IDE 2 | Arduino用プログラム（スケッチ）の編集・ビルド・マイコンへの書き込み（標準GUI） |
| PlatformIO Core | マイコン向けファームウェアのビルド、ライブラリ管理、書き込み |
| DYNAMIXEL SDK | PythonからDYNAMIXELを制御するためのライブラリ |
| GIMP | B4論文などで使用する図・画像の作成、加工 |
| KiCad | 回路図・PCB設計、JLCPCBなどへ発注する製造データの作成 |
| DYNAMIXEL Wizard 2 | DYNAMIXELの検出、設定変更、診断、ファームウェア管理 |
| Autodesk Fusion | 3D CAD、機械部品・治具などの3Dモデル作成（必要な場合に手動導入） |
| Bambu Studio | Bambu Lab製3Dプリンタ向けのスライス、印刷設定、G-code確認（標準GUI） |
| Docker | 研究室配布の論文ビルドコンテナなどを実行する場合に使用（任意導入） |

</details>

## ドキュメント

OS別の詳細手順、対象ツール、設計判断は [docs/](docs/README.md) を参照してください。
