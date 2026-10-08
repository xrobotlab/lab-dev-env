# Windowsセットアップ

対象はWindows 11 x64の通常ユーザーです。

## 1. リポジトリを取得

Gitがない場合はGitHubの **Code → Download ZIP** から取得し、ZIPを完全に展開します。

Gitがある場合:

```bat
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
```

## 2. bootstrapを実行

```bat
bootstrap.cmd
```

ZIP版は展開後の `bootstrap.cmd` を通常のダブルクリックで開きます。必要な配布ファイルを `%USERPROFILE%\source\lab-dev-env` へ検証付きでコピーし、配置先で通常権限のセットアップ画面を開きます。展開元は残します。既存の配置先は上書きせず停止するので、その中の `bootstrap.cmd` から再実行してください。Git作業コピーは履歴を保つため移動せず、その場所を使います。

`bootstrap.cmd` はGitがなければPortableGitをユーザー領域へ導入し、その後mise、標準CLI、B3共通Python環境を構築します。

GIMPとKiCadが未導入の場合は、SHA-256検証後に対話インストーラーが開きます。ユーザー単位の導入を選択してください。別ウィンドウのインストールが終わるまで、セットアップ画面は閉じないでください。完了画面ではアプリの起動を選ばずに閉じます。起動した場合は、そのアプリも閉じると処理が続きます。

「完了。この画面を閉じて構いません。」と表示されたらEnterキーで閉じます。失敗・キャンセル時はエラー表示が残るので、表示を控えて原因を解消してから配置先で再実行してください。

管理者権限を要求された場合は自動昇格せず、いったんキャンセルして研究室の管理者へ相談してください。

## 3. DYNAMIXEL Wizard 2を手動導入

DYNAMIXEL Wizard 2はbootstrapでは導入しません。

1. [ROBOTIS DYNAMIXEL Wizard 2 e-Manual](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)を開く
2. Windows X64版をダウンロードする
3. ダウンロードしたインストーラーを実行する
4. 画面の指示に従って導入する

## 4. 用途に応じて追加ソフトを導入

- 3D CADを行う場合: [Autodesk Fusion](fusion.md)
- 研究室の3Dプリンタを使用する場合: [Bambu Studio](bambu-studio.md)
- 論文ビルドコンテナなどでDockerを使用する場合: [Docker](docker.md)

## 5. 確認

新しく通常のPowerShellを開き、ZIP版では次で配置先へ移動します。Git作業コピーは実際の取得場所へ移動してください。

```powershell
cd "$HOME\source\lab-dev-env"
```

```bat
just doctor-full
```

`just doctor-full` でGIMP、KiCad、DYNAMIXEL Wizard 2まで検出されることを確認します。

## ZIPから開始した場合

ZIP展開ディレクトリ自体はGitリポジトリへ変換されません。GitHub組織への参加後、開発用にはあらためて `git clone` してください。
