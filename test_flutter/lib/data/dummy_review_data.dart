import '../models/feedback_result.dart';

final Map<String, List<FeedbackResult>> dummyReviewData = {
  'ㄱ': [
    FeedbackResult(
      id: 4,
      category: '자음',
      targetItem: 'ㄱ',
      videoPath: 'uploads/videos/sample_ㄱ_4.mp4',
      createdAt: '2026-04-07',

      targetPronunciation: '우',
      whisperResult: '응',
      isCorrect: false,

      speechStartTime: 0.992,
      speechEndTime: 1.376,
      speechDuration: 0.384,
      volume: 0.08998,
      energyChange: 0.05994,
      averagePitch: 127.29,
      pitchChange: 26.0,

      speedScore: 56.88,
      durationScore: 63.04,
      stabilityScore: 60.06,
      pitchScore: 93.99,
      volumeScore: 60.02,
      audioTotalScore: 67.48,

      averageMouthOpenRatio: 0.9480,
      maxMouthOpenRatio: 1.1818,
      minMouthOpenRatio: 0.7477,
      lipMovementChange: 0.4342,
      averageMouthOpenScore: 94.52,
      maxMouthOpenScore: 81.82,
      lipMovementScore: 63.64,
      visualTotalScore: 81.45,

      feedbacks: [
        '입을 벌리는 정도를 조금 더 목표 발음에 맞춰보세요.',
        '발음할 때 입 모양 변화가 부족합니다.',
        '발음 속도가 적절하지 않습니다. 너무 빠르거나 느리지 않게 발음해보세요.',
        '발화 시간이 적절하지 않습니다. 발음을 너무 짧게 끊거나 너무 길게 늘이지 않도록 해보세요.',
        '발화 중 음량 변화가 불안정합니다. 일정한 크기로 발음해보세요.',
        '음성이 너무 작거나 크게 입력되었습니다. 적절한 크기로 또렷하게 발음해 주세요.',
        "Whisper 음성 인식 결과는 '응'로 나왔습니다. 목표 발음 '우'와 다르게 인식되었지만, 한 글자 발음은 음성 인식이 오인식할 수 있으므로 입모양 점수와 함께 확인해야 합니다.",
      ],
    ),

    FeedbackResult(
      id: 3,
      category: '자음',
      targetItem: 'ㄱ',
      videoPath: 'uploads/videos/sample_ㄱ_3.mp4',
      createdAt: '2026-04-06',

      targetPronunciation: '가',
      whisperResult: '가',
      isCorrect: true,

      speechStartTime: 0.812,
      speechEndTime: 1.420,
      speechDuration: 0.608,
      volume: 0.10231,
      energyChange: 0.04122,
      averagePitch: 132.40,
      pitchChange: 18.0,

      speedScore: 78.0,
      durationScore: 82.5,
      stabilityScore: 74.0,
      pitchScore: 88.0,
      volumeScore: 80.0,
      audioTotalScore: 80.5,

      averageMouthOpenRatio: 0.8821,
      maxMouthOpenRatio: 1.0324,
      minMouthOpenRatio: 0.6120,
      lipMovementChange: 0.5123,
      averageMouthOpenScore: 86.0,
      maxMouthOpenScore: 83.5,
      lipMovementScore: 78.0,
      visualTotalScore: 82.5,

      feedbacks: [
        '목표 발음과 음성 인식 결과가 일치합니다.',
        '입 모양은 비교적 안정적입니다.',
        '발화 길이가 적절합니다.',
        '조금 더 또렷하게 발음하면 더 좋은 점수를 받을 수 있습니다.',
      ],
    ),

    FeedbackResult(
      id: 2,
      category: '자음',
      targetItem: 'ㄱ',
      videoPath: 'uploads/videos/sample_ㄱ_2.mp4',
      createdAt: '2026-04-03',

      targetPronunciation: '가',
      whisperResult: '카',
      isCorrect: false,

      speechStartTime: 0.744,
      speechEndTime: 1.118,
      speechDuration: 0.374,
      volume: 0.06741,
      energyChange: 0.07102,
      averagePitch: 121.34,
      pitchChange: 30.0,

      speedScore: 60.0,
      durationScore: 58.0,
      stabilityScore: 63.0,
      pitchScore: 84.0,
      volumeScore: 61.0,
      audioTotalScore: 65.2,

      averageMouthOpenRatio: 0.7132,
      maxMouthOpenRatio: 0.9123,
      minMouthOpenRatio: 0.4880,
      lipMovementChange: 0.3220,
      averageMouthOpenScore: 72.0,
      maxMouthOpenScore: 69.0,
      lipMovementScore: 62.0,
      visualTotalScore: 67.6,

      feedbacks: [
        "Whisper 음성 인식 결과는 '카'로 나왔습니다.",
        '숨이 강하게 나와 ㄱ보다 ㅋ에 가깝게 인식될 수 있습니다.',
        '입 모양 변화가 다소 부족합니다.',
        '목에 힘을 빼고 부드럽게 발음해보세요.',
      ],
    ),
  ],
};