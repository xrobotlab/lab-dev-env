# lab-dev-env

XRobotLabの研究室PC向け標準開発環境です。

## Windows 11

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

管理者として実行しないでください。

## Linux / macOS

Gitを用意したうえで実行します。

```sh
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
./bootstrap.sh
```

`sudo` では実行しないでください。

## セットアップ後の確認

```sh
just doctor
```

GUIアプリまで含めて確認する場合:

```sh
just doctor-full
```

環境を再同期する場合:

```sh
just setup
```

## ドキュメント

詳細な導入手順、対象ツール、設計判断は [docs/](docs/README.md) を参照してください。
