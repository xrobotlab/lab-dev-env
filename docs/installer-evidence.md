# 標準アプリの導入根拠

確認日: 2026-10-07。固定値は `config/windows-apps.json` と `mise.lock` を参照してください。以下の資料確認と、インストーラの実行試験は別です。

## Git / GitHub CLI

- [Git for Windows 2.56.0.windows.2公式リリース](https://github.com/git-for-windows/git/releases/tag/v2.56.0.windows.2)にPortableGit x64のファイル名とSHA-256が掲載されています。作成途中の設定の値と一致しました。
- [公式の展開手順](https://gitforwindows.org/zip-archives-extracting-the-released-archives.html)が `-y -gm2 -InstallPath="…"` を文書化しています。指定するWindowsパスのバックスラッシュは二重にします。ユーザー領域へ展開し、GitがないPCでもZIP取得から始められます。
- [mise公式レジストリ](https://mise.jdx.dev/registry.html)にGitHub CLIの `aqua:cli/cli` バックエンドがあります。gh 2.102.0のWindows / Linux / macOS用アーカイブとSHA-256は[公式リリースの配布物一覧](https://github.com/cli/cli/releases/expanded_assets/v2.102.0)と照合できます。導入は認証・組織参加とは別です。

## GIMP

- [公式ダウンロードページ](https://www.gimp.org/downloads/)では現行安定版は3.2.6。Windows x64 / ARM64対応の `gimp-3.2.6-setup.exe` とSHA-256が掲載されています。設定のURL・ハッシュと一致しました。
- [3.2.6タグの公式インストーラソース](https://raw.githubusercontent.com/GNOME/gimp/GIMP_3_2_6/build/windows/installer/gimp-setup.iss)はInno Setup 6を使用し、`PrivilegesRequired=lowest`、`PrivilegesRequiredOverridesAllowed=dialog` を指定しています。既定の導入先は安定版では `GIMP 3` です。
- [公式ビルド定義](https://github.com/GNOME/gimp/blob/GIMP_3_2_6/meson.build)は実行ファイル名をメジャー・マイナーバージョンから生成するため、3.2系の実行ファイルは `gimp-3.2.exe` として扱います。
- [Inno Setupの公式オプション](https://jrsoftware.org/ishelp/topic_setupcmdline.htm)は `/CURRENTUSER` などを説明しています。[`dialog` の仕様](https://jrsoftware.org/ishelp/topic_setup_privilegesrequiredoverridesallowed.htm)は `commandline` の上書きも許可します。今回の実装は `/CURRENTUSER` のみ指定し、無人導入用の引数は使わず対話画面で導入します。

## KiCad

- [公式Windowsダウンロードページ](https://www.kicad.org/download/windows/)の現行安定版は10.0.6です。今回の固定候補9.0.9は最新とは呼びません。[9.0.9公式配布物一覧](https://github.com/KiCad/kicad-source-mirror/releases/expanded_assets/9.0.9)のx64版URL・SHA-256は設定の値と一致しました。
- [公式パッケージ作成ソース](https://gitlab.com/kicad/packaging/kicad-win-builder/-/raw/master/nsis/install-8-9-10.nsi)はNSIS 3を使用します。[同梱MultiUser実装](https://gitlab.com/kicad/packaging/kicad-win-builder/-/raw/master/nsis/includes/NsisMultiUser.nsh)は `RequestExecutionLevel user` とユーザー単位導入を定義しています。
- [公式プロジェクトの保守担当者の回答](https://gitlab.com/kicad/packaging/kicad-win-builder/-/work_items/135)は `/S` に `/allusers` または `/currentuser` の併用が必要としています。今回の実装は `/S` を外し、ユーザー単位を指定する `/currentuser` のみ使って対話導入します。ただしソース・回答の確認は、固定した9.0.9実ファイルの実行試験を代替しません。
- 同パッケージソースには、条件に応じてVisual C++ Runtimeを導入する処理もあります。アプリ本体のユーザー単位導入とは別に、前提コンポーネントの管理者作業が必要な場合があります。権限要求は自動承認しません。

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
