# lab-dev-env

XRobotLab の研究室PC向け標準開発環境です。

このリポジトリは **公開** です。研究室のGitHub組織への参加前でもクローンでき、貸与PCを受け取った直後の初期セットアップに使えることを目的としています。

## 方針

- Windowsは GitHub の **Download ZIP → 展開 → bootstrap.cmd** から開始でき、Gitの事前導入は不要
- Python / Node.js / uv / just / PlatformIO / gh は `mise` でバージョン固定する
- GIMP（B4）とKiCad（B3）はWindowsでハッシュ検証後に対話インストーラーを起動する。DYNAMIXEL Wizard 2（B3）は公式の手動導入を案内する
- B3ゼミで全員が使う DYNAMIXEL SDK は専用の uv 環境として必ず構築する
- 研究固有の Python 依存関係は各研究リポジトリの `pyproject.toml` / `uv.lock` に置く
- 通常CLIセットアップは **管理者権限なし** で行う。GUIの前提コンポーネントが管理者権限を要求したら導入を中止し、管理者に相談する
- USB/シリアルドライバやLinuxのudevルール・グループ設定など、OS権限が必要な処理は通常セットアップから分離する
- シークレット、研究室内部URL、個人情報、秘密鍵はこの公開リポジトリに置かない

## 標準バージョン

| ツール | バージョン | 管理方法 |
| --- | ---: | --- |
| mise | 2026.10.3 | 初期導入処理 |
| Python | 3.13.16 | mise |
| Node.js | 24.21.0 LTS | mise |
| npm / npx | Node.js付属 | mise経由 |
| uv | 0.12.23 | mise |
| just | 1.58.0 | mise |
| PlatformIO Core | 6.1.19 | mise（`pypi:` バックエンド） |
| GitHub CLI (gh) | 2.102.0 | mise |
| DYNAMIXEL SDK（Python） | 4.1.0 | `b3/` のuv環境 |
| Git for Windows | 2.56.0.2 | Gitがない場合のみPortableGit |
| GIMP | 3.2.6 | Windows: `config/windows-apps.json` |
| KiCad | 9.0.9 | Windows: `config/windows-apps.json` |
| DYNAMIXEL Wizard 2 | 手動導入 | ROBOTIS公式配布 |

> 各研究リポジトリは必要に応じて異なるPythonや依存バージョンを指定して構いません。このリポジトリの値は研究室PCの共通基準です。

## セットアップ

### Windows 11

Windows 11 **x64** の通常ユーザーを対象とします。現在の `mise.lock` のWindows版とGUIの配布物はx64固定です。ARM64では自動導入を停止します。

