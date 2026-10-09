"""読み取り専用診断の失敗判定と、標準設定の整合性を確認する。"""
from __future__ import annotations

import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tomllib
import unittest
from unittest.mock import patch

import doctor

ROOT = Path(__file__).resolve().parents[1]


class DoctorTests(unittest.TestCase):
    def test_cli_ready_does_not_hide_missing_gui(self):
        for required, expected_exit in ((False, 0), (True, 1)):
            with self.subTest(required=required), contextlib.redirect_stdout(io.StringIO()) as output:
                arguments = ["doctor", "--require-gui"] if required else ["doctor"]
                with patch.object(sys, "argv", arguments), patch.object(doctor.shutil, "which", return_value="tool.exe"), \
                     patch.object(doctor, "run", return_value=(True, " ".join(doctor.EXPECTED.values()))), \
                     patch.object(doctor.importlib.metadata, "version", return_value="4.1.0"), \
                     patch.object(doctor, "serial_report"), patch.object(doctor, "gui_report", return_value=3), \
                     patch.object(doctor, "docker_report"):
                    self.assertEqual(doctor.main(), expected_exit)
                self.assertIn("未完了" if required else "GUI未検出 3 件", output.getvalue())

    def test_docker_cli_is_distinct_from_engine(self):
        with patch.object(doctor.shutil, "which", side_effect=lambda name: "docker.exe" if name == "docker" else None), \
             patch.object(doctor, "run", side_effect=[(True, "Docker 1"), (True, "Compose 1"), (False, "connection refused")]), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            doctor.docker_report()
        self.assertIn("[検出] Docker CLI", output.getvalue())
        self.assertIn("[手動] Docker Engine", output.getvalue())

    def test_probe_timeout_is_reported(self):
        with patch.object(doctor.subprocess, "run", side_effect=subprocess.TimeoutExpired(["docker"], 15)):
            self.assertFalse(doctor.run(["docker"])[0])

    def test_gui_absence_is_reported(self):
        with patch.object(doctor.shutil, "which", return_value=None), patch.object(doctor.gui_tools, "windows_apps", return_value=[]), \
             patch.object(doctor.Path, "is_file", return_value=False), contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(doctor.gui_report(), 6)
        self.assertIn("DYNAMIXEL_WIZARD_PATH", output.getvalue())

    def test_explicit_wizard_location_is_detected(self):
        target = sys.executable
        with patch.dict(os.environ, {"DYNAMIXEL_WIZARD_PATH": target}), \
             patch.object(doctor.shutil, "which", return_value=None), patch.object(doctor.gui_tools, "windows_apps", return_value=[]), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            doctor.gui_report()
        self.assertIn("[検出] DYNAMIXEL Wizard 2", output.getvalue())

    def test_non_executable_wizard_location_is_not_detected(self):
        target = str(ROOT / "README.md")
        with patch.dict(os.environ, {"DYNAMIXEL_WIZARD_PATH": target}), \
             patch.object(doctor.shutil, "which", return_value=None), patch.object(doctor.gui_tools, "windows_apps", return_value=[]), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            doctor.gui_report()
        self.assertIn("[手動] DYNAMIXEL Wizard 2", output.getvalue())

    def test_wsl_uses_utf16_without_changing_other_probes(self):
        result = subprocess.CompletedProcess(["wsl.exe", "--status"], 0, "既定のバージョン: 2\n", "")
        with patch.object(doctor.subprocess, "run", return_value=result) as probe:
            self.assertEqual(doctor.run(["wsl.exe", "--status"], encoding="utf-16-le"),
                             (True, "既定のバージョン: 2"))
        self.assertEqual(probe.call_args.kwargs["encoding"], "utf-16-le")

    def test_supported_pins_and_manual_boundary(self):
        config = tomllib.loads((ROOT / "mise.toml").read_text())
        lock = tomllib.loads((ROOT / "mise.lock").read_text())
        entry = lock["tools"]["gh"][0]
        self.assertEqual(entry["version"], config["tools"]["gh"])
        self.assertEqual(entry["version"], doctor.EXPECTED["gh"])
        for platform in ("windows-x64", "linux-x64", "linux-arm64", "macos-x64", "macos-arm64"):
            self.assertRegex(entry[f"platforms.{platform}"]["checksum"], r"^sha256:[a-f0-9]{64}$")
        manifest = json.loads((ROOT / "config/windows-apps.json").read_text())
        self.assertTrue(manifest["git"]["url"].startswith("https://"))
        self.assertRegex(manifest["git"]["sha256"], r"^[a-f0-9]{64}$")
        self.assertEqual(set(manifest), {"git"})
        apps = doctor.gui_tools.inventory()
        self.assertEqual(len(apps), 6)
        self.assertTrue(all("version" not in app for app in apps))
        self.assertNotIn("winget", next(app for app in apps if app["id"] == "dynamixelWizard"))


if __name__ == "__main__":
    unittest.main()
