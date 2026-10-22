# 標準ツールと固定バージョン

CLI・SDKの固定値の正本は `mise.toml`、`mise.lock`、`config/windows-apps.json`、`b3/uv.lock` です。この文書は人間向けの一覧です。

| ツール | バージョン | 管理 |
| --- | ---: | --- |
| mise | 2026.10.17 | bootstrap |
| Python | 3.13.17 | mise |
| Node.js | 24.22.1 LTS | mise |
| npm / npx | Node.js付属 | mise |
| uv | 0.13.4 | mise |
| just | 1.58.0 | mise |
| PlatformIO Core | 6.2.0 | mise |
| GitHub CLI (`gh`) | 2.102.1 | mise |
| DYNAMIXEL SDK（Python） | 4.1.0 | `b3/` のuv環境 |
| Git for Windows | 2.56.0.2 | Git未導入時のPortableGit |
| GIMP / KiCad / VS Code / Arduino IDE 2 / Bambu Studio | 固定なし | 標準GUI。導入方式は [共通一覧](../../config/gui-apps.json) と [GUI手順](../setup/gui-apps.md) |
| DYNAMIXEL Wizard 2 | 固定なし | 標準GUI。公式手動導入 |
| Autodesk Fusion / Docker | 固定なし | 任意。必要な場合だけ手動導入 |

## 更新時

固定バージョンを変更する場合は、lockファイルとCIを更新し、必要に応じて [導入根拠](installer-evidence.md) も更新してください。

GUIは現在の安定配布を導入し、既存版は保持します。KiCad 9.0系への制限はありません。GUI更新は初期セットアップと分離して実施します。

## 2026年10月の証明書依存更新

2026-10-22時点の公式情報を確認し、次を固定しました。Node 24.22.1 / npm 11.19.1 はPR #8で反映済みです。

| 対象 | 更新理由・公式根拠 |
| --- | --- |
| mise 2026.10.17 | [公式リリース](https://github.com/jdx/mise/releases/tag/v2026.10.17)にeMudhra CAの信頼削除を明記。bootstrap両OSとmise-actionも同期 |
| uv 0.13.4 | [GHSA-hq85-5cpj-mr62](https://github.com/astral-sh/uv/security/advisories/GHSA-hq85-5cpj-mr62)の修正版。既定の同梱CA束からemSignルートを削除 |
| Python 3.13.17 | [公式リリース](https://www.python.org/downloads/release/python-31317/)はpip 26.2.2 / 同梱certifi 2026.10.19への更新を説明。miseが使用する[standalone 20261021](https://github.com/astral-sh/python-build-standalone/releases/tag/20261021)の7 platformをURL/SHA256で固定 |
| gh 2.102.1 | [公式リリース](https://github.com/cli/cli/releases/tag/v2.102.1)のGo 1.27.3 / x/net 0.60.0更新。gh固有のCA脆弱性と断定しない |
| PlatformIO 6.2.0 | [公式リリース](https://github.com/platformio/platformio-core/releases/tag/v6.2.0)のZIP展開時の権限・時刻変更対策。Python最低版は3.9へ変更。CA更新自体は専用uv.lockのcertifi 2026.10.19以上で確認 |
| Homebrew ca-certificates | [公式formula](https://github.com/Homebrew/homebrew-core/blob/HEAD/Formula/c/ca-certificates.rb)は **2026-10-20** のCA束と除外処理。2026-10-19と混同しない。自動更新は追加しない |

Pythonのlock作成時、miseの版一覧がstandaloneの公開に追随していなかったため、Pythonセクションだけ公式release assetのURLとSHA256を照合して更新しました。`mise install --locked` はその配布物を使います。通常のlock再生成時もPythonが3.13.16へ戻っていないことを確認してください。

`just doctor` はこのリポジトリのB3/PlatformIO lock内のcertifi、および実行中Python環境に存在するcertifi/pipの古い版を失敗として報告します。PlatformIO lockのpipにはPython 3.9用の互換分岐が残りますが、標準Python 3.13では26.2.2を使用します。uv管理のB3 venvにpipやcertifiが無いことは正常です。macOSでHomebrewがある場合は、導入済みca-certificatesの日付も読み取り専用で確認し、古い場合は「手動」と表示します。Homebrew CAはbootstrapが更新しない外部管理項目のため、標準CLIの失敗件数には含めません。診断はOSの信頼ストアや独自CA束の安全性を保証しません。

公開依存の監査では、B3の2依存とWindowsの標準Python 3.13.17に選ばれたPlatformIO実環境22依存は既知の指摘なしでした。専用lock全分岐の `uv audit --frozen` はPython 3.9用の旧版（anyio、marshmallow、pip、requests、starlette、urllib3）に指摘を返します。標準環境で使う分岐とは区別し、全分岐の監査成功とは扱いません。Python 3.9でこのlockを流用することは対象外です。

### 既存PCでの手動更新・再同期

稼働中の研究、Tunnelなどが共通runtimeを使用していないことを管理者・利用者が確認し、停止や再起動が可能な時間に実施してください。このPR作業では既存PCへ適用しません。

1. 作業中の変更を保持したうえで、承認・mergeされたmainを既存cloneへ取り込みます。このDraftのbranchを研究室全体へ配布しません。
2. リポジトリの `bootstrap.cmd`（Windows）または `sh bootstrap.sh`（macOS/Linux）を通常ユーザーで明示的に再実行します。mise本体を更新し、固定CLIとB3を同期します。Windowsの既存GUIは保持し、macOSのHomebrew自動更新停止・既存版保持を維持します。LinuxのOSパッケージは変更しません。
3. 新しいターミナルでリポジトリへ移動し、`just setup`、`just versions`、`just b3-check`、`just doctor` を実行します。B3の `.python-version` は3.13.17です。既存venvが残る場合は `uv sync --locked --project b3 --python 3.13.17` を明示します。SDKは4.1.0を保持します。

macOSのHomebrewを使うPCでは、管理者・所有者が別作業としてformula metadataを `brew update` で更新し、`brew upgrade ca-certificates`（未導入なら `brew install ca-certificates`）を実行し、`brew list --versions ca-certificates` が2026-10-20以上であることを確認します。これは手動のCA bundle更新です。bootstrapの自動更新停止を解除したり、GUI全体のupgradeを実行したりしません。権限が必要なら中断して管理者に相談してください。

Python本体の更新だけでは、ほかの既存venvやプロジェクトの古いpip/certifi固定は直りません。使用者が各公開依存のlockを確認し、pipがあるvenvではPython公式リリースのハッシュ付きwheelによるpip更新手順を使って26.2.2以上へ更新します。独立したcertifi依存は2026.10.19以上へ更新・lock・再同期してください。研究用の私有lockは外部の監査サービスへ送信しません。

OS証明書ストア、SSL_CERT_FILE / SSL_CERT_DIRなどの独自CA設定、権限・資格情報・ネットワーク設定の変更はこの手順の対象外です。just、DYNAMIXEL SDK、GUIの一括更新も行いません。CI成功と実機への適用・GUI起動・機器通信は別の確認です。
