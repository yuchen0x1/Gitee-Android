"""Guard the release body selected for publishing, without external packages."""

import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


class ReleaseNotesTest(unittest.TestCase):
    def setUp(self):
        project = Path(__file__).resolve().parents[1]
        scratch = project / "build/release-notes-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix="case-", dir=str(scratch))
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "tool").mkdir()
        (self.root / "docs/releases").mkdir(parents=True)
        self.script = self.root / "tool/release_notes.py"
        source = Path(__file__).resolve().parents[1] / "tool/release_notes.py"
        shutil.copyfile(source, self.script)
        self.history = self.root / "docs/releases/release-notes.md"
        self.output = self.root / "release.md"

    def extract(self, history, version="v1.4.1"):
        self.history.write_bytes(history.encode("utf-8"))
        return subprocess.run(
            [sys.executable, str(self.script), "--version", version,
             "--output", str(self.output)],
            capture_output=True,
        )

    def test_selects_requested_version_without_unreleased_or_older_changes(self):
        result = self.extract(
            "## [Unreleased] - 未发布\n- future\n"
            "## [1.4.1] - 2026-11-10\n### 修复\n- 已发布\n"
            "## [1.4.0] - 2026-11-08\n- older\n"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(encoding="utf-8"), "### 修复\n- 已发布\n")

    def test_missing_version_does_not_create_a_release_body(self):
        result = self.extract("## [Unreleased] - 未发布\n- future\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.output.exists())

    def test_duplicate_version_fails_instead_of_publishing_an_arbitrary_entry(self):
        result = self.extract("## [1.4.1]\n- first\n## [1.4.1]\n- second\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.output.exists())

    def test_empty_entry_is_rejected(self):
        result = self.extract("## [1.4.1]\n\n## [1.4.0]\n- older\n")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.output.exists())

    def test_unreleased_cannot_be_used_as_a_published_version(self):
        result = self.extract("## [Unreleased]\n- future\n", "Unreleased")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.output.exists())

    def test_output_has_utf8_lf_newlines_on_windows_and_linux(self):
        result = self.extract("## [1.4.1]\r\n- 修复\r\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_bytes(), "- 修复\n".encode("utf-8"))


if __name__ == "__main__":
    unittest.main()
