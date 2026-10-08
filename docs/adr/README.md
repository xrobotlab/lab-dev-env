# ADR

`lab-dev-env` の重要な設計判断をArchitecture Decision Recordとして記録します。

| ADR | 状態 | 内容 |
| --- | --- | --- |
| [0001](0001-public-bootstrap-repository.md) | 採用 | 初期構築リポジトリをPublicにする |
| [0002](0002-toolchain-and-project-dependencies.md) | 採用 | 共通ツールと研究固有依存関係を分離する |
| [0003](0003-user-privilege-boundary.md) | 採用 | 通常セットアップをユーザー権限に限定する |
| [0004](0004-dynamixel-wizard-manual-installation.md) | 採用 | DYNAMIXEL Wizard 2を手動導入とする |
| [0005](0005-docker-outside-default-bootstrap.md) | 採用 | Dockerを標準自動導入から分離する |
| [0006](0006-standardize-kicad.md) | 採用 | PCB設計ツールとしてKiCadを研究室標準にする |
| [0007](0007-standardize-fusion.md) | 採用 | 3D CADの標準案内をAutodesk Fusionとする |
| [0008](0008-standardize-bambu-studio.md) | 採用 | 3Dプリンタ用スライサーの標準案内をBambu Studioとする |

## 形式

各ADRは背景、決定、結果を記録します。決定を変更する場合は既存ADRを書き換えて履歴を消すのではなく、新しいADRで置き換えます。

- [0009: 標準GUIの共通一覧とパッケージ管理](0009-standard-gui-package-management.md)
