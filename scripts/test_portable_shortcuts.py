"""ショートカットと導入のテスト。実ユーザーのリンク・アプリは変更しない。"""
from __future__ import annotations

import base64
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import gui_tools as gui


class PortableShortcutTests(unittest.TestCase):
    def setUp(self):
        self.apps = [app for app in gui.inventory() if app.get("installerType") == "portable"]

    def entry(self, app, root):
        return {"DisplayName": app["name"], "InstallLocation": str(root),
                "WinGetPackageIdentifier": app["winget"], "WinGetInstallerType": "portable",
                "WinGetSourceIdentifier": "Microsoft.Winget.Source_8wekyb3d8bbwe", "_scope": "user"}

    def target(self, app, root):
        target = root / app["commands"][-1]
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(b"fixture only, never execute")
        return target

    def test_registered_portable_target_uses_real_package_root(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "日本語 & [1]!' programs"
            for app in self.apps:
                target = self.target(app, root / app["id"])
                self.assertEqual(gui.portable_shortcut_target(app, [self.entry(app, target.parent)]),
                                 target.resolve())

    def test_nested_executable_layout_is_resolved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = self.apps[-1]
            target = self.target(app, root / "日本語 folder" / "bin")
            self.assertEqual(gui.portable_shortcut_target(app, [self.entry(app, root)]), target.resolve())
            with patch.object(gui.shutil, "which", return_value=None):
                self.assertEqual(gui.detect(app, "Windows", [self.entry(app, root)]).path, target.resolve())

    def test_ambiguous_or_missing_executable_is_not_guessed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app = self.apps[-1]
            self.assertIsNone(gui.portable_shortcut_target(app, [self.entry(app, root)]))
            for name in ("first", "second"):
                self.target(app, root / name)
            self.assertIsNone(gui.portable_shortcut_target(app, [self.entry(app, root)]))

    def test_nonportable_machine_or_other_package_is_not_managed(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.apps[-1]
            root = Path(directory)
            self.target(app, root)
            for field, value in (("WinGetInstallerType", "nullsoft"), ("_scope", "machine"),
                                 ("WinGetPackageIdentifier", "Other.Package")):
                entry = self.entry(app, root)
                entry[field] = value
                self.assertIsNone(gui.portable_shortcut_target(app, [entry]))
                with patch.object(gui, "create_portable_shortcut") as create:
                    self.assertEqual(gui.ensure_portable_shortcut(app, "Windows", [entry]), 0)
                    create.assert_not_called()

    def test_missing_or_other_source_is_not_managed(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.apps[-1]
            root = Path(directory)
            self.target(app, root)
            for source in (None, "Private.Source", ""):
                entry = self.entry(app, root)
                if source is None:
                    del entry["WinGetSourceIdentifier"]
                else:
                    entry["WinGetSourceIdentifier"] = source
                with patch.object(gui, "create_portable_shortcut") as create:
                    self.assertEqual(gui.ensure_portable_shortcut(app, "Windows", [entry]), 0)
                    create.assert_not_called()

    def test_existing_portable_creates_shortcut_with_actual_executable(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.apps[-1]
            target = self.target(app, Path(directory))
            with patch.object(gui, "create_portable_shortcut", return_value=0) as create:
                self.assertEqual(gui.ensure_portable_shortcut(app, "Windows", [self.entry(app, target.parent)]), 0)
            create.assert_called_once_with(app, target.resolve())

    def test_managed_portable_without_executable_remains_pending(self):
        app = self.apps[-1]
        with tempfile.TemporaryDirectory() as directory, patch.object(gui, "create_portable_shortcut") as create, \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(gui.ensure_portable_shortcut(app, "Windows", [self.entry(app, Path(directory))]), 2)
            create.assert_not_called()

    def test_shortcut_pending_and_error_are_propagated(self):
        app = self.apps[-1]
        with tempfile.TemporaryDirectory() as directory:
            target = self.target(app, Path(directory))
            for status in (1, 2):
                with patch.object(gui, "create_portable_shortcut", return_value=status):
                    self.assertEqual(gui.ensure_portable_shortcut(app, "Windows",
                                     [self.entry(app, target.parent)]), status)

    def test_macos_linux_and_installer_apps_do_not_create_shortcuts(self):
        for system, app in (("Darwin", self.apps[-1]), ("Linux", self.apps[-1]), ("Windows", gui.inventory()[0])):
            with patch.object(gui, "create_portable_shortcut") as create:
                self.assertEqual(gui.ensure_portable_shortcut(app, system, []), 0)
                create.assert_not_called()

    def test_shortcut_bridge_encodes_paths_as_data_without_launching_app(self):
        app = self.apps[-1]
        target = Path("C:/日本語 & [1]!/Bambu Studio/bambu-studio.exe")
        result = subprocess.CompletedProcess([], 0, "[追加] shortcut\n", "")
        with patch.dict(os.environ, {"SystemRoot": "C:/Windows"}), \
             patch.object(gui.subprocess, "run", return_value=result) as run, \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(gui.create_portable_shortcut(app, target), 0)
        command = run.call_args.args[0]
        self.assertIn("-NoProfile", command)
        self.assertNotIn("-ExecutionPolicy", command)
        self.assertIn("-Command", command)
        self.assertIn("-NonInteractive", command)
        self.assertNotIn("-EncodedCommand", command)
        code = command[-1]
        self.assertTrue(code.isascii())
        payload = code.split("-RequestBase64 '", 1)[1].split("'", 1)[0]
        request = json.loads(base64.b64decode(payload).decode("utf-8"))
        self.assertEqual(request["target"], str(target))
        self.assertEqual(request["name"], app["name"])
        self.assertEqual(request["packageId"], app["winget"])
        self.assertNotIn("RunAs", code)

    @unittest.skipUnless(os.name == "nt", "Windows PowerShell 5.1 output fixture")
    def test_real_powershell_bridge_text_streams_and_exit_codes(self):
        # Load a fake script through the production bridge; never touch real links/apps.
        with tempfile.TemporaryDirectory() as directory:
            fixture_root = Path(directory) / "日本語 & [1]!' fixture"
            scripts = fixture_root / "scripts"
            scripts.mkdir(parents=True)
            (scripts / "ensure-portable-shortcut.ps1").write_text(
                """param([string]$RequestBase64)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$request = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($RequestBase64)) | ConvertFrom-Json
Write-Progress -Activity 'Preparing modules for first use.' -Status 'fixture 初回'
Write-Host ('[追加] fixture ' + $request.name)
Write-Host ('target: ' + $request.target)
Write-Warning 'fixture 警告'
[Console]::Error.WriteLine('fixture native stderr 日本語')
if ($request.packageId -eq 'throw') { throw 'fixture 真の失敗' }
if ($request.packageId -eq '7') { Write-Error 'fixture 真の失敗' -ErrorAction Continue }
exit ([int]$request.packageId)
""", encoding="utf-8")
            target = Path("C:/fixture 日本語 & [1]!' 🌿/fixture.exe")
            for status, expected in (("0", 0), ("2", 2), ("7", 1), ("throw", 1)):
                with self.subTest(status=status), patch.object(gui, "ROOT", fixture_root):
                    output = io.StringIO()
                    with contextlib.redirect_stdout(output):
                        result = gui.create_portable_shortcut(
                            {"name": "日本語 🌿", "winget": status}, target)
                    rendered = output.getvalue()
                    self.assertEqual(result, expected)
                    self.assertEqual(rendered.count("[追加] fixture 日本語 🌿"), 1)
                    self.assertIn("target: " + str(target), rendered)
                    self.assertIn("fixture 警告", rendered)
                    self.assertIn("fixture native stderr 日本語", rendered)
                    self.assertNotIn("#< CLIXML", rendered)
                    self.assertNotIn("<Objs", rendered)
                    self.assertNotIn("InformationRecord", rendered)
                    self.assertNotIn("ProgressRecord", rendered)
                    if expected == 1:
                        self.assertIn("fixture 真の失敗", rendered)

    def test_rerun_repairs_shortcut_without_install_or_upgrade(self):
        app = self.apps[-1]
        with tempfile.TemporaryDirectory() as directory:
            target = self.target(app, Path(directory))
            entry = self.entry(app, target.parent)
            with patch.object(gui.platform, "system", return_value="Windows"), patch.object(gui, "assert_normal_user"), \
                 patch.object(gui, "inventory", return_value=[app]), patch.object(gui, "windows_apps", return_value=[entry]), \
                 patch.object(gui, "detect", return_value=gui.Detection(target, True)), \
                 patch.object(gui, "create_portable_shortcut", return_value=0) as create, \
                 patch.object(gui, "run_install") as install, contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(gui.provision(), 0)
                self.assertEqual(gui.provision(), 0)
            self.assertEqual(create.call_count, 2)
            install.assert_not_called()

    def test_shortcut_conflict_or_failure_marks_rerun_incomplete(self):
        app = self.apps[-1]
        with tempfile.TemporaryDirectory() as directory:
            target = self.target(app, Path(directory))
            entry = self.entry(app, target.parent)
            for status in (1, 2):
                with patch.object(gui.platform, "system", return_value="Windows"), patch.object(gui, "assert_normal_user"), \
                     patch.object(gui, "inventory", return_value=[app]), patch.object(gui, "windows_apps", return_value=[entry]), \
                     patch.object(gui, "detect", return_value=gui.Detection(target, True)), \
                     patch.object(gui, "create_portable_shortcut", return_value=status), \
                     patch.object(gui, "run_install") as install, contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(gui.provision(), status)
                    install.assert_not_called()

    def test_new_install_repairs_shortcut_after_detection(self):
        app = self.apps[-1]
        with tempfile.TemporaryDirectory() as directory:
            target = self.target(app, Path(directory))
            entry = self.entry(app, target.parent)
            with patch.object(gui.platform, "system", return_value="Windows"), patch.object(gui, "assert_normal_user"), \
                 patch.object(gui, "inventory", return_value=[app]), patch.object(gui, "windows_apps", side_effect=[[], [entry]]), \
                 patch.object(gui, "detect", side_effect=[gui.Detection(), gui.Detection(target, True)]), \
                 patch.object(gui.shutil, "which", return_value="winget.exe"), \
                 patch.object(gui, "create_portable_shortcut", return_value=0) as create, \
                 patch.object(gui, "run_install", return_value=subprocess.CompletedProcess([], 0)), \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(gui.provision(), 0)
            create.assert_called_once_with(app, target.resolve())


if __name__ == "__main__":
    unittest.main()
