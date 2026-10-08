"""導入はmockのみ。ホストのアプリ・パッケージ管理設定は変更しない。"""
from __future__ import annotations
import base64
import contextlib
import io
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import gui_tools as gui


class GuiTests(unittest.TestCase):
    def setUp(self):
        self.apps = gui.inventory()

    def provision(self, system, app, detection, code=0, **mocks):
        with contextlib.ExitStack() as stack:
            output = stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
            stack.enter_context(patch.object(gui.platform, "system", return_value=system))
            stack.enter_context(patch.object(gui, "assert_normal_user"))
            stack.enter_context(patch.object(gui, "inventory", return_value=[app]))
            stack.enter_context(patch.object(gui, "windows_apps", return_value=[]))
            stack.enter_context(patch.object(gui, "detect", side_effect=detection))
            stack.enter_context(patch.object(gui.shutil, "which", return_value="package-manager"))
            install = stack.enter_context(patch.object(gui, "run_install",
                                                       return_value=subprocess.CompletedProcess([], code)))
            for name, value in mocks.items():
                stack.enter_context(patch.object(gui, name, return_value=value))
            result = gui.provision()
            return result, install, output.getvalue()

    def test_standard_inventory_and_unpinned_gui(self):
        self.assertEqual({a["id"] for a in self.apps},
                         {"gimp", "kicad", "vscode", "arduino", "bambu", "dynamixelWizard"})
        self.assertTrue(all("version" not in a and "sha256" not in a for a in self.apps))
        self.assertEqual({a["id"] for a in self.apps if a.get("cask")}, {"gimp", "vscode", "arduino", "bambu"})

    def test_windows_constrained_types_and_waiting_message(self):
        for app in self.apps[:-1]:
            with self.subTest(app=app["id"]):
                result, install, output = self.provision("Windows", app, [gui.Detection(), gui.Detection(Path("app.exe"))])
                self.assertEqual(result, 0)
                command = install.call_args.args[0]
                for option, value in (("--id", app["winget"]), ("--source", "winget"),
                                      ("--scope", "user"), ("--installer-type", app["installerType"])):
                    self.assertEqual(command[command.index(option) + 1], value)
                for option in ("--exact", "--no-upgrade", "--skip-dependencies"):
                    self.assertIn(option, command)
                self.assertNotIn("--version", command)
                self.assertNotIn("--override", command)
                self.assertEqual("--interactive" in command, app["id"] not in ("arduino", "bambu"))
                self.assertIn("[待機中]", output)
                self.assertIn("閉じないでください", output)

    def test_existing_versions_are_never_upgraded_or_reinstalled(self):
        for registered, path in ((False, Path("old.exe")), (True, None)):
            result, install, _ = self.provision("Windows", self.apps[1],
                                               [gui.Detection(path, registered, "8.0")])
            self.assertEqual(result, 2 if registered and not path else 0)
            install.assert_not_called()

    def test_failure_cancel_and_zero_without_executable_are_not_success(self):
        for code, path in ((7, None), (2, None), (0, None), (7, Path("app.exe"))):
            result, _, output = self.provision("Windows", self.apps[0],
                                               [gui.Detection(), gui.Detection(path)], code)
            self.assertEqual(result, 1)
            self.assertIn("[失敗]", output)

    def test_manual_wizard_and_linux_remain_required(self):
        for system, app in (("Windows", self.apps[-1]), ("Linux", self.apps[0])):
            result, install, output = self.provision(system, app, [gui.Detection()])
            self.assertEqual(result, 2)
            install.assert_not_called()
            self.assertIn(app["url"], output)

    def test_unavailable_package_manager_does_not_install(self):
        with patch.object(gui.shutil, "which", return_value=None):
            # provision helper patches which, so use direct context.
            with patch.object(gui, "assert_normal_user"), patch.object(gui.platform, "system", return_value="Windows"), \
                 patch.object(gui, "inventory", return_value=[self.apps[0]]), patch.object(gui, "windows_apps", return_value=[]), \
                 patch.object(gui, "detect", return_value=gui.Detection()), patch.object(gui, "run_install") as install, \
                 contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(gui.provision(), 2)
                install.assert_not_called()

    def test_mac_installs_only_missing_cask_to_user_appdir(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(gui.Path, "home", return_value=Path(directory)):
            result, install, _ = self.provision("Darwin", self.apps[3],
                [gui.Detection(), gui.Detection(Path(directory) / "Applications/Arduino IDE.app")],
                brew_registered=False, brew_supports_no_sudo=True, safe_cask=True)
            self.assertEqual(result, 0)
            command = install.call_args.args[0]
            self.assertIn("--appdir=" + str(Path(directory) / "Applications"), command)
            self.assertIn("--no-binaries", command)
            self.assertEqual(command[-1], "homebrew/cask/arduino-ide")
            self.assertEqual(install.call_args.args[2]["HOMEBREW_NO_SUDO"], "1")

    def test_mac_registration_and_unsupported_controls_preserve_app(self):
        for registered, controls in ((True, True), (False, False)):
            result, install, _ = self.provision("Darwin", self.apps[0], [gui.Detection()],
                    brew_registered=registered, brew_supports_no_sudo=controls, safe_cask=True)
            self.assertEqual(result, 2)
            install.assert_not_called()

    def test_brew_control_capability_and_override(self):
        lines = ["HOMEBREW_" + name + ": set" for name in
                 ("NO_SUDO", "NO_AUTO_UPDATE", "NO_INSTALL_UPGRADE", "NO_INSTALL_CLEANUP")]
        for output, expected in (("\n".join(lines), True), ("\n".join(lines[1:]), False),
                                 ("\n".join(lines + ["HOMEBREW_FORCE_API_AUTO_UPDATE: set"]), False),
                                 ("\n".join(lines + ["HOMEBREW_CASK_OPTS: --appdir=/Other"]), False)):
            with patch.object(gui, "captured", return_value=subprocess.CompletedProcess([], 0, output)):
                self.assertEqual(gui.brew_supports_no_sudo("brew", {}), expected)

    def test_brew_environment_recomputes_settings_without_changing_parent(self):
        with patch.dict(os.environ, {"HOMEBREW_USER_SET_VARS": "old_snapshot",
                                     "HOMEBREW_CASK_OPTS": "--appdir=/Other"}):
            env = gui.brew_environment()
            self.assertNotIn("HOMEBREW_USER_SET_VARS", env)
            self.assertEqual(env["HOMEBREW_CASK_OPTS"], "")
            self.assertEqual(os.environ["HOMEBREW_USER_SET_VARS"], "old_snapshot")
            self.assertEqual(os.environ["HOMEBREW_CASK_OPTS"], "--appdir=/Other")

    def test_cask_pkg_script_shared_artifact_and_dependencies_are_rejected(self):
        for artifacts, dependencies, expected in (
            ([{"app": ["GIMP.app"], "target": "/Applications/GIMP.app"},
              {"command_wrapper": ["gimp"], "target": "/opt/homebrew/bin/gimp"}], {}, True),
            ([{"pkg": ["app.pkg"]}], {}, False),
            ([{"app": ["GIMP.app", {"target": "/Library/Other.app"}]}], {}, False),
            ([{"app": ["../../GIMP.app"]}], {}, False),
            ([{"preflight": None}], {}, False),
            ([{"artifact": ["demos", {"target": "/Library/demos"}]}], {}, False),
            ([{"app": ["App.app"]}], {"formula": ["other"]}, False)):
            data = {"casks": [{"token": "gimp", "artifacts": artifacts, "depends_on": dependencies}]}
            with patch.object(gui, "captured", return_value=subprocess.CompletedProcess([], 0, json.dumps(data))):
                self.assertEqual(gui.safe_cask("brew", "gimp", {}), expected)

    def test_mac_bundle_detects_actual_executable_without_launch(self):
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "Applications/GIMP.app"
            (bundle / "Contents/MacOS").mkdir(parents=True)
            with (bundle / "Contents/Info.plist").open("wb") as handle:
                plistlib.dump({"CFBundleExecutable": "gimp"}, handle)
            executable = bundle / "Contents/MacOS/gimp"
            executable.write_text("fixture")
            executable.chmod(0o755)
            with patch.object(gui.Path, "home", return_value=Path(directory)), \
                 patch.object(gui.shutil, "which", return_value=None):
                self.assertEqual(gui.detect(self.apps[0], "Darwin").path, executable)

    def test_portable_arduino_custom_root_is_detected_from_registration(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "Arduino IDE.exe"
            target.write_text("fixture executable, never run")
            entry = {"DisplayName": "Arduino IDE", "DisplayVersion": "2.3.10",
                     "InstallLocation": directory}
            with patch.object(gui.shutil, "which", return_value=None):
                result = gui.detect(self.apps[3], "Windows", [entry])
            self.assertEqual(result.path, target)
            self.assertTrue(result.registered)

    def test_real_cask_artifact_shape_for_all_supported_apps(self):
        for app in self.apps:
            if not app.get("cask"):
                continue
            name = app["bundles"][0]
            data = {"casks": [{"token": app["cask"], "artifacts": [
                {"app": [name], "target": "/Applications/" + name},
                {"binary": ["/Applications/" + name + "/bin/cli"], "target": "/opt/homebrew/bin/cli"}],
                "depends_on": {"macos": [">= :monterey"]}}]}
            with patch.object(gui, "captured", return_value=subprocess.CompletedProcess([], 0, json.dumps(data))):
                self.assertTrue(gui.safe_cask("brew", app["cask"], {}))

    def test_normal_user_boundary_rejects_root(self):
        with patch.object(gui.os, "geteuid", return_value=0, create=True):
            with self.assertRaisesRegex(RuntimeError, "sudo"):
                gui.assert_normal_user("Darwin")

    def test_windows_wait_driver_preserves_unicode_path_and_exit(self):
        with patch.dict(os.environ, {"SystemRoot": "C:/Windows"}), \
             patch.object(gui.subprocess, "run", return_value=subprocess.CompletedProcess([], 23)) as run:
            result = gui.run_install(["C:/日本語 & [1]!/winget.exe", "install", "--id", "GIMP.GIMP.3"],
                                     "Windows", None)
            code = base64.b64decode(run.call_args.args[0][-1]).decode("utf-16-le")
            self.assertIn("-NoNewWindow -Wait -PassThru", code)
            self.assertIn("'C:/日本語 & [1]!/winget.exe'", code)
            self.assertNotIn("RunAs", code)
            self.assertEqual(result.returncode, 23)


if __name__ == "__main__":
    unittest.main()
