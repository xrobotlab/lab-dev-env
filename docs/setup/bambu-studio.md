# Bambu Studio

研究室の3Dプリンタを使用する場合の標準スライサーとしてBambu Studioを案内します。

研究室の3DプリンタはBambu Lab製で統一されているため、別のスライサーを選定する必要をなくし、プリンタ設定や操作方法を共有しやすくします。

## 導入対象

- Windows
- macOS
- Linux

## 導入

Bambu Lab公式のBambu Studioから、安定版のPublic Releaseを導入します。

- [Bambu Studio GitHub Releases](https://github.com/bambulab/BambuStudio/releases)

Windows / macOSは公式リリースの配布物を使用します。

Linuxは公式GitHub ReleasesのAppImage、またはBambu Studio公式リポジトリから案内されているFlathub版を利用できます。

## 用途

- 3Dモデルのスライス
- Bambu Labプリンタ向けの印刷設定
- G-codeの確認
- 対応環境でのプリンタ操作・監視

## lab-dev-envで自動導入しない理由

3Dプリンタを使用しない研究では不要であり、Bambu Studioは更新頻度も高いため、bootstrapで固定せず公式のPublic Releaseを手動導入します。
