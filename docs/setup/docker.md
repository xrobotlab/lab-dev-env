# Docker

Dockerは標準bootstrapの自動導入対象に含めません。

研究室配布の論文ビルドコンテナなど、Dockerが必要な研究・作業で個別に準備します。

## Windows

Docker DesktopはWindowsで利用できます。WSL 2バックエンドのユーザー単位導入も可能です。

ただし、WSL 2、Windows機能、BIOS / UEFIの仮想化などOS側の準備で管理者権限や再起動が必要になる場合があります。

公式手順:

- [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/)
- [Microsoft WSL install](https://learn.microsoft.com/windows/wsl/install)

## Linux

Docker Engineは公式手順に従って導入します。daemon導入やグループ変更などの管理者操作はbootstrapから実行しません。

- [Docker Engine install](https://docs.docker.com/engine/install/)

## ライセンス

Docker Desktopの利用条件は所属組織と用途に依存するため、研究室での利用条件を確認してから使用してください。

- [Docker Desktop license](https://docs.docker.com/subscription-billing/desktop-license/)

## 確認

`just doctor` はDocker CLI、Docker Compose、Docker Engineへの接続を個別に確認します。WindowsではWSLの状態も表示します。

CLIが存在してもEngineへの接続が失敗している場合は準備完了とは扱いません。
