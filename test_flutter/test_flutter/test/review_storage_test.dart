import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_flutter/services/demo_scenarios.dart';
import 'package:test_flutter/services/learning_progress.dart';
import 'package:test_flutter/services/review_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoScenarios.select(DemoScenario.off);
  });

  test('review queue persists independently from practice progress', () async {
    await ReviewQueue.setIncluded('ㄱ', true);
    await ReviewQueue.setIncluded('ㅏ', true);
    expect(await ReviewQueue.read(), {'ㄱ', 'ㅏ'});
    expect(await LearningProgress.read(), isEmpty);
    await ReviewQueue.setIncluded('ㄱ', false);
    expect(await ReviewQueue.read(), {'ㅏ'});
  });

  test('practice is unique per phoneme, attempts are logged each time', () async {
    expect(await LearningProgress.read(), isEmpty);
    expect(await LearningProgress.recordSuccessfulPractice(
      phoneme: 'ㅏ', category: '모음'), isTrue);
    expect(await LearningProgress.recordSuccessfulPractice(
      phoneme: 'ㅏ', category: '모음'), isFalse);
    expect(await LearningProgress.recordSuccessfulPractice(
      phoneme: 'ㄱ', category: '자음'), isTrue);
    expect(await LearningProgress.read(), {'ㅏ', 'ㄱ'});
    expect((await LearningProgress.readActivities())
      .where((e) => e.type == 'practiced').length, 3);
    expect(await ReviewQueue.read(), isEmpty);
  });

  test('successful practice automatically completes queued review once per day', () async {
    await ReviewQueue.setIncluded('ㅏ', true);
    expect(await ReviewQueue.reviewedToday(), isEmpty);
    await LearningProgress.recordSuccessfulPractice(phoneme: 'ㅏ', category: '모음');
    expect(await ReviewQueue.reviewedToday(), {'ㅏ'});
    final afterFirst = await LearningProgress.readActivities();
    expect(afterFirst.where((a) => a.type == 'reviewed').length, 1);
    await LearningProgress.recordSuccessfulPractice(phoneme: 'ㅏ', category: '모음');
    final afterSecond = await LearningProgress.readActivities();
    expect(afterSecond.where((a) => a.type == 'practiced').length, 2);
    expect(afterSecond.where((a) => a.type == 'reviewed').length, 1);
    expect(await LearningProgress.read(), {'ㅏ'});
  });

  test('old manual review completion is not treated as automatic completion', () async {
    final today = DateTime.now();
    final date = '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues({
      'daily_review_checks_v1': ['$date|ㄱ'],
    });
    await ReviewQueue.setIncluded('ㄱ', true);
    expect(await ReviewQueue.reviewedToday(), isEmpty);
    await LearningProgress.recordSuccessfulPractice(phoneme: 'ㄱ', category: '자음');
    expect(await ReviewQueue.reviewedToday(), {'ㄱ'});
  });

  test('practice outside review queue does not complete any daily review', () async {
    await ReviewQueue.setIncluded('ㄱ', true);
    await LearningProgress.recordSuccessfulPractice(phoneme: 'ㅏ', category: '모음');
    expect(await ReviewQueue.reviewedToday(), isEmpty);
  });

  test('demo B exposes dated practice activities for history and calendar', () async {
    await DemoScenarios.select(DemoScenario.studied);
    final activities = await LearningProgress.readActivities();
    expect(activities.where((a) => a.type == 'practiced').length, 6);
    expect(activities.map((a) => a.phoneme).toSet(), {'ㅏ', 'ㅓ', 'ㄱ', 'ㅗ', 'ㅁ'});
    expect(await LearningProgress.read(), {'ㅏ', 'ㅓ', 'ㄱ', 'ㅗ', 'ㅁ'});
    expect(activities.where((a) => a.phoneme == 'ㅓ').length, 2); // 반복해도 5/40
  });

  test('demo C successful queued review marks today, not other queue items', () async {
    await DemoScenarios.select(DemoScenario.reviewing);
    expect(await ReviewQueue.reviewedToday(), {'ㅓ'});
    await LearningProgress.recordSuccessfulPractice(phoneme: 'ㄱ', category: '자음');
    expect(await ReviewQueue.reviewedToday(), {'ㄱ', 'ㅓ'});
    expect(await LearningProgress.read(), contains('ㄱ'));
  });

  test('invalid or not-yet-supported category never counts', () async {
    for (final pair in [('단어', '사과'), ('문장', '안녕하세요'),
      ('자음', 'ㅏ'), ('모음', 'ㄱ')]) {
      expect(await LearningProgress.recordSuccessfulPractice(
        category: pair.$1, phoneme: pair.$2), isFalse);
    }
    expect(await LearningProgress.read(), isEmpty);
    expect(await LearningProgress.readActivities(), isEmpty);
    expect(LearningProgress.totalPhonemes, 40);
    expect(LearningProgress.consonants.length, 19);
    expect(LearningProgress.vowels.length, 21);
  });

  test('old manual-completion preference is not interpreted as practice', () async {
    SharedPreferences.setMockInitialValues({
      'completed_phonemes_v3': ['ㅏ', 'ㄱ'],
      'learning_activities_v1': ['{"phoneme":"ㅏ","type":"studied","at":"2026-10-01T10:00:00"}'],
    });
    expect(await LearningProgress.read(), isEmpty);
    expect(await LearningProgress.readActivities(), isEmpty);
  });

  test('reset only clears progress, retaining dates and review markers', () async {
    await LearningProgress.recordSuccessfulPractice(phoneme: 'ㅏ', category: '모음');
    await ReviewQueue.setIncluded('ㅏ', true);
    await ReviewQueue.setReviewedToday('ㅏ', true);
    await LearningProgress.recordReview('ㅏ');
    final before = await LearningProgress.readActivities();
    expect(before.length, 2);
    await LearningProgress.resetProgress();
    expect(await LearningProgress.read(), isEmpty);
    expect((await LearningProgress.readActivities()).length, 2);
    expect((await ReviewQueue.reviewedToday()).contains('ㅏ'), isTrue);
    await LearningProgress.recordSuccessfulPractice(phoneme: 'ㅏ', category: '모음');
    expect(await LearningProgress.read(), {'ㅏ'});
    expect((await LearningProgress.readActivities()).length, 3);
  });
}
