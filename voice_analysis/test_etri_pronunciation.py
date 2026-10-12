import base64
import io
import json
import tempfile
import unittest
import wave
from pathlib import Path
from unittest.mock import patch
from urllib.error import HTTPError

from .etri_pronunciation import EtriAPIError, assess_pronunciation, build_payload, parse_response


class EtriTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "audio.wav"
        self.write_audio()

    def write_audio(self, frames=16000, rate=16000, sample=b"\x01\x00"):
        with wave.open(str(self.path), "wb") as audio:
            audio.setparams((1, 2, rate, 0, "NONE", "not compressed"))
            audio.writeframes(sample * frames)

    def test_payload_formats(self):
        payload = build_payload(self.path, "밥")
        self.assertEqual(payload["argument"]["language_code"], "korean")
        self.assertEqual(payload["argument"]["script"], "밥")
        self.assertEqual(base64.b64decode(payload["argument"]["audio"]), self.path.read_bytes())
        pcm = build_payload(self.path, "밥", "pcm")
        self.assertEqual(base64.b64decode(pcm["argument"]["audio"]), b"\x01\x00" * 16000)

    def test_invalid_audio(self):
        for frames, rate, sample in ((0, 16000, b"\x01\x00"), (960001, 16000, b"\x01\x00"),
                                     (16000, 8000, b"\x01\x00"), (16000, 16000, b"\x00\x00")):
            self.write_audio(frames, rate, sample)
            with self.assertRaises(ValueError):
                build_payload(self.path, "밥")

    def test_valid_and_invalid_score(self):
        result = parse_response({"result": 0, "return_object": {"recognized": "밥", "score": "4.2"}})
        self.assertEqual(result["score"], 4.2)
        self.assertIsNone(result["phoneme_scores"])
        for score in (None, "nan", 6, 0, True):
            with self.assertRaises(EtriAPIError):
                parse_response({"result": 0, "return_object": {"recognized": "밥", "score": score}})

    def test_error_response(self):
        for response in ({"result": -1}, {}, [], {"result": 0, "return_object": {}}, {"result": False}):
            with self.assertRaises(EtriAPIError):
                parse_response(response)

    def test_request_and_response(self):
        response = {"result": 0, "return_object": {"recognized": "밥", "score": 4}}
        with patch("voice_analysis.etri_pronunciation.urlopen", return_value=io.BytesIO(json.dumps(response).encode())) as call:
            result = assess_pronunciation(self.path, "밥", api_key="test-key")
            self.assertEqual(result["score"], 4)
            request = call.call_args.args[0]
            self.assertEqual(request.get_header("Authorization"), "test-key")
            self.assertEqual(request.get_method(), "POST")
            self.assertEqual(json.loads(request.data)["argument"]["script"], "밥")

    def test_http_error_does_not_echo_key(self):
        error = HTTPError("http://test", 403, "test-secret", {}, None)
        with patch("voice_analysis.etri_pronunciation.urlopen", side_effect=error):
            with self.assertRaises(EtriAPIError) as raised:
                assess_pronunciation(self.path, "밥", api_key="test-secret")
            self.assertNotIn("test-secret", str(raised.exception))

    def test_missing_key_blocks_request(self):
        with patch.dict("os.environ", {"ETRI_API_KEY": ""}), patch("voice_analysis.etri_pronunciation.urlopen") as call:
            with self.assertRaises(ValueError):
                assess_pronunciation(self.path, "밥")
            call.assert_not_called()

    def test_video_pipeline_uses_etri(self):
        from .analyze import analyze_video
        with patch.dict("os.environ", {"ETRI_API_KEY": "test-key"}), \
             patch("voice_analysis.analyze.extract_audio", return_value=self.path), \
             patch("voice_analysis.analyze.assess_pronunciation", return_value={"score": 4, "recognized_text": "바"}), \
             patch("voice_analysis.analyze.transcribe_audio") as whisper, \
             patch("voice_analysis.analyze.analyze_audio_features", return_value={}):
            result = analyze_video("test.mp4", self.directory.name, reference_text="밥", pronunciation_provider="etri")
            whisper.assert_not_called()
            self.assertEqual(result["pronunciation_assessment"]["score"], 4)
            self.assertEqual(result["phoneme_comparison"]["differences"][0]["expected"], "ㅂ")
            saved = json.loads((Path(self.directory.name) / "result.json").read_text(encoding="utf-8"))
            self.assertEqual(saved, result)
