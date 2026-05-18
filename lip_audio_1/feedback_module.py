def generate_feedback(
    lip_result,
    audio_result,
    audio_match,
    target_char,
    recognized_text
):
    """
    입모양 분석 결과, Librosa 음성 분석 결과, Whisper 인식 결과를 바탕으로
    사용자에게 제공할 피드백 문장을 생성한다.
    """

    feedback = []

    # -----------------------------
    # 1. 입모양 분석 피드백
    # -----------------------------

    avg_score = lip_result["avg_score"]
    max_score = lip_result["max_score"]
    movement_score = lip_result["movement_score"]
    lip_final_score = lip_result["final_score"]

    if "error" in lip_result:
        feedback.append(
            "입술 좌표가 충분히 추출되지 않아 입모양 점수를 정확히 계산하기 어렵습니다. "
            "얼굴을 정면으로 두고 입이 잘 보이도록 다시 촬영해 주세요."
        )
    else:
        # 평균 입 벌림 피드백
        if avg_score < 70:
            feedback.append("전체적인 입 벌림 정도가 목표 발음과 차이가 큽니다.")
        elif avg_score < 85:
            feedback.append("입 벌림 정도를 목표 발음에 조금 더 가깝게 조절해보세요.")

        # 최대 입 벌림 피드백
        if max_score < 70:
            feedback.append("입을 가장 크게 벌리는 순간이 부족합니다.")
        elif max_score < 85:
            feedback.append("입을 벌리는 정도를 조금 더 목표 발음에 맞춰보세요.")

        # 입술 움직임 피드백
        if movement_score < 70:
            feedback.append("발음할 때 입 모양 변화가 부족합니다.")
        elif movement_score < 85:
            feedback.append("입 모양 변화가 조금 더 자연스럽게 이어지면 좋습니다.")

    # -----------------------------
    # 2. Librosa 음성 평가 피드백
    # -----------------------------

    speed_score = audio_result["speed_score"]
    duration_score = audio_result["duration_score"]
    stability_score = audio_result["stability_score"]
    pitch_score = audio_result["pitch_score"]
    volume_score = audio_result["volume_score"]
    audio_final_score = audio_result["final_audio_score"]

    # 속도 피드백
    if speed_score < 70:
        feedback.append("발음 속도가 적절하지 않습니다. 너무 빠르거나 느리지 않게 발음해보세요.")
    elif speed_score < 85:
        feedback.append("발음 속도를 조금 더 일정하게 조절해보세요.")

    # 길이 피드백
    if duration_score < 70:
        feedback.append("발화 시간이 적절하지 않습니다. 발음을 너무 짧게 끊거나 너무 길게 늘이지 않도록 해보세요.")
    elif duration_score < 85:
        feedback.append("목표 발음을 조금 더 자연스러운 길이로 유지해보세요.")

    # 안정성 피드백
    if stability_score < 70:
        feedback.append("발화 중 음량 변화가 불안정합니다. 일정한 크기로 발음해보세요.")
    elif stability_score < 85:
        feedback.append("발화가 조금 더 안정적으로 유지되면 좋습니다.")

    # 높낮이 피드백
    if pitch_score < 70:
        feedback.append("높낮이 변화가 부자연스럽게 나타났습니다. 너무 높거나 낮게 흔들리지 않도록 발음해보세요.")
    elif pitch_score < 85:
        feedback.append("높낮이를 조금 더 자연스럽게 유지해보세요.")

    # 음량 피드백
    if volume_score < 70:
        feedback.append("음성이 너무 작거나 크게 입력되었습니다. 적절한 크기로 또렷하게 발음해 주세요.")
    elif volume_score < 85:
        feedback.append("음량을 조금 더 일정하고 또렷하게 유지해보세요.")

    # -----------------------------
    # 3. Whisper 음성 인식 피드백
    # -----------------------------

    if not audio_match:
        feedback.append(
            f"Whisper 음성 인식 결과는 '{recognized_text}'로 나왔습니다. "
            f"목표 발음 '{target_char}'와 다르게 인식되었지만, "
            "한 글자 발음은 음성 인식이 오인식할 수 있으므로 입모양 점수와 함께 확인해야 합니다."
        )

    # -----------------------------
    # 4. 전체 평가 피드백
    # -----------------------------

    if lip_final_score >= 90 and audio_final_score >= 90 and audio_match:
        feedback.append("입모양, 음성 특성, 음성 인식 결과가 모두 목표 발음에 가깝습니다.")
    elif lip_final_score >= 90 and audio_final_score >= 90:
        feedback.append("입모양과 음성 특성은 전반적으로 좋지만, 음성 인식 결과는 다르게 나타났습니다.")
    elif lip_final_score >= 90:
        feedback.append("입모양은 목표 발음에 매우 가깝습니다.")
    elif audio_final_score >= 90:
        feedback.append("음성의 속도, 길이, 안정성, 높낮이, 음량은 전반적으로 양호합니다.")

    # -----------------------------
    # 5. 피드백이 없을 경우 기본 문장
    # -----------------------------

    if len(feedback) == 0:
        feedback.append("전체적으로 양호합니다. 조금 더 또렷하고 자연스럽게 발음해보세요.")

    return feedback