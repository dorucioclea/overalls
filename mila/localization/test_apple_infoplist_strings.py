from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from apple_infoplist_strings import generate, lproj_name, render


class AppleInfoPlistStringsTest(unittest.TestCase):
    def test_locale_names_follow_apple_lproj_convention(self) -> None:
        self.assertEqual(lproj_name(Path("app_en.arb")), "en")
        self.assertEqual(lproj_name(Path("app_pt_BR.arb")), "pt-BR")
        self.assertEqual(lproj_name(Path("app_zh_Hans.arb")), "zh-Hans")
        self.assertEqual(lproj_name(Path("app_fil.arb")), "fil")
        self.assertIsNone(lproj_name(Path("app_../x.arb")))

    def test_usage_text_is_escaped(self) -> None:
        self.assertEqual(
            render({"lockExplain": 'Say "hi"\\now'}),
            'NSFaceIDUsageDescription = "Say \\"hi\\"\\\\now";\n',
        )

    def test_empty_or_non_text_usage_is_refused(self) -> None:
        for bad in ("", "   ", 3):
            with self.assertRaises(ValueError):
                render({"lockExplain": bad})
        with self.assertRaises(ValueError):
            render(["lockExplain"])

    def test_english_usage_text_is_required(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory)
            (source / "app_de.arb").write_text('{"lockExplain":"Entsperren"}', encoding="utf-8")
            with self.assertRaises(ValueError):
                generate(source, source / "out")

    def test_repository_catalogs_generate(self) -> None:
        catalogs = Path(__file__).parent / "catalogs"
        with tempfile.TemporaryDirectory() as directory:
            written = generate(catalogs, Path(directory))
            self.assertIn("en", written)
            english = (Path(directory) / "en.lproj" / "InfoPlist.strings").read_text(
                encoding="utf-8"
            )
            self.assertTrue(english.startswith("NSFaceIDUsageDescription = "))


if __name__ == "__main__":
    unittest.main()
