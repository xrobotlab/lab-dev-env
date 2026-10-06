from __future__ import annotations

import importlib.metadata
import argparse
import fnmatch
import json
import os
import platform
import re
import shutil
import subprocess
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")
if os.name == "nt":
    try:
        import ctypes

        ctypes.windll.kernel32.SetConsoleOutputCP(65001)
    except Exception:
        pass

EXPECTED = {
    "mise": "2026.10.3",
    "python": "3.13.16",
    "node": "24.21.0",
    "uv": "0.12.23",
    "just": "1.58.0",
    "gh": "2.102.0",
    "platformio": "6.1.19",
    "dynamixel-sdk": "4.1.0",
}


def run(command: list[str], *, encoding: str = "utf-8") -> tuple[bool, str]:
    try:
        p = subprocess.run(command, check=False, text=True, capture_output=True,
                           encoding=encoding, errors="replace", timeout=15)
    except subprocess.TimeoutExpired:
        return False, "応答待ちが15秒を超えました"
    except OSError as exc:
        return False, str(exc)
    output = (p.stdout or p.stderr).strip().splitlines()
    return p.returncode == 0, output[0].strip() if output else f"終了コード {p.returncode}"


def status(ok: bool, name: str, detail: str) -> None:
    marker = "正常" if ok else "失敗"
    print(f"[{marker}] {name:<16} {detail}")


def windows_apps() -> list[dict[str, str]]:
    import winreg

    apps = []
    for hive in (winreg.HKEY_CURRENT_USER, winreg.HKEY_LOCAL_MACHINE):
        for view in (winreg.KEY_WOW64_64KEY, winreg.KEY_WOW64_32KEY):
            try:
                key = winreg.OpenKey(hive, r"Software\Microsoft\Windows\CurrentVersion\Uninstall",
                                     0, winreg.KEY_READ | view)
            except OSError:
                continue
            with key:
                for index in range(winreg.QueryInfoKey(key)[0]):
                    try:
                        with winreg.OpenKey(key, winreg.EnumKey(key, index)) as entry:
                            app = {}
                            for field in ("DisplayName", "DisplayVersion", "InstallLocation", "DisplayIcon"):
                                try:
                                    app[field] = str(winreg.QueryValueEx(entry, field)[0])
                                except OSError:
                                    pass
                            apps.append(app)
                    except OSError:
                        continue
    return apps


def gui_report() -> int:
    print("\nGUIアプリ（GIMP、KiCad、DYNAMIXEL Wizard 2）")
    manifest = json.loads((Path(__file__).resolve().parents[1] / "config/windows-apps.json").read_text(encoding="utf-8"))
    installed = windows_apps() if os.name == "nt" else []
    missing = 0
    for key, title, commands in (
        ("gimp", "GIMP", ("gimp", "gimp-3", "gimp-3.exe")),
        ("kicad", "KiCad", ("kicad", "kicad.exe")),
        ("dynamixelWizard", "DYNAMIXEL Wizard 2", ("DynamixelWizard2", "DynamixelWizard2.exe")),
    ):
        app = manifest[key]
        candidates = [Path(p) for command in commands if (p := shutil.which(command))]
        metadata = []
        if os.name == "nt":
            if key != "dynamixelWizard":
                candidates.append(Path(os.environ.get("LOCALAPPDATA", "")) / app["installDirectory"] / app["executable"])
            metadata = [a for a in installed if fnmatch.fnmatchcase(a.get("DisplayName", "").lower(), app["displayNamePattern"].lower())]
            for item in metadata:
                icon = re.sub(r",-?\d+$", "", item.get("DisplayIcon", "")).strip('"')
                if icon.lower().endswith(".exe") and "unins" not in Path(icon).name.lower():
                    candidates.append(Path(os.path.expandvars(icon)))
                if location := item.get("InstallLocation"):
                    root = Path(os.path.expandvars(location.strip('"')))
                    for command in commands:
                        candidates.extend((root / command, root / "bin" / command))
        if key == "dynamixelWizard":
            if custom := os.environ.get("DYNAMIXEL_WIZARD_PATH"):
                candidates.append(Path(custom).expanduser())
            roots = [Path.home() / "DYNAMIXEL Wizard 2.0", Path.home() / "DYNAMIXEL2Wizard"]
            if os.name == "nt":
                roots += [Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "DYNAMIXEL Wizard 2.0",
                          Path(os.environ.get("ProgramFiles", "")) / "ROBOTIS" / "DYNAMIXEL Wizard 2.0"]
            for root in roots:
                for command in commands:
                    candidates.extend((root / command, root / "bin" / command))
        found = next((p for p in candidates if p.is_file() and (
            p.suffix.lower() == ".exe" if os.name == "nt" else os.access(p, os.X_OK)
        )), None)
        if found:
            version = next((a.get("DisplayVersion", "") for a in metadata if a.get("DisplayVersion")), "")
            print(f"[検出] {title:<20} {found}" + (f" ({version})" if version else ""))
            if key != "dynamixelWizard":
                print(f"       Windows固定版: {app['version']}。検出は起動確認やバージョン一致の保証ではありません。")
        else:
            missing += 1
            print(f"[手動] {title:<20} 未検出。READMEの導入手順を確認してください。")
            if key == "dynamixelWizard":
                print(f"       {app['manualUrl']}（独自の場所へ導入した場合はDYNAMIXEL_WIZARD_PATHに実行ファイルを指定）")
    return missing


