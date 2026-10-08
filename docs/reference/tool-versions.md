# 標準ツールと固定バージョン

CLI・SDKの固定値の正本は `mise.toml`、`mise.lock`、`config/windows-apps.json`、`b3/uv.lock` です。この文書は人間向けの一覧です。

| ツール | バージョン | 管理 |
| --- | ---: | --- |
| mise | 2026.10.3 | bootstrap |
| Python | 3.13.16 | mise |
| Node.js | 24.21.0 LTS | mise |
| npm / npx | Node.js付属 | mise |
| uv | 0.12.23 | mise |
| just | 1.58.0 | mise |
| PlatformIO Core | 6.1.19 | mise |
| GitHub CLI (`gh`) | 2.102.0 | mise |
| DYNAMIXEL SDK（Python） | 4.1.0 | `b3/` のuv環境 |
| Git for Windows | 2.56.0.2 | Git未導入時のPortableGit |
| GIMP / KiCad / VS Code / Arduino IDE 2 / Bambu Studio | 固定なし | 標準GUI。導入方式は [共通一覧](../../config/gui-apps.json) と [GUI手順](../setup/gui-apps.md) |
| DYNAMIXEL Wizard 2 | 固定なし | 標準GUI。公式手動導入 |
| Autodesk Fusion / Docker | 固定なし | 任意。必要な場合だけ手動導入 |

## 更新時

固定バージョンを変更する場合は、lockファイルとCIを更新し、必要に応じて [導入根拠](installer-evidence.md) も更新してください。

GUIは現在の安定配布を導入し、既存版は保持します。KiCad 9.0系への制限はありません。GUI更新は初期セットアップと分離して実施します。
