import json
import unittest

from .phoneme_comparison import compare_phonemes, decompose_syllable


class PhonemeComparisonTests(unittest.TestCase):
    def test_hangul_decomposition(self):
        self.assertEqual(decompose_syllable("밥"), ("ㅂ", "ㅏ", "ㅂ"))
        self.assertEqual(decompose_syllable("힣"), ("ㅎ", "ㅣ", "ㅎ"))
        self.assertEqual(decompose_syllable("값"), ("ㄱ", "ㅏ", "ㅄ"))

    def test_initial_replacement(self):
        result = compare_phonemes("바", "파")
        self.assertEqual(result["overall"]["similarity_percent"], 50)
        self.assertEqual(len(result["differences"]), 1)
        self.assertEqual(result["differences"][0]["expected"], "ㅂ")
        self.assertEqual(result["differences"][0]["recognized"], "ㅍ")

    def test_vowel_replacement(self):
        result = compare_phonemes("바", "버")
        self.assertEqual(result["differences"][0]["position"], "vowel")
        self.assertEqual(result["mismatched_symbols"][0]["symbol"], "ㅏ")

    def test_missing_final(self):
        result = compare_phonemes("밥", "바")
        self.assertEqual(result["differences"][0]["position"], "final")
        self.assertEqual(result["differences"][0]["operation"], "delete")

    def test_missing_syllable_preserves_suffix(self):
        result = compare_phonemes("바나나", "바나")
        self.assertEqual(result["overall"]["match_count"], 4)
        self.assertEqual(result["overall"]["delete_count"], 2)
        self.assertEqual(result["overall"]["replace_count"], 0)

    def test_added_syllable(self):
        result = compare_phonemes("바나", "바나나")
        self.assertEqual(result["overall"]["insert_count"], 2)
        self.assertLess(result["overall"]["similarity_percent"], 100)

    def test_unicode_formatting(self):
        result = compare_phonemes("바 나!", "바나")
        self.assertEqual(result["overall"]["similarity_percent"], 100)
        self.assertEqual(result["differences"], [])

    def test_empty_recognition(self):
        result = compare_phonemes("밥", "")
        self.assertEqual(result["overall"]["delete_count"], 3)
        self.assertEqual(result["overall"]["similarity_percent"], 0)

    def test_no_hangul_and_optional_reference(self):
        self.assertIsNone(compare_phonemes(None, "바"))
        result = compare_phonemes("abc", "abc")
        self.assertIsNone(result["overall"]["similarity_percent"])
        json.dumps(result, allow_nan=False)
        with self.assertRaises(ValueError):
            compare_phonemes("!", "바")

    def test_separate_initial_and_final_counts(self):
        result = compare_phonemes("밥 밥", "밥 바")
        affected = result["mismatched_symbols"]
        self.assertEqual(len(affected), 1)
        self.assertEqual(affected[0]["position"], "final")
        self.assertEqual(affected[0]["expected_count"], 2)
        self.assertEqual(affected[0]["match_percent"], 50)
