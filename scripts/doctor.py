from __future__ import annotations

import importlib.metadata
import argparse
import os
import platform
import re
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

import gui_tools

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
    "mise": "2026.10.17",
    "python": "3.13.17",
    "node": "24.22.1",
    "uv": "0.13.4",
    "just": "1.58.0",
    "gh": "2.102.1",
    "platformio": "6.2.0",
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


def gui_report() -> int:
    return gui_tools.report()


def certificate_report() -> int:
    """公開の管理対象lockと実行中venvだけを確認する（通信・更新なし）。"""
    print("\n証明書依存（OSの信頼ストア・独自CA設定は手動確認）")
    failures = 0
    minimums = {"certifi": (2026, 10, 19), "pip": (26, 2, 2)}

    def check(name: str, version: str, location: str) -> None:
        nonlocal failures
        parts = version.split(".")
        ok = len(parts) >= 3 and all(part.isdigit() for part in parts)
        ok = ok and tuple(map(int, parts)) >= minimums[name]
        status(ok, name, f"{version} ({location}; 最低 {'.'.join(map(str, minimums[name]))})")
        failures += int(not ok)

    root = Path(__file__).resolve().parents[1]
    locks = [root / "b3/uv.lock",
             root / f".mise/locks/pypi-platformio/{EXPECTED['platformio']}/uv.lock"]
    for path in locks:
        try:
            packages = tomllib.loads(path.read_text(encoding="utf-8"))["package"]
            for package in packages:
                # pipにはPython 3.9用の互換分岐もあるため、実行環境側で確認する。
                if package["name"] == "certifi":
                    check(package["name"], package["version"], str(path.relative_to(root)))
            if path == locks[1] and not any(p["name"] == "certifi" for p in packages):
                raise ValueError("PlatformIO lockにcertifiがありません")
        except (OSError, ValueError, KeyError) as exc:
            status(False, "証明書lock", f"{path.relative_to(root)}: {exc}")
            failures += 1

    for name in minimums:
        try:
            check(name, importlib.metadata.version(name), "実行中Python環境")
        except importlib.metadata.PackageNotFoundError:
            print(f"[情報] {name:<16} 実行中Python環境に未導入（uv管理venvでは正常）")

    if sys.platform == "darwin" and (brew := shutil.which("brew")):
        ok, detail = run([brew, "list", "--versions", "ca-certificates"])
        if ok and detail:
            match = re.search(r"\b(\d{4})[-.](\d{2})[-.](\d{2})(?!\d)", detail)
            current = tuple(map(int, match.groups())) if match else ()
            ok = current >= (2026, 10, 20)
            # bootstrapが更新しない外部管理項目。古さは表示し、標準CLIとは分ける。
            print(f"[{'正常' if ok else '手動'}] brew CA          {detail}（最低 2026-10-20; 更新は手動）")
        else:
            print("[情報] brew CA          未導入または取得不可。使用する場合は手動確認")
    return failures


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

    failures += certificate_report()
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
