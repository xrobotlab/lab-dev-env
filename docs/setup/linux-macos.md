# Linux / macOSセットアップ

Linux / macOSではGitを事前に用意します。

```sh
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
./bootstrap.sh
```

`bootstrap.sh` はmiseをユーザー領域へ導入し、標準CLIとB3共通Python環境を構築します。

`sudo` やrootでは実行しないでください。

## GUIアプリ

GIMP、KiCad、DYNAMIXEL Wizard 2はOS別の公式配布から導入します。詳細は [GUIアプリ](gui-apps.md) を参照してください。

## シリアル・USBアクセス

LinuxではDYNAMIXELやUSBシリアル機器へのアクセスに `dialout` グループなどのOS側設定が必要になる場合があります。

これらの管理者操作はbootstrapから実行しません。必要な場合は研究室の管理者が設定してください。

## 確認

```sh
just doctor
just doctor-full
```
