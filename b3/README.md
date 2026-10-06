# B3共通環境

B3ゼミで共通利用するPython環境です。

現在の必須依存関係：

- `dynamixel-sdk==4.1.0`

セットアップ：

```sh
just b3-sync
```

確認：

```sh
just b3-check
```

この環境は教材用の共通環境です。卒研・修研のコードがDYNAMIXEL SDKを利用する場合、その研究リポジトリ自身の `pyproject.toml` / `uv.lock` に依存を宣言してください。
