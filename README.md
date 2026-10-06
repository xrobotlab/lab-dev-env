# lab-dev-env

XRobotLab の研究室PC向け標準開発環境です。

このリポジトリは **公開** です。研究室のGitHub組織への参加前でもクローンでき、貸与PCを受け取った直後の初期セットアップに使えることを目的としています。

## 方針

- 初回クローンに必要な **Gitだけを事前要件** とする
- Python / Node.js / uv / just / PlatformIO は `mise` でバージョン固定する
- B3ゼミで全員が使う DYNAMIXEL SDK は専用の uv 環境として必ず構築する
- 研究固有の Python 依存関係は各研究リポジトリの `pyproject.toml` / `uv.lock` に置く
- 通常セットアップは **管理者権限なし** で完結させる
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
| DYNAMIXEL SDK（Python） | 4.1.0 | `b3/` のuv環境 |

> 各研究リポジトリは必要に応じて異なるPythonや依存バージョンを指定して構いません。このリポジトリの値は研究室PCの共通基準です。

## セットアップ

### Windows 11

Git for Windowsでこのリポジトリをクローンした後、通常権限のコマンドプロンプトまたはWindows Terminalで実行します。

```bat
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
bootstrap.cmd
```

`bootstrap.cmd` はWindows向けの入口で、UTF-8の `scripts/bootstrap.ps1` を読み込んで実行します。PowerShellの実行ポリシーは変更しません。本体は固定版のmiseをGitHubの公式リリースからユーザー領域へ直接取得し、リポジトリに固定したSHA-256と照合してから、残りのツールとB3環境を構築します。`winget` は不要です。**管理者として実行しないでください。**

### Linux / macOS

```sh
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
./bootstrap.sh
```

`bootstrap.sh` は mise を `~/.local/bin` にユーザー権限で導入します。**sudoで実行しないでください。**

## セットアップ後

```sh
just doctor
```

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
