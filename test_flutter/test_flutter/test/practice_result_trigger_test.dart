import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_flutter/models/feedback_result.dart';
import 'package:test_flutter/screens/feedback_screen.dart';
import 'package:test_flutter/services/demo_scenarios.dart';
import 'package:test_flutter/services/learning_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoScenarios.select(DemoScenario.off);
  });
  tearDown(() async => DemoScenarios.select(DemoScenario.off));

  FeedbackResult result() => FeedbackResult.fromJson({
    'category': '모음',
    'target_item': 'ㅏ',
    'target_pronunciation': 'ㅏ',
    'feedbacks': ['발화 구간을 확인했습니다.'],
    'audio_total_score': 72,
    'visual_total_score': 74,
    'created_at': '2026-10-15T15:00:00',
  });

  testWidgets('analyzed feedback display records one practiced phoneme',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: FeedbackResultScreen(
      result: result(), recordPracticeOnDisplay: true,
    )));
    await tester.pumpAndSettle();
    expect(await LearningProgress.read(), {'ㅏ'});
    expect((await LearningProgress.readActivities())
        .where((item) => item.type == 'practiced').length, 1);
  });

  testWidgets('opening a stored result without analysis does not count',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: FeedbackResultScreen(
      result: result(),
    )));
    await tester.pumpAndSettle();
    expect(await LearningProgress.read(), isEmpty);
  });
}
