# Windows検証範囲

`lab-dev-env` のWindows初期構築について、CIで自動確認する範囲と実機で確認する範囲を分けます。

## 自動検証

GitHub Actionsの `Windowsクリーンbootstrap` ジョブでは、GitHub-hosted Windows Runner上に次の隔離環境を作ります。

- `.git` を持たないDownload ZIP相当の作業ディレクトリ
- Git / gh / mise / Python / Node.js / npm / uv / just / PlatformIOをPATHから除外した開始状態
- Runner本来の `%LOCALAPPDATA%` を使わない一時ユーザー領域
- GUIインストーラーだけを省略するCI専用モード

この状態からbootstrap本体を直接実行し、次を確認します。

1. PortableGitをダウンロードし、SHA-256検証後にユーザー領域へ展開できる
2. miseをダウンロードし、固定済みのCLIを `mise.lock` に従って導入できる
3. B3共通uv環境とDYNAMIXEL SDKを構築できる
4. ユーザーPATHへGit / miseの経路を保存できる
5. 新しいターミナル相当のPATHで固定版の各CLIを利用できる
6. `just doctor` が成功する
7. bootstrap本体を2回目に実行しても成功する
8. 2回目の実行後も `just doctor` が成功する

テスト終了後はユーザーPATHを元へ戻し、一時領域を削除します。

## 通常のWindows CI

通常のWindowsジョブでは、PowerShell構文、ダウンロード・ハッシュ検証関数、固定版ツール、B3環境、doctorの単体テストも別に確認します。

## 自動検証に含めないもの

次はGitHub Actionsでは実際に導入・操作しません。

- GIMPの対話インストールとGUI起動
- KiCad / VS Codeの対話インストールとGUI起動
- Arduino IDE 2 / Bambu Studioのwinget portable導入とGUI起動
- DYNAMIXEL Wizard 2の手動インストールとGUI起動
- USB / シリアル機器との実接続
- ドライバ導入
- Docker Desktop / WSL 2の初回OS設定
- Autodesk Fusionの手動導入

これらは使い捨てWindowsまたは実機での受入試験対象です。

## Windows Sandboxでの受入試験

Windows 11 Pro / Enterprise / EducationでWindows Sandboxが利用できる場合は、ホスト環境を汚さずに最終確認できます。

受入試験ではSandbox内で次を順番に実施します。

1. Gitがない状態でGitHubからZIPを取得する
2. ZIPを展開して `bootstrap.cmd` を実行する
3. GIMP・KiCad・VS Codeを対話インストールし、Arduino IDE 2・Bambu Studioのportable配置を確認する
4. DYNAMIXEL Wizard 2を公式手順で導入する
5. ターミナルを開き直す
6. `just doctor-full` を実行する
7. `bootstrap.cmd` を再実行して冪等性を確認する

Sandbox終了時に内部状態が破棄されるため、ホストPCの既存開発環境とは分離して試験できます。

## 今回の検証と残る受入試験

Windows / Linux / macOSのCIは固定CLI・SDKと、GUI導入をmockに置き換えた単体テストを検証します。Windowsの配置・結果画面・子孫待機は無害なfixtureで確認します。実物のwingetインストーラー、Homebrew caskの導入、GUI起動、実機通信はCIで実施しません。

macOSの受入試験は、通常ユーザーと準備済みHomebrewでGIMP・VS Code・Arduino IDE 2・Bambu Studioが ~/Applications に導入されること、KiCadとWizardが手動案内されることを確認します。Homebrew未準備・古い制御機能・管理者要求・既存の異なる版・導入済みcaskの独自配置・キャンセル・取得失敗も確認します。再実行で既存アプリが更新・重複導入されないことを確認します。

Windows Sandboxはwingetが標準で入っていない場合があります。winget自体の準備はbootstrapの対象外です。未準備ではGUI公式手動手順が表示されることを確認し、winget導入経路の受入試験は準備済みの使い捨て環境で実施します。資料・fixtureの検証結果を実物の導入成功として扱いません。
