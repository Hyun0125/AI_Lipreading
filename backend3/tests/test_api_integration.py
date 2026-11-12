"""Offline FastAPI upload/save/read and route contract; no ML imports or real DB changed."""
import importlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from fastapi.testclient import TestClient


class ApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sandbox = tempfile.TemporaryDirectory()
        cls.previous = Path.cwd()
        os.chdir(cls.sandbox.name)
        for name in ['main','database','models']:
            sys.modules.pop(name,None)
        cls.main = importlib.import_module('main')
        cls.client = TestClient(cls.main.app)

    @classmethod
    def tearDownClass(cls):
        # Close the API test client before releasing SQLite connections.
        try:
            cls.client.close()
        finally:
            try:
                # Dispose the engine imported by this test's own main module.
                # Otherwise, on Windows feedback.db may remain locked when
                # TemporaryDirectory attempts to delete the sandbox.
                cls.main.engine.dispose()
            finally:
                os.chdir(cls.previous)
                try:
                    cls.sandbox.cleanup()
                finally:
                    for name in ['main', 'database', 'models']:
                        sys.modules.pop(name, None)

    def upload(self, category='모음', target='ㅏ'):
        return self.client.post('/feedback/analyze', data={'category':category,'target_item':target},
            files={'video':('recording.webm', b'video-bytes', 'video/webm')})

    def fake_result(self, video_path, category, target_item):
        path, target = video_path, target_item
        result = dict(
          id=None, user_id=None, category=category, target_item=target,video_path=path,
          created_at='2026-11-02 14:00:00', target_pronunciation='아',
          whisper_result='아', is_correct=True, feedbacks=['분석 성공'],
          voice_analysis={'recognized_text':'아','audio_features': {'duration':{'speech_sec':1.0}}},
          audio_total_score=80.0,visual_total_score=70.0)
        if category=='문장':
            result.update(audio_total_score=None,visual_total_score=None)
        return result

    def test_two_routes_same_contract(self):
        seen=[]
        def fake_analyze(*, video_path, category, target_item):
            seen.append((video_path,category,target_item))
            return self.fake_result(video_path,category,target_item)
        with patch.object(self.main,'analyze_pronunciation',side_effect=fake_analyze):
            a=self.upload('모음','ㅏ')
            b=self.upload('자음','ㄱ')
            c=self.upload('문장','안녕하세요')
        for r in [a,b,c]:
            self.assertEqual(r.status_code,200,r.text)
            self.assertTrue(r.json()['video_path'])
        self.assertEqual(len({s[0] for s in seen}),3)
        self.assertEqual([s[1] for s in seen],['모음','자음','문장'])
        self.assertEqual(c.json()['audio_total_score'],None)

    def test_save_and_review_with_null_scores(self):
        with patch.object(self.main,'analyze_pronunciation',side_effect=self.fake_result):
            res=self.upload('문장','안녕')
        self.assertEqual(res.status_code,200,res.text)
        stored=self.client.post('/feedback/save', json=res.json())
        self.assertEqual(stored.status_code,200,stored.text)
        self.assertTrue(stored.json()['success'])
        db_id=stored.json()['id']
        detail=self.client.get('/feedback/results/'+str(db_id))
        self.assertEqual(detail.json()['voice_analysis'],res.json()['voice_analysis'])
        self.assertIsNone(detail.json()['audio_total_score'])
        self.assertEqual(len(self.client.get('/feedback/results?category=문장&target_item=안녕').json()),1)
        self.assertTrue(Path(stored.json()['video_path']).exists())

    def test_cors_and_validation(self):
        with patch.object(self.main,'analyze_pronunciation',side_effect=ValueError('bad target')):
            self.assertEqual(self.upload().status_code,422)
        self.assertEqual(self.upload('단어','안녕').status_code,422)
        options=self.client.options('/feedback/analyze',headers={
             'Origin':'http://localhost:54321','Access-Control-Request-Method':'POST'})
        self.assertEqual(options.status_code,200)
        self.assertEqual(options.headers['access-control-allow-origin'],'http://localhost:54321')

    def _insert_feedback_row(self, category, target_item, user_id=None):
        db = self.main.SessionLocal()
        try:
            row = self.main.FeedbackResult(
                user_id=user_id,
                category=category,
                target_item=target_item,
                video_path='uploads/videos/count-test.webm',
            )
            db.add(row)
            db.commit()
        finally:
            db.close()

    def test_feedback_count_only_returns_matching_saved_rows(self):
        # A result from /feedback/analyze is not saved to the DB until /feedback/save.
        test_target = 'count_test_ㄲ'
        with patch.object(self.main,'analyze_pronunciation',side_effect=self.fake_result):
            analyzed = self.upload('자음', test_target)
        self.assertEqual(analyzed.status_code, 200, analyzed.text)

        zero = self.client.get('/feedback/count', params={
            'category': '자음', 'target_item': test_target,
        })
        self.assertEqual(zero.status_code, 200, zero.text)
        self.assertEqual(zero.json()['count'], 0)

        self._insert_feedback_row('자음', test_target, user_id=11)
        self._insert_feedback_row('자음', test_target, user_id=11)
        self._insert_feedback_row('자음', test_target, user_id=22)
        self._insert_feedback_row('모음', test_target, user_id=11)
        self._insert_feedback_row('자음', 'count_test_ㄱ', user_id=11)

        all_users = self.client.get('/feedback/count', params={
            'category': '자음', 'target_item': test_target,
        })
        user_11 = self.client.get('/feedback/count', params={
            'category': '자음', 'target_item': test_target, 'user_id': 11,
        })
        other_category = self.client.get('/feedback/count', params={
            'category': '모음', 'target_item': test_target,
        })
        other_target = self.client.get('/feedback/count', params={
            'category': '자음', 'target_item': 'count_test_ㄱ',
        })

        for response in (all_users, user_11, other_category, other_target):
            self.assertEqual(response.status_code, 200, response.text)
        self.assertEqual(all_users.json()['count'], 3)
        self.assertEqual(user_11.json()['count'], 2)
        self.assertEqual(other_category.json()['count'], 1)
        self.assertEqual(other_target.json()['count'], 1)

    def test_feedback_count_composite_index_is_created(self):
        with self.main.engine.connect() as connection:
            indexes = connection.exec_driver_sql(
                "PRAGMA index_list('feedback_results')"
            ).fetchall()
        index_names = {row[1] for row in indexes}
        self.assertIn('ix_feedback_results_category_target_user', index_names)

    def test_generated_media(self):
        media=Path('outputs/voice_analysis/fixture')
        media.mkdir(parents=True,exist_ok=True)
        (media/'result.json').write_text('{"ok":true}',encoding='utf-8')
        r=self.client.get('/media/fixture/result.json')
        self.assertEqual(r.status_code,200)
        self.assertEqual(r.json(),{'ok':True})


if __name__=='__main__': unittest.main()
