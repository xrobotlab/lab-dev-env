# Linuxセットアップ

`bootstrap.sh` はCLIとB3共通Python環境を構築します。

GUIアプリは自動導入されないため、GIMP、KiCad、DYNAMIXEL Wizard 2を続けて手動導入します。

## 1. リポジトリを取得してbootstrapを実行

```sh
git clone https://github.com/xrobotlab/lab-dev-env.git
cd lab-dev-env
./bootstrap.sh
```

`sudo` やrootでは実行しないでください。

## 2. GIMPを導入

[GIMP公式Downloads](https://www.gimp.org/downloads/)からLinux版を導入します。

Flatpakを利用できる場合は、公式案内のユーザー単位導入を使用できます。

```sh
flatpak install --user https://flathub.org/repo/appstream/org.gimp.GIMP.flatpakref
```

Flatpakを使わない場合は、公式AppImageまたは利用ディストリビューション向けの公式案内を使用してください。

## 3. KiCad 9.0系を導入

研究室内でPCB設計ツールを統一するため、KiCad 9.0系を標準として使用します。

UbuntuではKiCad公式の9.0 releases PPAを使用します。

```sh
sudo add-apt-repository --yes ppa:kicad/kicad-9.0-releases
sudo apt update
sudo apt install --install-recommends kicad
```

Ubuntu以外は [KiCad公式Linux Downloads](https://www.kicad.org/download/arch-linux/) を参照し、9.0系を導入してください。

## 4. DYNAMIXEL Wizard 2を導入

1. [ROBOTIS DYNAMIXEL Wizard 2 e-Manual](https://emanual.robotis.com/docs/en/software/dynamixel/dynamixel_wizard2/)から、CPUアーキテクチャに合うLinux版をダウンロードする
2. インストーラーに実行権限を付与する
3. インストーラーを起動し、画面の指示に従う

例:

```sh
chmod u+x DynamixelWizard2Setup_x64
./DynamixelWizard2Setup_x64
```

## 5. DYNAMIXEL / USBシリアルのアクセス権を設定

DYNAMIXEL Wizard 2をUSB機器と使用する場合、ROBOTIS公式手順では利用者を `dialout` グループへ追加し、再起動します。

管理者に次の設定を依頼してください。

```sh
sudo usermod -aG dialout "$USER"
```

設定後に再起動します。

## 6. 用途に応じて追加ソフトを導入

- 研究室の3Dプリンタを使用する場合: [Bambu Studio](bambu-studio.md)
- 論文ビルドコンテナなどでDockerを使用する場合: [Docker](docker.md)

Autodesk FusionはLinuxへ直接インストールできないため、3D CADでFusionを使用する場合は [Fusionの導入案内](fusion.md) を確認してください。

## 7. 確認

```sh
just doctor-full
```

GIMP、KiCad、DYNAMIXEL Wizard 2と、接続しているシリアル機器へのアクセスを確認します。
