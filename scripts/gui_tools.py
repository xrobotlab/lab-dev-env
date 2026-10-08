"""標準GUIの読み取り専用検出と、不足分の通常権限での導入。"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import fnmatch
import glob
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def inventory() -> list[dict]:
    return json.loads((ROOT / "config/gui-apps.json").read_text(encoding="utf-8"))["standard"]


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


@dataclass
class Detection:
    path: Path | None = None
    registered: bool = False
    version: str = ""


def executable(path: Path, system: str) -> bool:
    if not path.is_file():
        return False
    return path.suffix.lower() in (".exe", ".cmd", ".bat") if system == "Windows" else os.access(path, os.X_OK)


def bundle_executable(bundle: Path) -> Path | None:
    try:
        with (bundle / "Contents/Info.plist").open("rb") as handle:
            name = plistlib.load(handle).get("CFBundleExecutable", "")
        # Info.plist is metadata, not a path authority.
        if not name or Path(name).name != name:
            return None
        candidate = bundle / "Contents/MacOS" / name
        return candidate if executable(candidate, "Darwin") else None
    except (OSError, TypeError, ValueError, plistlib.InvalidFileException):
        return None


def detect(app: dict, system: str, installed: list[dict] | None = None) -> Detection:
    candidates = []
    custom = os.environ.get(app.get("pathEnv", "LAB_GUI_" + app["id"].upper() + "_PATH"))
    if custom:
        candidates.append(Path(custom).expanduser())
    for command in app["commands"]:
        if found := shutil.which(command):
            candidates.append(Path(found))
    metadata = []
    if system == "Windows":
        metadata = [entry for entry in (installed or [])
                    if fnmatch.fnmatchcase(entry.get("DisplayName", "").lower(), app["pattern"].lower())]
        for pattern in app["windowsPaths"]:
            candidates.extend(Path(p) for p in glob.glob(os.path.expandvars(pattern)))
        for entry in metadata:
            icon = re.sub(r",\s*-?\d+$", "", entry.get("DisplayIcon", "")).strip('"')
            if icon.lower().endswith(".exe") and not re.search(r"unins|setup", Path(icon).name, re.I):
                candidates.append(Path(os.path.expandvars(icon)))
            if location := entry.get("InstallLocation"):
                directory = Path(os.path.expandvars(location.strip('"')))
                for command in app["commands"]:
                    candidates.extend((directory / command, directory / "bin" / command))
    elif system == "Darwin":
        for root in (Path("/Applications"), Path.home() / "Applications"):
            for name in app["bundles"]:
                bundle = root / name
                if bundle.exists():
                    metadata.append({})
                if path := bundle_executable(bundle):
                    candidates.append(path)
    if app["id"] == "dynamixelWizard":
        for root in (Path.home() / "DYNAMIXEL Wizard 2.0", Path.home() / "DYNAMIXEL2Wizard"):
            for command in app["commands"]:
                candidates.extend((root / command, root / "bin" / command))
    found = next((p for p in candidates if executable(p, system)), None)
    version = next((entry["DisplayVersion"] for entry in metadata if entry.get("DisplayVersion")), "")
    return Detection(found, bool(metadata), version)


def report() -> int:
    print("\n標準GUI（GIMP、KiCad、VS Code、Arduino IDE 2、Bambu Studio、DYNAMIXEL Wizard 2）")
    system = platform.system()
    installed = windows_apps() if system == "Windows" else []
    missing = 0
    for app in inventory():
        result = detect(app, system, installed)
        if result.path:
            print(f"[検出] {app['name']:<20} {result.path}" + (f" ({result.version})" if result.version else ""))
        else:
            missing += 1
            manual(app, "登録はありますが実行ファイルを確認できません。既存導入を確認してください。" if result.registered else "未検出")
    print("       GUIの版は固定しません。検出は起動・実機通信の確認とは別です。")
    return missing


def manual(app: dict, reason: str) -> None:
    variable = app.get("pathEnv", "LAB_GUI_" + app["id"].upper() + "_PATH")
    print(f"[手動] {app['name']}: {reason}\n       {app['url']}\n       独自の導入先は {variable} に実行ファイルの絶対パスを指定できます。")


def captured(command: list[str], env: dict | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(command, check=False, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=60, env=env)


def brew_environment() -> dict:
    env = dict(os.environ, HOMEBREW_NO_SUDO="1", HOMEBREW_NO_INSTALL_UPGRADE="1",
               HOMEBREW_NO_AUTO_UPDATE="1", HOMEBREW_NO_INSTALL_CLEANUP="1", HOMEBREW_CASK_OPTS="")
    # Let brew recompute effective settings instead of inheriting a parent brew snapshot.
    env.pop("HOMEBREW_USER_SET_VARS", None)
    return env


def brew_supports_no_sudo(brew: str, env: dict) -> bool:
    result = captured([brew, "config"], env)
    if result.returncode:
        return False
    lines = set(result.stdout.splitlines())
    required = ("NO_SUDO", "NO_INSTALL_UPGRADE", "NO_AUTO_UPDATE", "NO_INSTALL_CLEANUP")
    return all("HOMEBREW_" + name + ": set" in lines for name in required) and not any(
        line.startswith("HOMEBREW_FORCE_API_AUTO_UPDATE:") or (
            line.startswith("HOMEBREW_CASK_OPTS:") and line.partition(":")[2].strip())
        for line in lines)


def brew_registered(brew: str, cask: str, env: dict) -> bool:
    result = captured([brew, "list", "--cask", "-1"], env)
    if result.returncode:
        raise RuntimeError("Homebrewの導入済み一覧を取得できません。重複導入を避けて停止します。")
    return cask in result.stdout.splitlines()


def safe_cask(brew: str, cask: str, env: dict) -> bool:
    result = captured([brew, "info", "--cask", "--json=v2", "homebrew/cask/" + cask], env)
    if result.returncode:
        return False
    data = json.loads(result.stdout)["casks"]
    if len(data) != 1 or data[0]["token"] != cask:
        return False
    # Do not run pkg installers, pre/post scripts, or writes to shared OS directories.
    allowed = {"app", "binary", "command_wrapper", "zap", "uninstall"}
    dependencies = data[0].get("depends_on") or {}
    if any(dependencies.get(kind) for kind in ("cask", "formula")):
        return False
    expected = next((app["bundles"] for app in inventory() if app.get("cask") == cask), [])
    app_count = 0
    for artifact in data[0]["artifacts"]:
        if not isinstance(artifact, dict):
            return False
        # "target" is computed output metadata, separate from operation arguments.
        operations = set(artifact) - {"target"}
        if len(operations) != 1 or not operations <= allowed:
            return False
        if "app" in operations:
            payload = artifact["app"]
            # Explicit destination options can ignore --appdir: reject those.
            if not isinstance(payload, list) or len(payload) != 1 or payload[0] not in expected:
                return False
            if Path(payload[0]).name != payload[0]:
                return False
            app_count += 1
    return app_count == 1


def run_install(command: list[str], system: str, env: dict | None) -> subprocess.CompletedProcess:
    if system == "Windows":
        # Start-Process -Wait includes descendants, even if an installer exits first.
        import base64
        quote = lambda value: "'" + value.replace("'", "''") + "'"
        code = ("$ErrorActionPreference='Stop'; $p=Start-Process -FilePath " + quote(command[0]) +
                " -ArgumentList " + quote(" ".join(command[1:])) +
                " -NoNewWindow -Wait -PassThru; exit $p.ExitCode")
        encoded = base64.b64encode(code.encode("utf-16-le")).decode("ascii")
        powershell = str(Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe")
        command = [powershell, "-NoProfile", "-EncodedCommand", encoded]
    return subprocess.run(command, check=False, env=env)


def assert_normal_user(system: str) -> None:
    if system == "Windows":
        import ctypes
        if ctypes.windll.shell32.IsUserAnAdmin():
            raise RuntimeError("管理者として実行しないでください。")
    elif hasattr(os, "geteuid") and os.geteuid() == 0:
        raise RuntimeError("root / sudoでは実行しないでください。")


def provision() -> int:
    system = platform.system()
    assert_normal_user(system)
    installed = windows_apps() if system == "Windows" else []
    failures = pending = 0
    for app in inventory():
        result = detect(app, system, installed)
        if result.path:
            print(f"[保持] {app['name']}: 導入済み。更新しません。")
            continue
        if result.registered:
            manual(app, "既存の登録を確認してください。自動再導入は行いません。")
            pending += 1
            continue
        command = None
        env = None
        try:
            if system == "Windows" and app.get("winget") and (winget := shutil.which("winget")):
                # No machine-scope fallback, version pin, override, elevation or security bypass.
                command = [winget, "install", "--id", app["winget"], "--exact", "--source", "winget",
                           "--scope", "user", "--installer-type", app["installerType"],
                           "--architecture", "x64", "--no-upgrade", "--skip-dependencies",
                           "--accept-source-agreements", "--accept-package-agreements", "--disable-interactivity"]
                if app["installerType"] != "portable":
                    command.append("--interactive")
            elif system == "Darwin" and app.get("cask") and (brew := shutil.which("brew")):
                env = brew_environment()
                if brew_registered(brew, app["cask"], env):
                    manual(app, "Homebrewに登録済みです。導入先・起動を確認してください。更新しません。")
                    pending += 1
                    continue
                if brew_supports_no_sudo(brew, env) and safe_cask(brew, app["cask"], env):
                    directory = Path.home() / "Applications"
                    directory.mkdir(exist_ok=True)
                    command = [brew, "install", "--cask", "--no-binaries", "--appdir=" + str(directory),
                               "homebrew/cask/" + app["cask"]]
            if command is None:
                manual(app, "通常権限の自動導入経路が未対応、またはパッケージ管理ツールが未準備です。")
                pending += 1
                continue
            print(f"[待機中] {app['name']}を導入します。インストールが終わるまで、このターミナルは閉じないでください。", flush=True)
            print("管理者権限を要求された場合はキャンセルし、研究室の管理者に相談してください。", flush=True)
            print("完了画面ではアプリの起動を選ばずに閉じてください。起動した場合はそのアプリも閉じてください。", flush=True)
            process = run_install(command, system, env)
            # Windows registration can change while the installer is running.
            after = detect(app, system, windows_apps() if system == "Windows" else [])
            if process.returncode or not after.path:
                print(f"[失敗] {app['name']}: 終了コード {process.returncode}。導入後の検出: {bool(after.path)}")
                manual(app, "キャンセル・通信・導入先を確認して再実行してください。")
                failures += 1
            else:
                print(f"[検出] {app['name']}: 導入を確認しました。")
        except (OSError, subprocess.TimeoutExpired, ValueError, KeyError, RuntimeError) as exc:
            manual(app, str(exc))
            failures += 1
    print(f"GUI結果: 導入失敗 {failures} 件、手動確認 {pending} 件")
    return 1 if failures else 2 if pending else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="標準GUIの検出・不足分導入")
    parser.add_argument("--install-missing", action="store_true")
    args = parser.parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    try:
        return provision() if args.install_missing else int(report() > 0)
    except (OSError, RuntimeError) as exc:
        print(f"[失敗] {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
