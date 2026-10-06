# ADR 0005: Dockerを標準自動導入から分離する

- 状態: 採用
- 日付: 2026-10-07

## 背景

研究室配布の論文ビルドコンテナなどでDockerを利用する場合がありますが、全員が必須ではありません。

WindowsではDocker Desktop自体をユーザー単位で導入できる一方、WSL 2や仮想化などOS側の準備が必要になる場合があります。また利用条件の確認も必要です。

## 決定

Dockerは標準bootstrapの自動導入対象に含めません。

必要な研究・作業で公式手順に従って導入し、`just doctor` はDocker CLI、Compose、Engineへの接続、WindowsではWSL状態を診断します。

## 結果

- Dockerを使わない利用者に不要なOS変更を要求しない
- Dockerが必要な環境では別途導入手順が必要
- CLIの存在とEngineの稼働を分けて診断できる

導入手順は [Docker](../setup/docker.md) を参照します。
