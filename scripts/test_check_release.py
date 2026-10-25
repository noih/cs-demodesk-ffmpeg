import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError
import os
import tempfile

spec = importlib.util.spec_from_file_location("check_release", Path(__file__).with_name("check-release.py"))
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.release = dict(id=10, tag_name="autobuild-2026-10-24-13-02", published_at="2026-10-24",
                            draft=False, prerelease=False, assets=[dict(id=20, state="uploaded",
                            name="ffmpeg-N-128013-g6b05263b44-win64-gpl-shared.zip", updated_at="2026-10-24")])

    def test_rolling_latest_is_not_a_version(self):
        rolling = dict(self.release, tag_name="latest", published_at="2026-10-25")
        self.assertEqual(check.select_release([rolling, self.release])[2], "6b05263b44")

    def test_incomplete_newest_release_fails(self):
        incomplete = dict(self.release, published_at="2026-10-25", assets=[])
        with self.assertRaises(ValueError):
            check.select_release([self.release, incomplete])

    def test_release_tag_preserves_ffmpeg_version_and_identifies_package(self):
        asset = self.release["assets"][0]
        tag = check.release_tag(self.release, asset, "b" * 40)
        self.assertRegex(tag, r"^N-128013-g6b05263b44-[0-9a-f]{8}$")
        self.assertEqual(tag, check.release_tag(self.release, asset, "b" * 40))
        self.assertNotEqual(tag, check.release_tag(self.release, asset, "c" * 40))
        replaced = dict(asset, id=21, digest="sha256:" + "a" * 64)
        self.assertNotEqual(tag, check.release_tag(self.release, replaced, "b" * 40))

    def test_existing_release_skips_and_missing_resolves_published_sources(self):
        for existing in (True, False):
            with self.subTest(existing=existing), tempfile.TemporaryDirectory() as folder:
                output = str(Path(folder) / "output")
                calls = []
                def api(path):
                    calls.append(path)
                    if "?per_page" in path:
                        return [self.release]
                    if "/releases/tags/" in path:
                        if existing:
                            return {"draft": False}
                        raise HTTPError(path, 404, "Not Found", {}, None)
                    return {"sha": "a" * 40}
                with patch.dict(os.environ, GITHUB_SHA="b" * 40, GITHUB_REPOSITORY="noih/test", GITHUB_OUTPUT=output), patch.object(check, "api", api):
                    check.main()
                self.assertIn(f"changed={'false' if existing else 'true'}", Path(output).read_text())
                self.assertRegex(Path(output).read_text(), r"tag=N-128013-g6b05263b44-[0-9a-f]{8}\n")
                self.assertIn("upstream=autobuild-2026-10-24-13-02\n", Path(output).read_text())
                self.assertIn("version=N-128013-g6b05263b44\n", Path(output).read_text())
                self.assertEqual(len(calls), 2 if existing else 4)
                if not existing:
                    self.assertTrue(calls[2].endswith(self.release["tag_name"]))
                    self.assertTrue(calls[3].endswith("6b05263b44"))


if __name__ == "__main__":
    unittest.main()
