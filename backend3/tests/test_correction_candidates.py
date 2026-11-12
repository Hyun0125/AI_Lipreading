import json
from pathlib import Path
import tempfile
import unittest

from voice_analysis.correction_candidates import detect_correction_candidates
from voice_analysis.correction_integration import enrich_sentence_analysis


class CorrectionTests(unittest.TestCase):
    def test_both_agree_on_word_and_syllable(self):
        r = detect_correction_candidates(
            "친구와 함께 학교에 가요.",
            "친구와 함께 학교에 와요.",
            "친구와 함께 학교에 와요.", 3.2,
        )
        self.assertEqual(r["status"], "review_candidates")
        self.assertEqual(r["total_candidate_words"], 1)
        item = r["candidates"][0]
        self.assertEqual((item["expected_word"], item["recognized_by_whisper"], item["priority"]),
                         ("가요", "와요", "high"))
        self.assertEqual(item["syllable_candidates"][0]["expected"], "가")
        self.assertEqual(item["syllable_candidates"][0]["recognized"], "와")
        self.assertTrue(any(d["position"] == "initial" for d in item["syllable_candidates"][0]["jamo_changes"]))

    def test_only_one_asr_differs(self):
        r = detect_correction_candidates("학교에 가요", "학교에 와요", "학교에 가요", 4.5)
        self.assertEqual(r["candidates"][0]["priority"], "low")
        self.assertEqual(r["candidates"][0]["evidence_sources"], ["whisper"])

    def test_both_differ_in_different_ways(self):
        r = detect_correction_candidates("학교에 가요", "학교에 와요", "학교에 나요")
        self.assertEqual(r["candidates"][0]["priority"], "medium")

    def test_spacing_punctuation_ignored(self):
        r = detect_correction_candidates("할 수 있어요!", "할수있어요.", "할 수 있어요")
        self.assertEqual(r["status"], "no_text_difference")
        self.assertEqual(r["candidates"], [])

    def test_empty_asr_not_false_omission(self):
        r = detect_correction_candidates("안녕하세요", "", None)
        self.assertEqual(r["status"], "no_recognition")
        self.assertEqual(r["candidates"], [])

    def test_missing_syllable(self):
        r = detect_correction_candidates("사과를 먹어요", "사과를 먹어", None)
        self.assertTrue(any(x["operation"] == "delete" for x in r["candidates"][0]["syllable_candidates"]))

    def test_score_alone_does_not_create_candidates(self):
        r = detect_correction_candidates("아침마다 책을 읽어요", "아침마다 책을 읽어요", "아침마다 책을 읽어요", 1.0)
        self.assertEqual(r["status"], "no_text_difference")

    def test_integration_keeps_existing_fields_and_persists(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "result.json").write_text(json.dumps({"volume": 42}), encoding="utf-8")
            data = {
                "recognized_text": "학교에 와요", "audio_features": {"duration": 3.0},
                "whisper_recognized_text": "학교에 와요",
                "pronunciation_assessment": {"provider": "etri", "recognized_text": "학교에 와요", "score": 4.1},
            }
            result = enrich_sentence_analysis(data, reference_text="학교에 가요", output_dir=root)
            self.assertEqual(result["recognized_text"], "학교에 와요")
            self.assertEqual(result["audio_features"], {"duration": 3.0})
            self.assertEqual(result["correction_candidates"]["candidates"][0]["expected_word"], "가요")
            persisted = json.loads((root / "result.json").read_text(encoding="utf-8"))
            self.assertEqual(persisted["volume"], 42)
            self.assertEqual(persisted["correction_candidates"]["status"], "review_candidates")


if __name__ == "__main__":
    unittest.main()
