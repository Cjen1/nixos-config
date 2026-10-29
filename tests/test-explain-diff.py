"""Browser regression test; requires Chromium and Python's playwright package."""

import importlib.util
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from playwright.sync_api import sync_playwright


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "modules/home-manager/coding-agents/copilot-skills/explain-diff/walkthrough.py"
spec = importlib.util.spec_from_file_location("walkthrough", SCRIPT)
walkthrough = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = walkthrough
spec.loader.exec_module(walkthrough)


class StickyFileHeaderTests(unittest.TestCase):
    def test_scrolling_and_navigation(self):
        with tempfile.TemporaryDirectory(prefix="explain-diff-") as directory:
            repo = Path(directory)

            def git(*args):
                return subprocess.check_output(
                    ["git", "-C", directory, *args], text=True
                ).strip()

            git("init", "--quiet")
            git("config", "user.name", "Test")
            git("config", "user.email", "test@example.invalid")
            paths = ["Proofs/Witnesses.txt", "Tests/CanonicalTraces.txt"]
            comments = []
            for path in paths:
                target = repo / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text("".join(f"line {i}\n" for i in range(1, 501)))
                for line in (100, 300, 450):
                    comments.append((path, line, line, f"Explain {path}:{line}"))
            git("add", ".")
            git("commit", "--quiet", "-m", "Before")
            base = git("rev-parse", "HEAD")
            for path in paths:
                target = repo / path
                target.write_text(target.read_text().replace("line 300\n", "changed 300\n"))
            git("commit", "--quiet", "-am", "After")
            output = walkthrough.render_walkthrough(
                repo, base, git("rev-parse", "HEAD"), comments, repo / "index.html",
                "A walkthrough title long enough to wrap the toolbar on narrow screens",
            )
            with sync_playwright() as playwright:
                browser = playwright.chromium.launch(
                    executable_path=shutil.which("chromium"), args=["--no-sandbox"]
                )
                try:
                    for width in (1600, 900, 600):
                        with self.subTest(width=width):
                            page = browser.new_page(viewport={"width": width, "height": 900})
                            page.goto(output.as_uri())
                            self.assertEqual(page.locator("main").evaluate("(e) => e.scrollTop"), 0)
                            page.locator("#step").select_option("1")
                            self.assert_header(page, "file-0", paths[0], pinned=True)
                            self.assertGreater(page.locator(".fold:visible").count(), 0)
                            page.locator("#next").click()
                            self.assert_header(page, "file-0", paths[0])
                            page.locator("#file").select_option("file-1")
                            self.assert_header(page, "file-1", paths[1])
                            page.locator("#step").select_option("4")
                            self.assert_header(page, "file-1", paths[1])
                            page.locator("#prev").click()
                            self.assert_header(page, "file-1", paths[1])
                            page.close()
                    page = browser.new_page(java_script_enabled=False)
                    page.goto(output.as_uri())
                    page.locator("#file-1").evaluate("(e) => e.scrollIntoView()")
                    page.locator("main").evaluate("(e) => e.scrollTop += 100")
                    self.assert_header(page, "file-1", paths[1])
                finally:
                    browser.close()

    def assert_header(self, page, file_id, path, pinned=False):
        header = page.locator(f"#{file_id} h2")
        self.assertEqual(header.inner_text(), path)
        toolbar = page.locator("header").bounding_box()
        box = header.bounding_box()
        toolbar_bottom = toolbar["y"] + toolbar["height"]
        self.assertGreaterEqual(box["y"], toolbar_bottom - 2)
        self.assertLessEqual(box["y"] + box["height"], page.viewport_size["height"])
        if pinned:
            self.assertAlmostEqual(box["y"], toolbar_bottom, delta=2)
        self.assertEqual(
            page.evaluate(
                "([x,y]) => document.elementFromPoint(x,y).tagName",
                [box["x"] + 20, box["y"] + box["height"] / 2],
            ),
            "H2",
        )


if __name__ == "__main__":
    unittest.main()
