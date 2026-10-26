// 피드백 결과 데이터 모델

import 'voice_analysis_result.dart';

// 서버에서 분석한 음성 피드백, 입모양 피드백, 점수, 영상 경로 등을
// Flutter 화면에서 사용하기 위해 저장하는 클래스
class FeedbackResult {
  final int? id; // DB에 저장된 피드백 기록 id
  final int? userId; // 사용자 id
  final String category; // 학습 종류
  final String targetItem; // 학습 항목

  final String tempVideoPath;  // analyze 단계에서 사용하는 임시 영상 경로
  final String videoPath; // save 단계 또는 DB 조회 단계에서 사용하는 영상 경로

  final String createdAt; // 피드백 생성 날짜

  // 문자열을 최대 글자 수만큼 자르는 함수
  // Whisper 인식 결과가 너무 길게 표시되지 않도록 4글자까지만 사용한다.
  static String _limitTextLength(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return text.substring(0, maxLength);
  }

  // 기본 정보
  final String targetPronunciation; // 목표 발음
  final String whisperResult; // Whisper가 인식한 발음 결과
  final bool isCorrect; // 목표 발음과 인식 결과의 일치 여부

  // 음성 세부 분석
  final double speechStartTime; // 발화 시작 시간
  final double speechEndTime; // 발화 종료 시간
  final double speechDuration; // 발화 길이
  final double volume; // 음량
  final double energyChange; // 에너지 변화량
  final double averagePitch; // 평균 높낮이
  final double pitchChange; // 높낮이 변화량

  // 음성 점수
  final double speedScore; // 발음 속도 점수
  final double durationScore; // 발화 길이 점수
  final double stabilityScore; // 안정성 점수
  final double pitchScore; // 높낮이 점수
  final double volumeScore; // 음량 점수
  final double audioTotalScore; // 음성 평가 최종 점수

  // 입모양 세부 분석
  final double averageMouthOpenRatio; // 평균 입 벌림 비율
  final double maxMouthOpenRatio; // 최대 입 벌림 비율
  final double minMouthOpenRatio; // 최소 입 벌림 비율
  final double lipMovementChange; // 입술 움직임 변화량

  // 입모양 점수
  final double averageMouthOpenScore; // 평균 입 벌림 점수
  final double maxMouthOpenScore; // 최대 입 벌림 점수
  final double lipMovementScore; // 입술 움직임 점수
  final double visualTotalScore; // 입모양 평가 최종 점수

  // 피드백
  final List<String> feedbacks; // 종합 피드백 문장 목록
  final VoiceAnalysisResult? voiceAnalysis; // 음성 분석 상세 데이터

  const FeedbackResult({
    this.id,
    this.userId,
    required this.category,
    required this.targetItem,
    required this.tempVideoPath,
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
    this.voiceAnalysis,
  });

  // JSON 데이터를 FeedbackResult 객체로 변환하는 함수
  // 서버에서 받은 snake_case 데이터를 Flutter에서 사용하는 camelCase 필드에 맞춰 저장한다.
  factory FeedbackResult.fromJson(Map<String, dynamic> json) {
    final String tempPath = json['temp_video_path']?.toString() ?? ''; //분석용 임시 영상 경로
    final String savedPath = json['video_path']?.toString() ?? ''; //저장 완료 후 또는 복습모드에서 조회할 때 사용하는 최종 영상 경로

    return FeedbackResult(
      id: json['id'] as int?,
      userId: json['user_id'] as int?,

      category: json['category']?.toString() ?? '',
      targetItem: json['target_item']?.toString() ?? '',

      tempVideoPath: tempPath,
      videoPath: savedPath.isNotEmpty ? savedPath : tempPath,

      createdAt: json['created_at']?.toString() ?? '',

      targetPronunciation:
      json['target_pronunciation']?.toString() ??
          json['target_item']?.toString() ??
          '',

      whisperResult: (() {
        final category = json['category']?.toString() ?? '';
        final voiceData = json['voice_analysis'];

        final recognizedText = voiceData is Map &&
            (voiceData['recognized_text']?.toString().isNotEmpty ?? false)
            ? voiceData['recognized_text'].toString()
            : json['whisper_result']?.toString() ?? '';

        if (category == '자음' || category == '모음') {
          return _limitTextLength(recognizedText, 4);
        }

        return recognizedText;
      })(),
      isCorrect: json['is_correct'] as bool? ?? false,

      speechStartTime: (json['speech_start_time'] as num?)?.toDouble() ?? 0.0,
      speechEndTime: (json['speech_end_time'] as num?)?.toDouble() ?? 0.0,
      speechDuration: (json['speech_duration'] as num?)?.toDouble() ?? 0.0,
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
        if (json['feedback_text'] != null)
          json['feedback_text'].toString(),
        if (json['audio_feedback'] != null)
          json['audio_feedback'].toString(),
        if (json['visual_feedback'] != null)
          json['visual_feedback'].toString(),
        if (json['feedback'] != null)
          json['feedback'].toString(),
      ],

      voiceAnalysis: json['voice_analysis'] is Map
          ? VoiceAnalysisResult.fromJson(
        Map<String, dynamic>.from(
          json['voice_analysis'] as Map,
        ),
      )
          : null,
    );
  }

  // FeedbackResult 객체를 저장 요청용 JSON으로 변환하는 함수
  // /feedback/save 요청에서 서버가 요구하는 key 이름에 맞춰 데이터를 구성한다.
  Map<String, dynamic> toSaveJson({
    required int? userId,
  }) {
    final String pathForSave = videoPath.isNotEmpty ? videoPath : tempVideoPath;

    return {
      'user_id': userId,

      'category': category,
      'target_item': targetItem,

      // save 요청에서는 temp_video_path가 아니라 video_path로 보내야 한다.
      'video_path': pathForSave,

      'created_at': createdAt,

      'target_pronunciation': targetPronunciation,
      'whisper_result': whisperResult,
      'is_correct': isCorrect,
      'speech_start_time': speechStartTime,
      'speech_end_time': speechEndTime,
      'speech_duration': speechDuration,
      'volume': volume,
      'energy_change': energyChange,
      'average_pitch': averagePitch,
      'pitch_change': pitchChange,

      'speed_score': speedScore,
      'duration_score': durationScore,
      'stability_score': stabilityScore,
      'pitch_score': pitchScore,
      'volume_score': volumeScore,
      'audio_total_score': audioTotalScore,

      'average_mouth_open_ratio': averageMouthOpenRatio,
      'max_mouth_open_ratio': maxMouthOpenRatio,
      'min_mouth_open_ratio': minMouthOpenRatio,
      'lip_movement_change': lipMovementChange,

      'average_mouth_open_score': averageMouthOpenScore,
      'max_mouth_open_score': maxMouthOpenScore,
      'lip_movement_score': lipMovementScore,
      'visual_total_score': visualTotalScore,

      'feedbacks': feedbacks,
      'feedback_text': feedbacks.join('\n'),
      'voice_analysis': voiceAnalysis?.toJson(),
    };
  }
}