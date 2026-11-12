import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from voice_analysis.correction_integration import (
    build_sentence_repractice, enrich_sentence_analysis,
)


class SentencePracticeTests(unittest.TestCase):
    def test_low_score_recommends_whole_sentence(self):
        result = build_sentence_repractice(2.81269)
        self.assertTrue(result['recommended'])
        self.assertEqual(result['status'], 'recommended')
        self.assertIn('문장 전체', result['message'])

    def test_normal_score_not_recommended(self):
        self.assertFalse(build_sentence_repractice(4.06)['recommended'])
        self.assertEqual(build_sentence_repractice(3.5)['status'], 'not_needed')

    def test_unavailable_or_bad_score_cannot_recommend(self):
        for score in (None, 'xyz', 0, 6, float('nan'), float('inf'), True):
            with self.subTest(score=score):
                self.assertEqual(build_sentence_repractice(score)['status'], 'unavailable')

    def test_actual_example_detected_and_persisted(self):
        with tempfile.TemporaryDirectory() as work:
            file = Path(work) / 'result.json'
            file.write_text(json.dumps({'pronunciation_assessment': {'score': 2.81269}}), encoding='utf-8')
            raw = {
                'pronunciation_assessment': {
                    'score': 2.81269,
                    'recognized_text': '바다에 작은 배가 떠 있어요.',
                },
                'whisper_recognized_text': '하늘에 작은 배가 더 있어요.',
            }
            result = enrich_sentence_analysis(
                raw, reference_text='바다에 작은 배가 떠 있어요.', output_dir=work)
            self.assertTrue(result['sentence_repractice']['recommended'])
            self.assertEqual(result['correction_candidates']['status'], 'review_candidates')
            self.assertEqual([x['expected_word'] for x in result['correction_candidates']['candidates']], ['바다에', '떠'])
            self.assertEqual([x['priority'] for x in result['correction_candidates']['candidates']], ['low', 'low'])
            saved = json.loads(file.read_text(encoding='utf-8'))
            self.assertTrue(saved['sentence_repractice']['recommended'])
            self.assertEqual(len(saved['correction_candidates']['candidates']), 2)
            self.assertEqual(result['pronunciation_assessment']['score'], 2.81269)

    def test_low_score_even_when_transcripts_match(self):
        raw = {
            'pronunciation_assessment': {'score': 2.9, 'recognized_text': '아침마다 책을 읽어요.'},
            'whisper_text': '아침마다 책을 읽어요.',
        }
        with tempfile.TemporaryDirectory() as work:
            result = enrich_sentence_analysis(raw, reference_text='아침마다 책을 읽어요.', output_dir=work)
        self.assertTrue(result['sentence_repractice']['recommended'])
        self.assertEqual(result['correction_candidates']['status'], 'no_text_difference')

    def test_missing_etri_does_not_invent_score(self):
        raw = {'whisper_recognized_text': '가요'}
        with tempfile.TemporaryDirectory() as work:
            result = enrich_sentence_analysis(raw, reference_text='가요', output_dir=work)
        self.assertEqual(result['sentence_repractice']['status'], 'unavailable')

    def test_full_analyze_sentence_returns_practice_data_and_feedback(self):
        import importlib.util
        import voice_analysis
        code = Path(__file__).resolve().parents[1] / 'ai' / 'analyze.py'
        spec = importlib.util.spec_from_file_location('trial_ai_analyze', code)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        def fake_analyze_video(*args, **kwargs):
            output_dir = Path(kwargs['output_dir'])
            output_dir.mkdir(parents=True, exist_ok=True)
            (output_dir / 'result.json').write_text('{}', encoding='utf-8')
            return {
                'recognized_text': '하늘에 작은 배가 더 있어요.',
                'whisper_recognized_text': '하늘에 작은 배가 더 있어요.',
                'pronunciation_assessment': {
                    'score': 2.81269,
                    'recognized_text': '바다에 작은 배가 떠 있어요.',
                },
                'text_comparison': {'normalized_match': False},
                'audio_features': {},
            }

        previous_cwd = Path.cwd()
        with tempfile.TemporaryDirectory() as tmp, patch.object(
            voice_analysis, 'analyze_video', fake_analyze_video, create=True
        ):
            os.chdir(tmp)
            try:
                result = module.analyze_sentence('sample.webm', '바다에 작은 배가 떠 있어요.')
            finally:
                os.chdir(previous_cwd)
        self.assertIn('voice_analysis', result)
        self.assertTrue(result['voice_analysis']['sentence_repractice']['recommended'])
        self.assertIn('바다에', result['voice_analysis']['correction_candidates']['summary'])
        self.assertTrue(any('문장 전체' in value for value in result['feedbacks']))
        self.assertIsNone(result['audio_total_score'])
        self.assertIsNone(result['visual_total_score'])

    def test_custom_threshold(self):
        raw = {'pronunciation_assessment': {'score': 4.0, 'recognized_text': '가요'}, 'whisper_text': '가요'}
        with tempfile.TemporaryDirectory() as work, patch.dict(os.environ, {'SENTENCE_REPRACTICE_THRESHOLD': '4.5'}):
            result = enrich_sentence_analysis(raw, reference_text='가요', output_dir=work)
        self.assertTrue(result['sentence_repractice']['recommended'])
        self.assertEqual(result['sentence_repractice']['threshold'], 4.5)


if __name__ == '__main__':
    unittest.main()
