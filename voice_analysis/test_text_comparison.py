import unittest

from .text_comparison import compare_text


class TextComparisonTests(unittest.TestCase):
    def test_optional_reference(self):
        self.assertIsNone(compare_text(None, "안녕하세요"))

    def test_exact_match(self):
        result = compare_text("안녕하세요", "안녕하세요")
        self.assertTrue(result["exact_match"])
        self.assertEqual(result["character_similarity_percent"], 100)
        self.assertEqual(result["differences"], [])

    def test_formatting_and_unicode(self):
        result = compare_text("안녕 하세요!", "안녕하세요")
        self.assertFalse(result["exact_match"])
        self.assertTrue(result["normalized_match"])

    def test_wrong_word(self):
        result = compare_text("임용시험", "이명시험")
        self.assertFalse(result["normalized_match"])
        self.assertLess(result["character_similarity_percent"], 100)
        self.assertTrue(result["differences"])

    def test_no_recognized_speech(self):
        result = compare_text("안녕하세요", "")
        self.assertEqual(result["character_similarity_percent"], 0)
        self.assertEqual(result["differences"][0]["operation"], "delete")

    def test_invalid_reference(self):
        for reference in ("", "   ", "!?"):
            with self.assertRaises(ValueError):
                compare_text(reference, "안녕하세요")


if __name__ == "__main__":
    unittest.main()
