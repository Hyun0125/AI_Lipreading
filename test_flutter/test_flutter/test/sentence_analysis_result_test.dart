import 'package:flutter_test/flutter_test.dart';
import 'package:test_flutter/models/sentence_analysis_result.dart';

void main() {
  test('문장 음성 인식 결과를 자르거나 점수로 바꾸지 않는다', () {
    final result = SentenceAnalysisResult.fromJson({
      'category': '문장',
      'target_item': '오늘은 날씨가 좋아요.',
      'whisper_result': '오늘은 날씨가 좋아요.',
      'audio_total_score': null,
      'visual_total_score': null,
      'voice_analysis': {
        'recognized_text': '오늘은 날씨가 좋아요.',
        'text_comparison': {
          'normalized_match': true,
          'character_similarity_percent': 100,
        },
      },
    });
    expect(result.referenceText, '오늘은 날씨가 좋아요.');
    expect(result.recognizedText, '오늘은 날씨가 좋아요.');
    expect(result.normalizedMatch, true);
    expect(result.characterSimilarityPercent, 100.0);
  });

  test('voice_analysis가 없는 응답은 문장 분석 완료로 처리하지 않는다', () {
    expect(() => SentenceAnalysisResult.fromJson({
      'category': '문장',
      'target_item': '안녕하세요',
    }), throwsFormatException);
  });
}
