# 標準ツールと固定バージョン

固定値の正本は `mise.toml`、`mise.lock`、`config/windows-apps.json`、`b3/uv.lock` です。この文書は人間向けの一覧です。

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
| GIMP | 3.2.6 | Windows GUIアプリ |
| KiCad | 9.0.9 | Windows GUIアプリ |
| DYNAMIXEL Wizard 2 | 固定なし | 手動導入 |

## 更新時

固定バージョンを変更する場合は、lockファイルとCIを更新し、必要に応じて [導入根拠](installer-evidence.md) も更新してください。