def docker_report() -> None:
    print("\nDocker（必要な研究でのみ使用。標準CLIの必須項目には含めません）")
    executable = shutil.which("docker")
    if executable is None and os.name == "nt":
        for root in (Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "DockerDesktop",
                     Path(os.environ.get("ProgramFiles", "")) / "Docker" / "Docker"):
            candidate = root / "resources" / "bin" / "docker.exe"
            if candidate.is_file():
                executable = str(candidate)
                break
    if executable:
        for label, arguments in (("Docker CLI", ["--version"]),
                                 ("Docker Compose", ["compose", "version"]),
                                 ("Docker Engine", ["version", "--format", "{{.Server.Version}}"] )):
            ok, detail = run([executable, *arguments])
            print(f"[{'検出' if ok else '手動'}] {label:<20} {detail}")
    else:
        print("[手動] Docker CLI           未導入。必要ならREADMEのDocker Desktop手順を確認してください。")
    if os.name == "nt":
        executable = shutil.which("wsl.exe")
        if executable:
            # wsl.exeのリダイレクト出力はUTF-16LE。日本語をUTF-8として解釈しない。
            ok, detail = run([executable, "--status"], encoding="utf-16-le")
            print(f"[情報] WSL状態              {'取得済み' if ok else '取得失敗'}: {detail}")
        print("       WSL 2 / 仮想化の準備には管理者の作業が必要な場合があります。自動変更しません。")


def serial_report() -> None:
    print("\nハードウェア / シリアル")
    ports: list[str] = []
    try:
        from serial.tools import list_ports  # type: ignore

        ports = [p.device for p in list_ports.comports()]
    except Exception:
        if os.name != "nt":
            ports = [str(p) for pat in ("ttyACM*", "ttyUSB*") for p in Path("/dev").glob(pat)]

    if not ports:
        print("[情報] シリアル機器     接続または検出された機器なし")
        return

    for port in ports:
        if os.name == "nt":
            print(f"[情報] シリアル機器     {port}")
        else:
            can_rw = os.access(port, os.R_OK | os.W_OK)
            status(can_rw, "シリアルアクセス", port)
            if not can_rw:
                print("       Linuxではudevルールまたはシリアルアクセス用グループ（例: dialout）への参加が必要な場合があります。")


def main() -> int:
    parser = argparse.ArgumentParser(description="標準CLI、GUI、Docker、シリアル機器を読み取り専用で診断")
    parser.add_argument("--require-gui", action="store_true", help="GUI未検出も失敗として扱う")
    args = parser.parse_args()
    print("XRobotLab lab-dev-env 環境診断")
    print(f"OS: {platform.platform()}")
    print(f"Python実行ファイル: {sys.executable}\n")

    failures = 0

    checks = [
        ("git", ["git", "--version"], None),
        ("gh", ["gh", "--version"], EXPECTED["gh"]),
        ("mise", ["mise", "--version"], EXPECTED["mise"]),
        ("python", [sys.executable, "--version"], EXPECTED["python"]),
        ("node", ["node", "--version"], EXPECTED["node"]),
        ("npm", ["npm", "--version"], None),
        ("uv", ["uv", "--version"], EXPECTED["uv"]),
        ("just", ["just", "--version"], EXPECTED["just"]),
        ("platformio", ["pio", "--version"], EXPECTED["platformio"]),
    ]

    for name, command, expected in checks:
        if command[0] == sys.executable:
            resolved_command = command
        else:
            executable = shutil.which(command[0])
            if executable is None:
                status(False, name, "見つかりません")
                failures += 1
                continue
            if os.name == "nt" and executable.lower().endswith((".cmd", ".bat")):
                resolved_command = [
                    os.environ.get("COMSPEC", "cmd.exe"),
                    "/d",
                    "/c",
                    executable,
                    *command[1:],
                ]
            else:
                resolved_command = [executable, *command[1:]]

        ok, detail = run(resolved_command)
        if expected is not None:
            ok = ok and expected in detail
            if not ok:
                detail = f"{detail}（想定: {expected}）"
        status(ok, name, detail)
        failures += int(not ok)

    try:
        dxl_version = importlib.metadata.version("dynamixel-sdk")
        ok = dxl_version == EXPECTED["dynamixel-sdk"]
        status(ok, "dynamixel-sdk", f"{dxl_version}（想定: {EXPECTED['dynamixel-sdk']}）")
        failures += int(not ok)
    except importlib.metadata.PackageNotFoundError:
        status(False, "dynamixel-sdk", "B3環境にインストールされていません")
        failures += 1

    serial_report()
    gui_missing = gui_report()
    docker_report()
    if args.require_gui:
        failures += gui_missing

    print()
    if failures:
        print(f"結果: 準備未完了（必須項目 {failures} 件で失敗）")
        return 1
    print("結果: 標準CLI準備完了" + (f"（GUI未検出 {gui_missing} 件。手動導入が必要）" if gui_missing else "（GUI検出済み）"))
    print("Docker / ドライバ / GUI起動・実機接続は上記診断と手動確認を参照してください。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
