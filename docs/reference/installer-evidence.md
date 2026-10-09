# 標準アプリの導入根拠

確認日: 2026-10-07。固定値は `config/windows-apps.json` と `mise.lock` を参照してください。以下の資料確認と、インストーラの実行試験は別です。

## Git / GitHub CLI

- [Git for Windows 2.56.0.windows.2公式リリース](https://github.com/git-for-windows/git/releases/tag/v2.56.0.windows.2)にPortableGit x64のファイル名とSHA-256が掲載されています。`config/windows-apps.json` の固定値と一致しています。
- [公式の展開手順](https://gitforwindows.org/zip-archives-extracting-the-released-archives.html)は自己展開アーカイブの `-y -gm2` を文書化しています。[現行PortableGit生成スクリプト](https://github.com/git-for-windows/build-extra/blob/main/portable/release.sh)では、既定展開先をアーカイブと同じ場所の `PortableGit` とし、展開後に `post-install.bat` を実行します。bootstrapは一時領域へこの既定方式で展開し、`cmd/git.exe` を確認してからユーザー領域へ移動します。
- [mise公式レジストリ](https://mise.jdx.dev/registry.html)にGitHub CLIの `aqua:cli/cli` バックエンドがあります。gh 2.102.0のWindows / Linux / macOS用アーカイブとSHA-256は[公式リリースの配布物一覧](https://github.com/cli/cli/releases/expanded_assets/v2.102.0)と照合できます。導入は認証・組織参加とは別です。

## 標準GUIのパッケージ管理

確認日: 2026-10-08。GUIの版・SHA-256はリポジトリで固定しません。配布元の現在の定義をパッケージ管理ツールが検証します。資料・fixtureの確認は実アプリ導入試験とは別です。

Windowsの現在の公式winget定義を確認しました。

| ID | 確認した配布形式 | bootstrapの選択 |
| --- | --- | --- |
| [GIMP.GIMP.3](https://github.com/microsoft/winget-pkgs/tree/master/manifests/g/GIMP/GIMP/3) | Inno、user / machine | user、inno、対話式 |
| [KiCad.KiCad](https://github.com/microsoft/winget-pkgs/tree/master/manifests/k/KiCad/KiCad) | NSIS、user / machine | user、nullsoft、対話式 |
| [Microsoft.VisualStudioCode](https://github.com/microsoft/winget-pkgs/tree/master/manifests/m/Microsoft/VisualStudioCode) | Inno、user / machine | user、inno、対話式 |
| [ArduinoSA.IDE.stable](https://github.com/microsoft/winget-pkgs/tree/master/manifests/a/ArduinoSA/IDE/stable) | ZIP + nested portable、scope未記載 / NSIS / machine MSI | user、portable限定 |
| [Bambulab.Bambustudio](https://github.com/microsoft/winget-pkgs/tree/master/manifests/b/Bambulab/Bambustudio) | machine NSIS / ZIP + nested portable、scope未記載 | user、portable限定 |

[winget公式install仕様](https://learn.microsoft.com/en-us/windows/package-manager/winget/install)のexact・source・scope・installer-type・no-upgradeを指定します。Portableは[公式選択処理](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCommonCore/Manifest/ManifestComparator.cpp)でscope未記載でもuser指定を受理し、[配置処理](https://github.com/microsoft/winget-cli/blob/master/src/AppInstallerCLICore/Workflows/PortableFlow.cpp)がユーザー領域へ周辺ファイルも配置します。適用不能・取得エラーでmachineやEXEへ条件を緩めません。

KiCadは本体がユーザー単位でも、[公式パッケージソース](https://gitlab.com/kicad/packaging/kicad-win-builder/-/raw/master/nsis/install-8-9-10.nsi)にVisual C++ Runtimeの前提導入があります。権限要求はキャンセルして管理者へ相談します。依存パッケージの自動導入はskip-dependenciesで抑止しますが、インストーラー自身の要求を保証するものではありません。

macOSの現在の公式cask: [GIMP](https://github.com/Homebrew/homebrew-cask/blob/main/Casks/g/gimp.rb)、[VS Code](https://github.com/Homebrew/homebrew-cask/blob/main/Casks/v/visual-studio-code.rb)、[Arduino IDE](https://github.com/Homebrew/homebrew-cask/blob/main/Casks/a/arduino-ide.rb)、[Bambu Studio](https://github.com/Homebrew/homebrew-cask/blob/main/Casks/b/bambu-studio.rb)はapp配置に対応します。[KiCad](https://github.com/Homebrew/homebrew-cask/blob/main/Casks/k/kicad.rb)は共有 /Library artifactを含むので手動扱いです。

[Homebrew公式manpage](https://docs.brew.sh/Manpage)のNO_SUDO、NO_INSTALL_UPGRADE、NO_AUTO_UPDATE、NO_INSTALL_CLEANUPをプロセス単位で設定し、[公式SystemConfig](https://github.com/Homebrew/brew/blob/main/Library/Homebrew/system_config.rb)によるbrew config出力で認識を確認します。既存brewの制御が使えない場合は手動導入へ戻します。公式caskに限定し、pkg・導入script・共有artifact・追加formula/cask依存を検査して除外します。appdirは ~/Applications、no-binariesで追加リンクを避けます。Homebrewの初期導入、sudo、quarantine解除は行いません。

## インストーラーの待機

Windowsは[PowerShell 5.1 Start-Process](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.management/start-process?view=powershell-5.1)のWaitでwingetとその子孫の終了を待ちます。待機するアプリ名とターミナルを閉じない案内を起動前に表示し、終了コードと実行ファイルを再確認します。既存アプリの版は比較・更新しません。終了コード0でも未検出なら成功にはしません。

## DYNAMIXEL Wizard 2

- [ROBOTIS公式e-Manual](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)はWindows 10 / 11（64 bit）、Ubuntu 22.04 / 24.04（64 bit）を対応OSとして案内しています。Windows x64、Linux x64、Linux ARM64のリンクがあり、ARM64についてJetson AGX Orin / Raspberry Pi 5への言及があります。
- 公式の配布入口: [Windows x64](https://www.robotis.com/service/download.php?no=1670)、[Linux x64](https://www.robotis.com/service/download.php?no=1671)、[Linux ARM64](https://www.robotis.com/service/download.php?no=2233)。これらは版付き実ファイルURLではありません。
- [公式ダウンロード一覧](https://en.robotis.com/service/downloadpage.php?ca_id=10)はWizardのWindows版をexeと表記しています。同ページのportable ZIP化の告知はR+ソフトウェアについての告知で、Wizardの形式の根拠には使いません。
- e-ManualのWindows手順はインストーラ起動後にNextを押す対話式です。Linuxも `DynamixelWizard2Setup_x64` に実行権限を付けて起動後、GUI操作を行う手順です。exe / Linux実行ファイルという情報だけでは、MSI / NSIS / Inno Setup / Qt Installer Frameworkなどの内部形式は確定できません。
- この実行環境から実ファイルを取得できず、内部形式、版、固定版URL、SHA-256、ヘルプ・`strings`、無人導入用引数を確定できませんでした。`/S`、`/silent`、`/VERYSILENT`、MSI用引数を推測で指定しません。
- SHA-256未確定のため、今回は公式配布URLへの誘導とdoctorによる検出を採用します。自動ダウンロード・起動は行いません。版付き配布物とハッシュを確認できた場合だけ、検証後に対話起動する方式を追加できます。
- LinuxのUSBアクセスは公式手順の `sudo usermod -aG dialout <your_account_id>` と再起動で設定します。これは管理者作業として通常セットアップと分離します。本人が所有するダウンロードファイルの実行権限変更には通常 `chmod u+x` で足り、インストーラ自体をsudoで起動する必要はありません。追加のudevルールを独自に生成・適用しません。

## Docker

今回の標準自動導入には含めず、論文ビルドコンテナを使う研究で別途準備する方針です。

- [公式ライセンス説明](https://docs.docker.com/subscription-billing/desktop-license/)は教育利用を無料対象に含めています。有料対象には大規模組織の業務利用、政府機関などがあり、研究室という呼称だけで全用途の適用を確定しません。実際の利用目的・所属組織と契約を確認します。
- [現行Windows導入資料](https://docs.docker.com/desktop/setup/install/windows-install/)にはユーザー単位の `install --user`（管理者権限不要）と全ユーザー導入（管理者権限必要）の両方があります。Docker Desktopの導入が常に管理者権限必須とは扱いません。
- 同資料はWSL 2初回有効化には管理者権限が必要と明記し、WSL 2.1.5以上や仮想化などを要件として挙げています。利用条件、OS側の準備、研究用コンテナの動作確認を一律bootstrapから分離します。
