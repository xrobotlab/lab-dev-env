# Windowsセットアップ

対象はWindows 11 x64の通常ユーザーです。

## Gitがない場合

GitHubのリポジトリ画面から **Code → Download ZIP** を選び、ZIPを完全に展開します。

展開したディレクトリで次を実行します。

```bat
bootstrap.cmd
```

`bootstrap.cmd` はPowerShellの実行ポリシーを変更せず、UTF-8の `scripts/bootstrap.ps1` を実行します。

GitがPATHにない場合は、固定版PortableGitをSHA-256検証後にユーザー領域へ展開します。その後、miseと標準CLI、B3共通Python環境を構築します。

## Gitがある場合

```bat
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
bootstrap.cmd
```

## GUIアプリ

GIMPとKiCadはセットアップ中に対話インストーラーを起動します。ユーザー単位の導入を選択してください。

管理者権限を要求された場合は自動昇格せず、いったんキャンセルして研究室の管理者へ相談してください。

DYNAMIXEL Wizard 2は自動導入対象ではありません。詳細は [GUIアプリ](gui-apps.md) を参照してください。

## 確認

```bat
just doctor
just doctor-full
```

`just doctor` は標準CLIを必須判定します。`just doctor-full` はGIMP、KiCad、DYNAMIXEL Wizard 2の未検出も失敗として扱います。

## 注意

ZIPから開始した場合、その展開ディレクトリ自体をGitリポジトリへ変換したりGitHubへログインしたりはしません。GitHub組織への参加後、開発用にはあらためて `git clone` してください。
