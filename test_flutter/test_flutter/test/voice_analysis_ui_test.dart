
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test_flutter/models/feedback_result.dart';
import 'package:test_flutter/screens/feedback_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('새 AI 음성 분석 결과가 음성 탭에 표시된다', (tester) async {
    // 1. AI 서버 응답을 대신할 샘플 JSON
    final json = <String, dynamic>{
      'category': '모음',
      'target_item': 'ㅏ',
      'target_pronunciation': '아',
      'whisper_result': '아',
      'feedbacks': ['음성 분석 테스트입니다.'],
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

    // 2. JSON을 기존 FeedbackResult로 변환
    final result = FeedbackResult.fromJson(json);

    // 3. 기존 v7 결과 화면 실행
    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackResultScreen(
          result: result,
          recordPracticeOnDisplay: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 4. 기존 '음성' 탭 선택
    await tester.tap(find.text('음성'));
    await tester.pumpAndSettle();

    // 5. 새 음성 분석 카드 확인
    await tester.scrollUntilVisible(
      find.text('AI 음성 분석 정보'),
      200,
    );

    expect(
      find.text('AI 음성 분석 정보'),
      findsOneWidget,
    );

    // 6. 실제 분석 수치 표시 확인
    await tester.scrollUntilVisible(
      find.text('6.12 초'),
      150,
    );

    expect(find.text('6.12 초'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('229.39 Hz'),
      150,
    );

    expect(find.text('229.39 Hz'), findsOneWidget);
  });
}