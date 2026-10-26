import 'package:flutter_test/flutter_test.dart';
import 'package:test_flutter/models/feedback_result.dart';

void main() {
  test('새 AI 분석 JSON을 정상적으로 읽는다', () {
    final json = <String, dynamic>{
      'category': '문장',
      'target_item': '문장 진단',
      'whisper_result': '혼자 이명시험 준비를 하려니 너무 외로워',
      'voice_analysis': {
        'schema_version': 1,
        'recognized_text': '혼자 이명시험 준비를 하려니 너무 외로워',
        'text_comparison': null,
        'audio_features': {
          'duration': {
            'total_sec': 6.12,
            'speech_sec': 5.93,
            'silence_sec': 0.19,
          },
          'speech_rate': {
            'syllables_per_second': 2.87,
          },
          'volume': {
            'mean_db': -37.93,
          },
          'pitch': {
            'mean_hz': 229.39,
          },
          'pause': {
            'count': 0,
          },
          'voice': {
            'voiced_ratio_percent': 69.27,
          },
        },
      },
    };

    final result = FeedbackResult.fromJson(json);

    // 긴 문장이 잘리지 않았는지 확인
    expect(
      result.whisperResult,
      '혼자 이명시험 준비를 하려니 너무 외로워',
    );

    // 새 음성 분석 데이터 확인
    final voice = result.voiceAnalysis;
    expect(voice, isNotNull);

    expect(voice!.totalDuration, 6.12);
    expect(voice.speechDuration, 5.93);
    expect(voice.speechRate, 2.87);
    expect(voice.meanVolume, -37.93);
    expect(voice.meanPitch, 229.39);
    expect(voice.pauseCount, 0.0);
    expect(voice.voicedRatio, 69.27);
    // 저장용 JSON에 새 음성 분석 데이터가 포함되는지 확인

    final saveJson = result.toSaveJson(userId: null);

    expect(saveJson['voice_analysis'], isNotNull);

    final savedAnalysis =
    Map<String, dynamic>.from(saveJson['voice_analysis'] as Map);

    expect(savedAnalysis['recognized_text'],
        '혼자 이명시험 준비를 하려니 너무 외로워');

    final features =
    Map<String, dynamic>.from(savedAnalysis['audio_features'] as Map);

    final pitch =
    Map<String, dynamic>.from(features['pitch'] as Map);

    expect(pitch['mean_hz'], 229.39);
  });

  test('기존 서버 JSON도 정상적으로 읽는다', () {
    final result = FeedbackResult.fromJson({
      'category': '자음',
      'target_item': 'ㄱ',
      'whisper_result': '가',
    });

    expect(result.whisperResult, '가');
    expect(result.voiceAnalysis, isNull);
  });
}
