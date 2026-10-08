"""Markdown内のローカルリンクがリポジトリ内で解決できることを確認する。"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)]+)\)")
SKIP_PARTS = {".git", ".venv", ".mise"}


class DocumentationTests(unittest.TestCase):
    def test_windows_source_inventory_matches_tracked_files(self) -> None:
        if not (ROOT / ".git").exists():
            self.skipTest("配布ZIPではGit追跡情報がない")
        manifest = ROOT / "config/windows-source-files.txt"
        inventory = [line for line in manifest.read_text(encoding="utf-8").splitlines()
                     if line and not line.startswith("#")]
        tracked = subprocess.check_output(
            ["git", "ls-files", "-z"], cwd=ROOT).decode("utf-8").rstrip("\0").split("\0")
        self.assertEqual(len(inventory), len(set(inventory)), "配布一覧に重複がある")
        self.assertEqual(set(inventory), set(tracked), "ZIPコピー一覧を追跡ファイルと同期する")

    def test_local_markdown_links_exist(self) -> None:
        failures: list[str] = []
        for document in ROOT.rglob("*.md"):
            if any(part in SKIP_PARTS for part in document.parts):
                continue
            text = document.read_text(encoding="utf-8")
            for raw_target in LINK_RE.findall(text):
                target = raw_target.strip().split()[0].strip("<>")
                if target.startswith(("http://", "https://", "mailto:", "#")):
                    continue
                path_text = target.split("#", 1)[0]
                if not path_text:
                    continue
                resolved = (document.parent / path_text).resolve()
                if not resolved.exists():
                    failures.append(f"{document.relative_to(ROOT)} -> {target}")
        self.assertFalse(failures, "解決できないローカルリンク:\n" + "\n".join(failures))


if __name__ == "__main__":
    unittest.main()
