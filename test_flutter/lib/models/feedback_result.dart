class FeedbackResult {
  final int? id;
  final int? userId;

  final String category;
  final String targetItem;
  final String videoPath;
  final String createdAt;

  // 기본 정보
  final String targetPronunciation;
  final String whisperResult;
  final bool isCorrect;

  // Librosa 음성 분석
  final double speechStartTime;
  final double speechEndTime;
  final double speechDuration;
  final double volume;
  final double energyChange;
  final double averagePitch;
  final double pitchChange;

  // Librosa 음성 평가 점수
  final double speedScore;
  final double durationScore;
  final double stabilityScore;
  final double pitchScore;
  final double volumeScore;
  final double audioTotalScore;

  // 입모양 분석 점수
  final double averageMouthOpenRatio;
  final double maxMouthOpenRatio;
  final double minMouthOpenRatio;
  final double lipMovementChange;
  final double averageMouthOpenScore;
  final double maxMouthOpenScore;
  final double lipMovementScore;
  final double visualTotalScore;

  // 피드백
  final List<String> feedbacks;

  const FeedbackResult({
    this.id,
    this.userId,
    required this.category,
    required this.targetItem,
    required this.videoPath,
    required this.createdAt,

    required this.targetPronunciation,
    required this.whisperResult,
    required this.isCorrect,

    required this.speechStartTime,
    required this.speechEndTime,
    required this.speechDuration,
    required this.volume,
    required this.energyChange,
    required this.averagePitch,
    required this.pitchChange,

    required this.speedScore,
    required this.durationScore,
    required this.stabilityScore,
    required this.pitchScore,
    required this.volumeScore,
    required this.audioTotalScore,

    required this.averageMouthOpenRatio,
    required this.maxMouthOpenRatio,
    required this.minMouthOpenRatio,
    required this.lipMovementChange,
    required this.averageMouthOpenScore,
    required this.maxMouthOpenScore,
    required this.lipMovementScore,
    required this.visualTotalScore,

    required this.feedbacks,
  });

  factory FeedbackResult.fromJson(Map<String, dynamic> json) {
    return FeedbackResult(
      id: json['id'] as int?,
      userId: json['user_id'] as int?,

      category: json['category']?.toString() ?? '',
      targetItem: json['target_item']?.toString() ?? '',
      videoPath: json['video_path']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',

      targetPronunciation:
      json['target_pronunciation']?.toString() ??
          json['target_item']?.toString() ??
          '',
      whisperResult: json['whisper_result']?.toString() ?? '',
      isCorrect: json['is_correct'] as bool? ?? false,

      speechStartTime:
      (json['speech_start_time'] as num?)?.toDouble() ?? 0.0,
      speechEndTime:
      (json['speech_end_time'] as num?)?.toDouble() ?? 0.0,
      speechDuration:
      (json['speech_duration'] as num?)?.toDouble() ?? 0.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
      energyChange: (json['energy_change'] as num?)?.toDouble() ?? 0.0,
      averagePitch: (json['average_pitch'] as num?)?.toDouble() ?? 0.0,
      pitchChange: (json['pitch_change'] as num?)?.toDouble() ?? 0.0,

      speedScore: (json['speed_score'] as num?)?.toDouble() ?? 0.0,
      durationScore: (json['duration_score'] as num?)?.toDouble() ?? 0.0,
      stabilityScore: (json['stability_score'] as num?)?.toDouble() ?? 0.0,
      pitchScore: (json['pitch_score'] as num?)?.toDouble() ?? 0.0,
      volumeScore: (json['volume_score'] as num?)?.toDouble() ?? 0.0,
      audioTotalScore:
      (json['audio_total_score'] as num?)?.toDouble() ??
          (json['audio_score'] as num?)?.toDouble() ??
          0.0,

      averageMouthOpenRatio:
      (json['average_mouth_open_ratio'] as num?)?.toDouble() ?? 0.0,
      maxMouthOpenRatio:
      (json['max_mouth_open_ratio'] as num?)?.toDouble() ?? 0.0,
      minMouthOpenRatio:
      (json['min_mouth_open_ratio'] as num?)?.toDouble() ?? 0.0,
      lipMovementChange:
      (json['lip_movement_change'] as num?)?.toDouble() ?? 0.0,
      averageMouthOpenScore:
      (json['average_mouth_open_score'] as num?)?.toDouble() ?? 0.0,
      maxMouthOpenScore:
      (json['max_mouth_open_score'] as num?)?.toDouble() ?? 0.0,
      lipMovementScore:
      (json['lip_movement_score'] as num?)?.toDouble() ?? 0.0,
      visualTotalScore:
      (json['visual_total_score'] as num?)?.toDouble() ??
          (json['visual_score'] as num?)?.toDouble() ??
          0.0,

      feedbacks: json['feedbacks'] is List
          ? List<String>.from(json['feedbacks'])
          : [
        if (json['audio_feedback'] != null)
          json['audio_feedback'].toString(),
        if (json['visual_feedback'] != null)
          json['visual_feedback'].toString(),
      ],
    );
  }
}