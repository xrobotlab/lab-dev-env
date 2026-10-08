"""バージョン表示の対象と、justfileの探索・実行場所を確認する。"""
from __future__ import annotations

import ast
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]


def versions_commands() -> list[list[str]]:
    text = (ROOT / "justfile").read_text(encoding="utf-8")
    match = re.search(r"(?m)^versions:\n((?:[ \t]+[^\n]*(?:\n|$)|\n)+)", text)
    if match is None:
        raise AssertionError("versionsレシピがありません")
    return [shlex.split(line.strip()) for line in match.group(1).splitlines() if line.strip()]


class VersionsTests(unittest.TestCase):
    def test_all_standard_cli_versions_are_reported(self) -> None:
        config = tomllib.loads((ROOT / "mise.toml").read_text(encoding="utf-8"))
        aliases = {"pypi:platformio": "pio"}
        tools = {"git", "mise", "npm", "npx"} | {
            aliases.get(name, name) for name in config["tools"]
        }
        commands = versions_commands()
        missing = sorted(tool for tool in tools if [tool, "--version"] not in commands)
        self.assertFalse(missing, f"versionsに不足している標準CLI: {missing}")

    def test_sdk_version_uses_locked_b3_environment(self) -> None:
        commands = [args for args in versions_commands() if args[:2] == ["uv", "run"]]
        self.assertEqual(len(commands), 1, "SDKのバージョンはB3環境で取得してください")
        args = commands[0]
        self.assertIn("--locked", args)
        project_index = args.index("--project")
        self.assertEqual(args[project_index + 1], "b3")
        self.assertEqual(args[project_index + 2:project_index + 4], ["python", "-c"])
        code = ast.parse(args[-1])
        self.assertTrue(any(
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and node.func.attr == "version"
            and node.args
            and isinstance(node.args[0], ast.Constant)
            and node.args[0].value == "dynamixel-sdk"
            for node in ast.walk(code)
        ), "SDKのdistributionバージョンを表示してください")


@unittest.skipUnless(shutil.which("just"), "justがPATHに必要です")
class JustLocationTests(unittest.TestCase):
    def test_repo_subdirectory_and_explicit_file_use_repo_root(self) -> None:
        with tempfile.TemporaryDirectory() as outside:
            contexts = (
                (ROOT, []),
                (ROOT / "b3", []),
                (Path(outside), ["--justfile", str(ROOT / "justfile")]),
            )
            for cwd, arguments in contexts:
                with self.subTest(cwd=cwd):
                    result = subprocess.run(
                        ["just", *arguments, "--command", sys.executable, "-c",
                         "from pathlib import Path; print(Path.cwd())"],
                        cwd=cwd, check=True, text=True, capture_output=True, encoding="utf-8",
                        timeout=15,
                    )
                    self.assertEqual(Path(result.stdout.strip()).resolve(), ROOT)


if __name__ == "__main__":
    unittest.main()
