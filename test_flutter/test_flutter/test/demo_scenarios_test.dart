import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_flutter/services/demo_scenarios.dart';
import 'package:test_flutter/services/feedback_api.dart';
import 'package:test_flutter/services/learning_progress.dart';
import 'package:test_flutter/services/review_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'intro_seen_v1': true});
    await DemoScenarios.select(DemoScenario.off);
  });
  tearDown(() async => DemoScenarios.select(DemoScenario.off));

  test('switching A/B/C never overwrites real practice history', () async {
    await LearningProgress.recordSuccessfulPractice(phoneme: 'ㅣ', category: '모음');
    await ReviewQueue.setIncluded('ㄴ', true);

    await DemoScenarios.select(DemoScenario.firstLaunch);
    expect(await LearningProgress.read(), isEmpty);
    expect(await ReviewQueue.read(), isEmpty);
    expect(await LearningProgress.readActivities(), isEmpty);

    await DemoScenarios.select(DemoScenario.studied);
    expect(await LearningProgress.read(), {'ㅏ', 'ㅓ', 'ㅗ', 'ㄱ', 'ㅁ'});
    expect((await LearningProgress.readActivities()).length, 5);
    expect(await LearningProgress.recordSuccessfulPractice(
      phoneme: 'ㅐ', category: '모음'), isTrue);
    expect((await LearningProgress.read()).contains('ㅐ'), isTrue);
    expect((await LearningProgress.readActivities()).length, 6);

    await DemoScenarios.select(DemoScenario.reviewing);
    expect(await ReviewQueue.read(), {'ㄱ', 'ㅓ', 'ㅜ'});
    expect(await ReviewQueue.reviewedToday(), {'ㅓ'});
    expect((await FeedbackApi.getAllReviewResults()).length, 2);
    expect((await FeedbackApi.getAllReviewResults()).every(
      (item) => item.id != null && item.id! < 0), isTrue);
    await ReviewQueue.setIncluded('ㅋ', true);
    expect((await ReviewQueue.read()).contains('ㅋ'), isTrue);

    await DemoScenarios.select(DemoScenario.off);
    expect(await LearningProgress.read(), {'ㅣ'});
    expect(await ReviewQueue.read(), {'ㄴ'});
    expect((await LearningProgress.readActivities()).length, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('intro_seen_v1'), true);
  });

  test('reselecting a demo profile resets only its own progress', () async {
    await DemoScenarios.select(DemoScenario.studied);
    await LearningProgress.recordSuccessfulPractice(phoneme: 'ㅐ', category: '모음');
    expect((await LearningProgress.read()).contains('ㅐ'), isTrue);
    await DemoScenarios.select(DemoScenario.studied);
    expect((await LearningProgress.read()).contains('ㅐ'), isFalse);
  });

  test('demo result saves to session only, never real backend', () async {
    await DemoScenarios.select(DemoScenario.reviewing);
    final sample = (await FeedbackApi.getAllReviewResults()).first;
    await FeedbackApi.saveFeedbackResult(result: sample, userId: null);
    expect((await FeedbackApi.getAllReviewResults()).length, 3);
    await DemoScenarios.select(DemoScenario.reviewing);
    expect((await FeedbackApi.getAllReviewResults()).length, 2);
  });
}
