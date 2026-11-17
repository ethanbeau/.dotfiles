"""Validate package selection and checksum handling without network access."""

import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    "native_release", Path(__file__).resolve().parents[1] / "scripts/native-release.py"
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("Cannot load native package helper")
RELEASE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RELEASE)


class NativeResponse(io.BytesIO):
    url = "https://example.com/package.deb"


class NativeReleaseTest(unittest.TestCase):
    def test_native_release_requires_exact_asset_match(self):
        data = {
            "assets": [
                {"name": "other.deb", "browser_download_url": "https://example.com"}
            ]
        }
        with (
            patch.object(
                RELEASE, "fetch", return_value=io.BytesIO(json.dumps(data).encode())
            ),
            self.assertRaises(ValueError),
        ):
            RELEASE.github_asset("usebruno/bruno", "bruno_.*\\.deb")

    def test_checksum_failure_removes_download(self):
        with tempfile.TemporaryDirectory(prefix="dotfiles-release-check-") as work:
            target = Path(work) / "package.deb"
            response = NativeResponse(b"incorrect bytes")
            with (
                patch.object(
                    RELEASE.sys,
                    "argv",
                    ["native-release.py", "bruno-release", "deb", str(target)],
                ),
                patch.object(
                    RELEASE, "release_url", return_value=(response.url, "sha256:wrong")
                ),
                patch.object(RELEASE, "fetch", return_value=response),
                self.assertRaises(ValueError),
            ):
                RELEASE.main()
            self.assertFalse(target.exists())


if __name__ == "__main__":
    unittest.main()
