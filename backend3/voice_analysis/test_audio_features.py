import json
import tempfile
import unittest
from pathlib import Path

import numpy as np
import soundfile as sf

from .audio_features import analyze_audio_features


class AudioFeatureTests(unittest.TestCase):
    def test_silence_is_not_speech(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "silence.wav"
            sf.write(path, np.zeros(16000), 16000)
            graphs = {}
            result = analyze_audio_features(path, graph_data=graphs, output_dir=directory)
            self.assertEqual(result["duration"]["speech_sec"], 0)
            self.assertEqual(result["duration"]["silence_ratio_percent"], 100)
            self.assertIsNone(result["pitch"]["mean_hz"])
            json.dumps({"features": result, "graphs": graphs}, allow_nan=False)

    def test_tone_pitch_and_graph_artifacts(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "tone.wav"
            samples = np.arange(16000) / 16000
            sf.write(path, 0.2 * np.sin(2 * np.pi * 220 * samples), 16000)
            graphs = {}
            result = analyze_audio_features(path, "안녕하세요", graph_data=graphs, output_dir=directory)
            self.assertAlmostEqual(result["pitch"]["mean_hz"], 220, delta=5)
            self.assertEqual(result["speech_rate"]["syllable_count"], 5)
            for graph, x, y in (("pitch", "time_sec", "frequency_hz"),
                                ("spectrum", "frequency_hz", "relative_power_db")):
                self.assertEqual(len(graphs[graph][x]), len(graphs[graph][y]))
            for filename in ("frequency_graph.png", "spectrogram.png"):
                self.assertGreater((Path(directory) / filename).stat().st_size, 0)
            json.dumps({"features": result, "graphs": graphs}, allow_nan=False)
