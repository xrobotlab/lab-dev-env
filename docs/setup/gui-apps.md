# 標準GUIアプリ

標準対象はGIMP、KiCad、VS Code、Arduino IDE 2、Bambu Studio、DYNAMIXEL Wizard 2の6本です。任意対象はDockerとAutodesk Fusionだけです。対象と検出・導入の設定は [共通一覧](../../config/gui-apps.json) を正本とします。GUIの版は固定せず、既存アプリを保持します。

| 対象 | Windows 11 x64 | macOS | Linux |
| --- | --- | --- | --- |
| GIMP / VS Code | wingetのuser-scope Inno対話導入 | 既存Homebrewからユーザー領域へ | 公式手動導入 |
| KiCad | wingetのuser-scope NSIS対話導入 | 公式手動導入 | 公式手動導入 |
| Arduino IDE 2 / Bambu Studio | wingetのuser-scope portableに限定 | 既存Homebrewからユーザー領域へ | 公式手動導入 |
| DYNAMIXEL Wizard 2 | 公式手動導入 | 公式手動導入 | 公式手動導入 |

不足分の導入はbootstrapが呼び出します。CLI導入後に再試行する場合はリポジトリのルートで `just gui-setup` を実行します。終了コード0は全6本検出、2は未対応経路などの公式手動確認が残る状態、1は導入失敗です。wingetの適用不可・取得失敗も1となり、公式手順を併記します。キャンセル・取得エラー・終了コード0でも実行ファイル未検出の場合は成功にしません。

Windowsは正確なpackage ID・winget source・user scope・installer typeを指定し、machineや別形式へ切り替えません。パッケージが適用できないときは上の公式手順を案内します。アプリが管理者権限を要求したらキャンセルし、研究室の管理者へ相談してください。

macOSは既存のHomebrewに昇格禁止・既存版の更新禁止・自動更新禁止・cleanup禁止を設定します。`brew config` でこれらを認識することを確認し、caskの現在の定義にpkg・導入スクリプト・共有領域artifact等がない場合だけ `~/Applications` へ導入します。`--no-binaries` を付け、追加CLIリンクを作りません。Homebrew自体の初期導入は管理者作業が必要になるため、未準備の場合は公式配布元を使います。KiCadのcaskは共有領域artifactを含むため自動導入しません。Gatekeeperやquarantineは変更しません。

公式配布元は [README](../../README.md#標準guiの公式配布元) と [導入根拠](../reference/installer-evidence.md) を参照してください。

## 検出と完了確認

`just doctor-full` は6本の実行ファイルを読み取り専用で検出します。登録だけ存在して実行ファイルが見つからない場合は自動再導入せず、既存の導入先・修復を確認します。検出はGUI起動・実機通信の成功を保証しません。macOSは `/Applications` と `~/Applications` のapp bundle、Windowsは登録情報・標準位置・PATH、LinuxはPATHを調べます。

AppImageや独自の場所への導入が未検出なら、現在のターミナルで次の変数に実行ファイルの絶対パスを指定できます。システム環境変数を変更する必要はありません。

| 対象 | 変数 |
| --- | --- |
| GIMP | `LAB_GUI_GIMP_PATH` |
| KiCad | `LAB_GUI_KICAD_PATH` |
| VS Code | `LAB_GUI_VSCODE_PATH` |
| Arduino IDE 2 | `LAB_GUI_ARDUINO_PATH` |
| Bambu Studio | `LAB_GUI_BAMBU_PATH` |
| DYNAMIXEL Wizard 2 | `DYNAMIXEL_WIZARD_PATH` |

更新はbootstrapと分離し、利用者が各アプリ・パッケージ管理ツールの更新手順を選んで実行します。bootstrapはupgrade・uninstall・強制再導入を実行しません。
