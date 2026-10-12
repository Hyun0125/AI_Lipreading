import argparse
import json
from pathlib import Path
from urllib.parse import quote

from .audio_extractor import extract_audio
from .audio_features import analyze_audio_features
from .whisper_module import transcribe_audio
from .text_comparison import compare_text
from .phoneme_comparison import compare_phonemes
from .etri_pronunciation import assess_pronunciation, get_api_key


def analyze_video(video_path, output_dir=None, media_base_url=None, reference_text=None, *, pronunciation_provider=None, etri_audio_format="wav"):
    """Return a JSON-compatible dict and save it as result.json.

    Serve output_dir at media_base_url to make the media URLs accessible.
    """
    if pronunciation_provider not in (None, "etri"):
        raise ValueError("pronunciation_provider는 None 또는 etri이어야 합니다.")
    if pronunciation_provider == "etri":
        get_api_key()
        if reference_text is None:
            raise ValueError("ETRI 발음 평가에는 기준 문장이 필요합니다.")
    if reference_text is not None:
        compare_text(reference_text, '')  # Validate before expensive analysis.
    output_dir = Path(output_dir or Path("outputs") / Path(video_path).stem)
    output_dir.mkdir(parents=True, exist_ok=True)
    base_url = (media_base_url or "/media/" + quote(output_dir.name)).rstrip("/")
    audio_path = extract_audio(video_path, output_dir / "audio.wav")
    pronunciation = None
    if pronunciation_provider == "etri":
        pronunciation = assess_pronunciation(audio_path, reference_text, audio_format=etri_audio_format)
        recognized_text = pronunciation["recognized_text"]
    else:
        recognized_text = transcribe_audio(audio_path)
    graphs = {}
    features = analyze_audio_features(
        audio_path, recognized_text, graph_data=graphs, output_dir=output_dir
    )
    graphs["spectrogram_url"] = base_url + "/spectrogram.png"
    graphs["preview_url"] = base_url + "/frequency_graph.png"
    result = {
        "schema_version": 1,
        "recognized_text": recognized_text,
        "pronunciation_assessment": pronunciation,
        "text_comparison": compare_text(reference_text, recognized_text),
        "phoneme_comparison": compare_phonemes(reference_text, recognized_text),
        "audio_features": features,
        "graphs": graphs,
        "audio_url": base_url + "/audio.wav",
    }
    json_path = output_dir / "result.json"
    json_path.write_text(
        json.dumps(result, ensure_ascii=False, indent=2, allow_nan=False),
        encoding="utf-8",
    )
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Analyze video and export frontend JSON.")
    parser.add_argument("video_path", nargs="?", default="sample.mp4")
    parser.add_argument("--output-dir")
    parser.add_argument("--media-base-url")
    parser.add_argument("--reference-text", help="기준 문장 (음성 인식 결과와 비교)")
    parser.add_argument("--pronunciation-provider", choices=["etri"])
    parser.add_argument("--etri-audio-format", choices=["wav", "pcm"], default="wav")
    args = parser.parse_args()
    result = analyze_video(args.video_path, args.output_dir, args.media_base_url, args.reference_text,
                           pronunciation_provider=args.pronunciation_provider, etri_audio_format=args.etri_audio_format)
    output_dir = Path(args.output_dir or Path("outputs") / Path(args.video_path).stem)
    print("JSON saved:", (output_dir / "result.json").resolve())

    print()
    print("=" * 50)
    print("음성 분석 결과")
    print("=" * 50)

    print()
    print("[음성 인식]")
    print("인식 문장 :", result["recognized_text"])
    if result["pronunciation_assessment"] is not None:
        print("ETRI 문장 발음 점수 :", result["pronunciation_assessment"]["score"], "/ 5")

    comparison = result["text_comparison"]
    if comparison is not None:
        print("기준 문장 :", comparison["reference_text"] )
        print("문장 일치 (공백/문장부호 제외) :", comparison["normalized_match"] )
        print("문자 유사도 :", comparison["character_similarity_percent"], "%")
        print("차이 :", comparison["differences"] )

    phonemes = result["phoneme_comparison"]
    if phonemes is not None:
        print("한글 구성 요소 유사도 :", phonemes["overall"]["similarity_percent"], "%")
        for item in phonemes["mismatched_symbols"]:
            label = {"initial": "초성", "vowel": "모음", "final": "받침"}[item["position"]]
            print(f"재확인: {label} {item['symbol']} / 일치 {item['matched_count']}/{item['expected_count']}회")
        print(phonemes["limitation"])

    f = result["audio_features"]

    print()
    print("[발화 시간]")
    print("전체 길이 :", f["duration"]["total_sec"], "초")
    print("실제 발화 :", f["duration"]["speech_sec"], "초")
    print("무음 시간 :", f["duration"]["silence_sec"], "초")
    print(
        "발화 비율 :",
        f["duration"]["speech_ratio_percent"],
        "%"
    )
    print(
        "무음 비율 :",
        f["duration"]["silence_ratio_percent"],
        "%"
    )

    print()
    print("[말하기 속도]")
    print(
        "음절 수 :",
        f["speech_rate"]["syllable_count"]
    )
    print(
        "단어 수 :",
        f["speech_rate"]["word_count"]
    )
    print(
        "초당 음절 수 :",
        f["speech_rate"]["syllables_per_second"]
    )
    print(
        "분당 단어 수 :",
        f["speech_rate"]["words_per_minute"]
    )

    print()
    print("[음량]")
    print(
        "평균 음량 :",
        f["volume"]["mean_db"],
        "dB"
    )
    print(
        "최저 음량 :",
        f["volume"]["min_db"],
        "dB"
    )
    print(
        "최고 음량 :",
        f["volume"]["max_db"],
        "dB"
    )
    print(
        "음량 범위 :",
        f["volume"]["range_db"],
        "dB"
    )
    print(
        "음량 변화 표준편차 :",
        f["volume"]["std_db"],
        "dB"
    )

    print()
    print("[음높이]")
    print(
        "평균 F0 :",
        f["pitch"]["mean_hz"],
        "Hz"
    )
    print(
        "중앙 F0 :",
        f["pitch"]["median_hz"],
        "Hz"
    )
    print(
        "최저 F0 :",
        f["pitch"]["min_hz"],
        "Hz"
    )
    print(
        "최고 F0 :",
        f["pitch"]["max_hz"],
        "Hz"
    )
    print(
        "F0 범위 :",
        f["pitch"]["range_hz"],
        "Hz"
    )
    print(
        "F0 표준편차 :",
        f["pitch"]["std_hz"],
        "Hz"
    )
    print(
        "F0 변화율 :",
        f["pitch"]["variation_percent"],
        "%"
    )
    print(
        "음높이 범위 :",
        f["pitch"]["range_semitones"],
        "반음"
    )

    print()
    print("[쉼]")
    print(
        "쉼 횟수 :",
        f["pause"]["count"]
    )
    print(
        "총 쉼 시간 :",
        f["pause"]["total_sec"],
        "초"
    )
    print(
        "평균 쉼 시간 :",
        f["pause"]["average_sec"],
        "초"
    )
    print(
        "가장 긴 쉼 :",
        f["pause"]["max_sec"],
        "초"
    )

    print()
    print("[음성]")
    print(
        "유성음 비율 :",
        f["voice"]["voiced_ratio_percent"],
        "%"
    )
