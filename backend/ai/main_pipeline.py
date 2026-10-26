import os

from ai.audio_module import find_speech_segment_from_video
from ai.video_preprocess import process_video_by_time
from ai.lip_module import calculate_lip_score
from ai.whisper_module import recognize_speech, check_target_match
from ai.feedback_module import generate_feedback
from ai.cleanup import cleanup_previous_outputs
from ai.result_writer import save_final_result, save_lip_score

INPUT_VIDEO_DIR = "input_videos"
VIDEO_EXTENSIONS = (".mp4", ".mov", ".avi", ".mkv")


def find_input_video(input_dir=INPUT_VIDEO_DIR):
    """
    input_videos 폴더 안의 영상 파일을 자동
    영상이 여러 개 있으면 첫 번째 영상을 사용
    """

    if not os.path.exists(input_dir):
        raise FileNotFoundError(f"{input_dir} 폴더가 없습니다.")

    video_files = [
        file for file in os.listdir(input_dir)
        if file.lower().endswith(VIDEO_EXTENSIONS)
    ]

    if len(video_files) == 0:
        raise FileNotFoundError(f"{input_dir} 폴더 안에 영상 파일이 없습니다.")

    video_files.sort()

    if len(video_files) > 1:
        print("input_videos 폴더에 영상이 여러 개 있습니다.")
        print("가장 앞에 있는 파일을 사용합니다:", video_files[0])

    return os.path.join(input_dir, video_files[0])


def is_lip_analysis_failed(lip_result):
    """
    입모양 점수가 모두 0점이면 실패로 판단
    """

    return (
        lip_result["avg_score"] == 0
        and lip_result["max_score"] == 0
        and lip_result["movement_score"] == 0
        and lip_result["final_score"] == 0
    )


def main():
    # 0. 이전 결과 삭제
    cleanup_previous_outputs()

    # 1. input_videos 폴더에서 영상 자동 선택
    video_path = find_input_video()
    print("분석할 영상:", video_path)

    # 2. 평가할 글자 입력
    target_char = input("평가할 글자를 입력하세요: ").strip()

    # 3. 음성 구간 탐지 + Librosa 음성 평가
    audio_result = find_speech_segment_from_video(video_path)

    # 4. 입술 움직임 누락 방지를 위해 앞뒤 0.5초 여유 추가
    start_time = max(audio_result["speech_start_time"] - 0.5, 0)
    end_time = audio_result["speech_end_time"] + 0.5

    # 5. 음성 구간 기준으로 영상 전처리
    video_result = process_video_by_time(
        video_path=video_path,
        start_time=start_time,
        end_time=end_time
    )

    # 6. 입모양 점수 계산
    lip_result = calculate_lip_score(
        target_char=target_char,
        landmark_path="speech_lip_landmarks.npy"
    )

    # 7. 입모양 분석 실패 여부 확인
    lip_failed = is_lip_analysis_failed(lip_result)

    if lip_failed:
        print("실패: 입모양 점수가 모두 0점입니다.")
        print("원인: 입술 좌표가 추출되지 않았거나 분석 가능한 프레임이 부족합니다.")

    # 8. Whisper 음성 인식
    whisper_result = recognize_speech(audio_result["trimmed_audio_path"])
    recognized_text = whisper_result["recognized_text"]

    # 9. 목표 발음과 음성 인식 결과 비교
    audio_match = check_target_match(
        recognized_text=recognized_text,
        target_char=target_char
    )

    # 10. 피드백 생성
    feedback = generate_feedback(
        lip_result=lip_result,
        audio_result=audio_result,
        audio_match=audio_match,
        target_char=target_char,
        recognized_text=recognized_text
    )

    if lip_failed:
        feedback.insert(
            0,
            "입모양 분석에 실패했습니다. 얼굴을 정면에 두고 입이 잘 보이도록 다시 촬영해 주세요."
        )

    # 11. 결과 저장
    save_lip_score(lip_result)

    save_final_result(
        target_char=target_char,
        audio_result=audio_result,
        lip_result=lip_result,
        whisper_result=whisper_result,
        audio_match=audio_match,
        feedback=feedback,
        video_path=video_path,
        video_result=video_result,
        lip_failed=lip_failed
    )

    print("분석 완료")
    print("영상 처리 결과:", video_result)
    print("최종 결과 파일: final_result.json")
    print("입모양 점수 파일: lip_score.json")
    print("음성 분석 파일: audio_score.txt")


if __name__ == "__main__":
    main()