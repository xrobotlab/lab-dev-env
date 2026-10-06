from __future__ import annotations

import importlib.metadata
import os
import platform
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
    "platformio": "6.1.19",
    "dynamixel-sdk": "4.1.0",
}


def run(command: list[str]) -> tuple[bool, str]:
    try:
        p = subprocess.run(command, check=False, text=True, capture_output=True)
    except OSError as exc:
        return False, str(exc)
    output = (p.stdout or p.stderr).strip().splitlines()
    return p.returncode == 0, output[0].strip() if output else f"終了コード {p.returncode}"


def status(ok: bool, name: str, detail: str) -> None:
    marker = "正常" if ok else "失敗"
    print(f"[{marker}] {name:<16} {detail}")


def version_contains(command: list[str], expected: str) -> tuple[bool, str]:
    ok, detail = run(command)
    return ok and expected in detail, detail


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
    print("XRobotLab lab-dev-env 環境診断")
    print(f"OS: {platform.platform()}")
    print(f"Python実行ファイル: {sys.executable}\n")

    failures = 0

    checks = [
        ("git", ["git", "--version"], None),
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

    print()
    if failures:
        print(f"結果: 準備未完了（必須項目 {failures} 件で失敗）")
        return 1
    print("結果: 準備完了")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
