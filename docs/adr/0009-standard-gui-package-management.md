# ADR 0009: 標準GUIを共通一覧とOS別パッケージ管理で導入する

- 状態: 採用
- 日付: 2026-10-08

## 決定

GIMP、KiCad、VS Code、Arduino IDE 2、Bambu Studio、DYNAMIXEL Wizard 2を標準GUIとし、DockerとAutodesk Fusionだけを任意にします。[共通一覧](../../config/gui-apps.json) をbootstrapとdoctorで共有します。

GUIの版は固定しません。KiCad 9.0系の制限も解除します。既存版は保持し、初期セットアップは不足分だけを導入します。CLI・PortableGit・Python SDKの固定管理は従来どおりです。

Windowsはwingetの正確なID、source、user scope、installer typeを指定します。GIMP・KiCad・VS Codeは対話式、Arduino IDE 2・Bambu Studioはportable形式だけを許可します。適用できない場合にmachine scopeへ戻しません。

macOSは準備済みHomebrewの制御機能を確認し、対応するcaskをユーザーのApplicationsへ導入します。pkg・導入スクリプト・共有領域artifactを含む定義は自動実行しません。Homebrew自体は初期導入しません。KiCadとWizardは公式手動手順へ誘導します。Linuxも公式手動手順を使用します。

Windowsのユーザーportable版Bambu Studio・Arduino IDE 2には、ユーザー用スタートメニューの不足したショートカットを新規導入後と再実行時に補完します。実行先と作業フォルダーを確認し、既存リンク・同名ファイルを保持します。デスクトップへ追加しません。

通常権限の境界、Windowsの自動配置と結果画面を維持します。未対応項目も標準対象に残し、手動確認が残る状態は完了にしません。doctor-fullは6本を検出します。GUI起動・ドライバ・実機通信は別途確認します。

## 検証と制約

隔離したfixtureで選択・待機・既存導入保持・失敗・手動未完了を検証します。実アプリの導入や起動は実施済みとは扱いません。Windows/macOSの実インストーラー受入試験を別途行い、パッケージ定義が通常権限で使えない場合は公式手順へ戻します。