GitがないPCでは、[リポジトリ](https://github.com/xrobotlab/lab-dev-env) の **Code → Download ZIP** を選び、ZIPを完全に展開してから `bootstrap.cmd` を実行します。ZIP内から直接実行しないでください。

Gitがある場合は、通常権限のコマンドプロンプトまたはWindows Terminalで次も使えます。

```bat
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
bootstrap.cmd
```

`bootstrap.cmd` はWindows向けの入口で、UTF-8の `scripts/bootstrap.ps1` を読み込んで実行します。PowerShellの実行ポリシーは変更しません。GitがPATHにない場合はPortableGitを `%LOCALAPPDATA%\lab-dev-env\PortableGit\2.56.0.2` に展開します。mise本体は `%LOCALAPPDATA%\mise` に導入し、残りのCLIとB3環境を構築します。Git、mise、GIMP、KiCadは固定URLとSHA-256を検証してから実行します。ダウンロード・展開の一時物は実行ごとのOS一時フォルダーで管理し、終了時に削除します。ユーザーPATHだけを更新します。CLIの導入に `winget` と管理者権限は不要です。GUIの前提コンポーネントについては後述の手順を確認してください。**管理者として実行しないでください。**

ZIPからの導入はGitリポジトリへの変換やGitHubへのログインを行いません。組織参加後に開発する際は別途 `git clone` してください。`gh auth login` は利用者が必要になった時に実行します。

### Linux / macOS

```sh
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
./bootstrap.sh
```

`bootstrap.sh` は mise を `~/.local/bin` にユーザー権限で導入します。**sudoで実行しないでください。**

Linux / macOSではGitを事前に用意してください。GUIアプリはOS別の公式配布から手動導入します。Linuxのパッケージ導入・USB権限変更を通常bootstrapから実行しません。

## セットアップ後

```sh
just doctor
```

標準CLIは必須判定し、GUI、Docker、シリアル機器は状態と手動対応を表示します。GIMP / KiCad / DYNAMIXEL Wizard 2 の未検出も終了コード1にするには `just doctor-full` を使います。GUI検出は実行ファイルの存在確認であり、起動・固定バージョン一致・実機接続の保証ではありません。CIはGUIやDockerの導入を要求しない通常の `just doctor` を使用します。

## GUIアプリ

WindowsのGIMP / KiCadの固定URL、SHA-256、対話導入方式は `config/windows-apps.json` にまとめています。無人導入用の引数は使用しません。既存のアプリが別の場所に登録されている場合は自動更新せず手動確認を案内します。

| アプリ | 対象 | Windowsの導入方法 |
| --- | --- | --- |
| GIMP | B4 | SHA-256検証後、Inno Setupの対話画面。既定のユーザー領域は `%LOCALAPPDATA%\Programs\GIMP 3` |
| KiCad | B3 | SHA-256検証後、NSISの対話画面。既定のユーザー領域は `%LOCALAPPDATA%\Programs\KiCad\9.0` |
| DYNAMIXEL Wizard 2 | B3 | 下記の公式配布から手動導入 |

ユーザー単位の導入を指定するGIMPの `/CURRENTUSER` は[3.2.6公式ソース](https://raw.githubusercontent.com/GNOME/gimp/GIMP_3_2_6/build/windows/installer/gimp-setup.iss)と[Inno Setup公式資料](https://jrsoftware.org/ishelp/topic_setupcmdline.htm)、KiCadの `/currentuser` は[公式パッケージのIssue #135](https://gitlab.com/kicad/packaging/kicad-win-builder/-/work_items/135)と[同梱MultiUserソース](https://gitlab.com/kicad/packaging/kicad-win-builder/-/raw/master/nsis/includes/NsisMultiUser.nsh)に根拠があります。この指定だけを使い、導入先は画面で確認します。PortableGitの展開引数は[Git for Windows公式資料](https://gitforwindows.org/zip-archives-extracting-the-released-archives.html)に従います。

KiCadの公式パッケージ作成ソースにはVisual C++ Runtimeの導入処理もあります。ユーザー単位のアプリ導入でも前提コンポーネントまで管理者権限不要とは保証しません。管理者権限の要求はキャンセルし、管理者が必要な準備を行ってから再実行してください。

Linux / macOSのGIMPとKiCadは、それぞれ[GIMP公式](https://www.gimp.org/downloads/)と[KiCad公式](https://www.kicad.org/download/)からOSに合う方法で導入してください。

配布物・引数の一次情報と未確認事項は[導入根拠](docs/installer-evidence.md)を参照してください。KiCadの現行安定版は10.0.6ですが、今回は既存の候補9.0.9を固定しています。インストーラ実行、Git未導入PCからの初回導入、GUI起動は通信可能なWindows 11での追加検証が必要です。

### DYNAMIXEL Wizard 2

[ROBOTIS公式マニュアル](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)と[ダウンロードセンター](https://www.robotis.com/service/downloadpage.php?ca_id=10)を入口とします。

| OS | 公式配布 |
| --- | --- |
| Windows 10 / 11（64 bit） | [Windows x64 インストーラー](https://www.robotis.com/service/download.php?no=1670) |
| Ubuntu 22.04 / 24.04（64 bit） | [Linux x64](https://www.robotis.com/service/download.php?no=1671)、[Linux ARM64](https://www.robotis.com/service/download.php?no=2233) |
| macOS 13以降 | 公式マニュアルのApp Storeリンク |

2026-10-07の調査では公式マニュアルに対話式の導入手順を確認しました。Windows配布物の取得がこの検証環境の通信制限でできないため、`--help`、`/S`、`/silent`、`/VERYSILENT`、MSI形式、Qt Installer FrameworkのCLI対応、`strings` による形式識別は **未検証** です。無人導入が非対応と断定する根拠はありません。[QtのCLI資料](https://doc.qt.io/qtinstallerframework/ifw-cli.html)だけでROBOTISの配布物も対応すると判断せず、自動実行用URL・SHA-256・引数の固定は追加していません。

公式インストーラーをダウンロードして通常ユーザーで起動し、ユーザーが書き込めるインストール先を選んで画面の手順に従ってください。Windowsはexe、Linuxは実行形式です。Linuxで実行権限がなければ、取得した自分のファイルに `chmod u+x <インストーラー名>` を適用してから実行します。管理者権限を要求された場合は研究室の管理者に相談してください。

導入後はGUIを起動して確認し、`just doctor-full` を実行します。独自の場所に導入して未検出になる場合は `DYNAMIXEL_WIZARD_PATH` に実行ファイルの絶対パスを設定してください。USB / シリアルの権限とドライバは別途確認します。

版付きURL・SHA-256が未確定のため、今回は自動ダウンロード・起動を行わず公式配布URLへの案内を採用します。固定版とハッシュを確認できた場合にのみ、検証後に対話インストーラーを起動する方式を追加できます。

LinuxのUSBアクセスについて、公式マニュアルは `sudo usermod -aG dialout <your_account_id>` と再起動を案内しています。利用者名を確認して研究室の管理者が実施する作業であり、bootstrapから実行しません。追加のudevルールも自動作成しません。

## Dockerを使う研究

Dockerは通常bootstrapの自動導入対象に含めません。`just doctor` はDocker CLI、Compose、Engineへの接続を別々に確認し、WindowsではWSLの状態も表示します。CLIの存在だけでEngine準備完了とは判断しません。

[公式ライセンス説明](https://docs.docker.com/subscription-billing/desktop-license/)では教育利用は無料対象です。政府機関や大規模組織の業務利用などには有料条件があるため、実際の所属組織・用途と契約を確認します。今回はこの確認とOS側の準備を通常セットアップから分離します。

Windowsは[Docker Desktop公式手順](https://docs.docker.com/desktop/setup/install/windows-install/)に従ってください。現在はWSL 2バックエンドを使う **ユーザー単位導入** があり、Docker Desktop本体の導入・更新は管理者権限なしで行えます。一方、WSL 2、Windows機能、BIOS/UEFIの仮想化の準備には管理者作業や再起動が必要になる場合があります。Hyper-V / Windowsコンテナー / 全ユーザー導入も権限条件が異なります。[MicrosoftのWSL手順](https://learn.microsoft.com/en-us/windows/wsl/install)を管理者と確認してください。

準備済みのPCではDocker Desktopを利用者が手動導入・起動し、ライセンス条件を確認してから `docker version` と `docker compose version` で接続を確かめます。Linuxは[Docker Engine公式手順](https://docs.docker.com/engine/install/)に従います。daemon導入やグループ変更は管理者の作業です。bootstrap / doctorはWSL有効化、Dockerサービス起動、管理者昇格、グループ追加を自動で行いません。

環境を更新・再同期する場合:

```sh
just setup
```

B3共通Python環境だけを同期する場合:

```sh
just b3-sync
```

DYNAMIXEL SDKのインポート確認:

```sh
just b3-check
```

## 研究リポジトリでDYNAMIXEL SDKを使う場合

B3環境にSDKが入っていても、研究コードが依存するなら **研究リポジトリ側にも依存関係として宣言** してください。

```sh
uv add dynamixel-sdk==4.1.0
```

その研究の `uv.lock` に残すことで、別PCや後任者も同じ依存関係を再現できます。B3環境を直接使い回すことは想定していません。

## 権限が必要になり得るもの

通常のツール導入はユーザー権限で行います。次はOS側の設定なので例外です。

- Windows：一部のUSB / シリアル / デバッグプローブ用ドライバ
- Linux：`/dev/ttyUSB*`、`/dev/ttyACM*` のudevルールや `dialout` などのグループ設定
- NVIDIAドライバ / CUDAなどのシステムコンポーネント

`just doctor` は可能な範囲で状態を検出しますが、これらを勝手に管理者権限で変更しません。

## 責務の境界

```text
OS / ドライバ
  └─ 必要な場合のみ管理者権限

lab-dev-env
  ├─ Python
  ├─ Node.js + npm/npx
  ├─ uv
  ├─ just
  ├─ PlatformIO
  └─ B3共通環境
       └─ dynamixel-sdk

研究リポジトリ
  ├─ pyproject.toml
  ├─ uv.lock
  ├─ package.json / package-lock.json（必要な場合）
  ├─ platformio.ini（必要な場合）
  └─ justfile
```

## 公開リポジトリについて

このリポジトリには認証情報を保存しません。公開する目的は、GitHubアカウント作成・研究室組織への招待・参加の完了前でも初期セットアップを開始できるようにすることです。
