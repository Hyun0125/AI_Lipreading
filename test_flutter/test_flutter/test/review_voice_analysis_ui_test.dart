
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:test_flutter/models/feedback_result.dart';
import 'package:test_flutter/screens/review_result_detail_screen.dart';

void main() {
  testWidgets('복습 화면에서 저장된 AI 음성 분석 결과가 표시된다', (tester) async {
    // 서버에서 다시 조회한 데이터를 가정한 샘플 JSON
    final json = <String, dynamic>{
      'id': 100,
      'category': '모음',
      'target_item': 'ㅏ',
      'target_pronunciation': '아',
      'whisper_result': '아',
      'feedbacks': <String>[],
      'voice_analysis': {
        'schema_version': 1,
        'recognized_text': '아',
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

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewResultDetailScreen(result: result),
      ),
    );

    await tester.pumpAndSettle();

    // 기존 음성 탭으로 이동
    await tester.tap(find.text('음성'));
    await tester.pumpAndSettle();

    // 새 AI 분석 카드 확인
    await tester.scrollUntilVisible(
      find.text('AI 음성 분석 정보'),
      200,
    );

    expect(find.text('AI 음성 분석 정보'), findsOneWidget);

    // 평균 음높이 확인
    await tester.scrollUntilVisible(
      find.text('229.39 Hz'),
      150,
    );

    expect(find.text('229.39 Hz'), findsOneWidget);
  });

  testWidgets('기존 복습 기록도 오류 없이 표시된다', (tester) async {
    final result = FeedbackResult.fromJson({
      'id': 101,
      'category': '자음',
      'target_item': 'ㄱ',
      'target_pronunciation': '가',
      'whisper_result': '가',
      'feedbacks': <String>[],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ReviewResultDetailScreen(result: result),
      ),
    );

    await tester.pumpAndSettle();

    // 기존 음성 탭 선택
    await tester.tap(find.text('음성'));
    await tester.pumpAndSettle();

    // 기존 음성 분석 화면은 표시되어야 함
    expect(find.text('음성 세부 분석'), findsOneWidget);

    // 새 AI 분석 데이터가 없으므로 새 카드는 표시되지 않음
    expect(find.text('AI 음성 분석 정보'), findsNothing);

    // 화면 오류 여부 확인
    expect(tester.takeException(), isNull);
  });
}
