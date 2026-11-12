"""Isolated dispatch tests. Run from backend/: python -m unittest discover -s tests"""
import importlib.util
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import Mock, patch


class AnalyzeRoutingTests(unittest.TestCase):
    def setUp(self):
        # Stub out computationally expensive legacy dependencies during imports.
        module_fns = {
            "ai.cleanup": {"cleanup_previous_outputs": Mock()},
            "ai.audio_module": {"analyze_audio": Mock(return_value={
                "trimmed_audio_path": "trimmed.wav",
                "lip_start_time": 0.0, "lip_end_time": 1.0,
            })},
            "ai.lip_module": {"analyze_lip": Mock(return_value={
                "average_mouth_open_score": 50, "max_mouth_open_score": 50,
                "lip_movement_score": 50, "visual_total_score": 50,
            })},
            "ai.whisper_module": {"recognize_speech": Mock(return_value={"recognized_text": "아"}),
                                  "check_target_match": Mock(return_value=True)},
            "ai.feedback_module": {"make_feedback": Mock(return_value=["기존 피드백"])},
            "ai.result_writer": {"save_final_result": Mock(),
                                  "convert_audio_result_for_save": Mock(return_value={})},
        }
        self.fakes = {}
        for name, attrs in module_fns.items():
            mod = types.ModuleType(name)
            for attr, fn in attrs.items():
                setattr(mod, attr, fn)
            self.fakes[name] = mod
        self.patchers = patch.dict(sys.modules, self.fakes)
        self.patchers.start()
        spec = importlib.util.spec_from_file_location(
            "split_analyze_under_test",
            Path(__file__).resolve().parents[1] / "ai" / "analyze.py",
        )
        self.analyze = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.analyze)

    def tearDown(self):
        self.patchers.stop()

    def test_phonemes_use_original_pipeline(self):
        for category, target in [("모음", "ㅏ"), ("자음", "ㄱ")]:
            with self.subTest(category=category), patch.object(
                self.analyze, "analyze_sentence", side_effect=AssertionError("sentence called")
            ):
                result = self.analyze.analyze_pronunciation("demo.mp4", category, target)
                self.assertEqual(result["category"], category)
                self.assertNotIn("voice_analysis", result)
        self.assertEqual(self.fakes["ai.audio_module"].analyze_audio.call_count, 2)
        self.assertEqual(self.fakes["ai.lip_module"].analyze_lip.call_count, 2)

    def test_sentence_uses_only_new_pipeline(self):
        sample = {
            "recognized_text": "안녕하세요",
            "text_comparison": {"normalized_match": True},
            "audio_features": {"duration": {"speech_sec": 2.1},
                               "volume": {"mean_db": -24.1},
                               "pitch": {"mean_hz": 223.4}},
        }
        package = types.ModuleType("voice_analysis")
        package.analyze_video = Mock(return_value=sample)
        with patch.dict(sys.modules, {"voice_analysis": package}):
            result = self.analyze.analyze_pronunciation(
                "sentence.mp4", "문장", "안녕하세요"
            )
        package.analyze_video.assert_called_once()
        self.assertEqual(package.analyze_video.call_args.kwargs["reference_text"], "안녕하세요")
        self.assertEqual(result["voice_analysis"], sample)
        self.assertEqual(result["category"], "문장")
        self.assertIsNone(result["audio_total_score"])
        self.assertIsNone(result["visual_total_score"])
        self.fakes["ai.audio_module"].analyze_audio.assert_not_called()
        self.fakes["ai.lip_module"].analyze_lip.assert_not_called()
        self.fakes["ai.whisper_module"].recognize_speech.assert_not_called()

    def test_unsupported_category_rejected(self):
        with self.assertRaises(ValueError):
            self.analyze.analyze_pronunciation("demo.mp4", "단어", "안녕")


if __name__ == "__main__":
    unittest.main()
