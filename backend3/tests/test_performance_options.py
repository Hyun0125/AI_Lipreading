"""Fast pitch option and legacy pYIN regression coverage (synthetic signal, no ML weights)."""
import os
import unittest
from unittest.mock import patch

import numpy as np
from ai.audio_features import analyze_audio_features


class PitchOptionsTests(unittest.TestCase):
    def setUp(self):
        sr = 16000
        t=np.arange(sr//2)/sr
        self.signal=(0.2*np.sin(2*np.pi*220*t)).astype(np.float32)
        self.sr=sr

    def test_yin_fast_pitch_produces_same_response_schema(self):
        with patch.dict(os.environ, {'JAMO_PITCH_METHOD':'yin'}):
            data=analyze_audio_features(self.signal,self.sr)
        self.assertGreater(data['pitch_mean'],150)
        self.assertLess(data['pitch_mean'],290)
        self.assertGreater(data['final_audio_score'],0)
        self.assertTrue({'pitch_mean','volume','duration','pitch_std','final_audio_score'}<=set(data))

    def test_original_pyin_option(self):
        with patch.dict(os.environ, {'JAMO_PITCH_METHOD':'pyin'}):
            data=analyze_audio_features(self.signal,self.sr)
        self.assertGreater(data['pitch_mean'],150)
        self.assertLess(data['pitch_mean'],290)

    def test_invalid_method_not_silent(self):
        with patch.dict(os.environ, {'JAMO_PITCH_METHOD':'unknown'}):
            with self.assertRaises(ValueError):
                analyze_audio_features(self.signal,self.sr)

if __name__=='__main__':unittest.main()
