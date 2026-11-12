import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_flutter/models/feedback_result.dart';
import 'package:test_flutter/screens/calendar_day_results_screen.dart';
import 'package:test_flutter/screens/learning_calendar_screen.dart';
import 'package:test_flutter/screens/phoneme_progress_chart_screen.dart';
import 'package:test_flutter/screens/review_result_detail_screen.dart';
import 'package:test_flutter/services/demo_scenarios.dart';
import 'package:test_flutter/services/pronunciation_record_filter.dart';

FeedbackResult sample(String phoneme, String category, String timestamp,
    {int id = 1, double? audio = 72, double? visual = 81}) =>
  FeedbackResult.fromJson({
    'id': id,
    'category': category,
    'target_item': phoneme,
    'target_pronunciation': phoneme,
    'created_at': timestamp,
    'whisper_result': phoneme,
    'audio_total_score': audio,
    'visual_total_score': visual,
    'feedbacks': ['테스트 결과'],
  });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoScenarios.select(DemoScenario.off);
  });
  tearDown(() async => DemoScenarios.select(DemoScenario.off));

  test('date selection keeps both attempts of the same phoneme', () {
    final source = [
      sample('ㅏ', '모음', '2026-10-26 08:01:00', id: 1),
      sample('ㅏ', '모음', '2026-10-26 19:30:00', id: 2),
      sample('ㅏ', '모음', '2026-10-25 08:01:00', id: 3),
      sample('ㄱ', '자음', '2026-10-26 13:20:00', id: 4),
      sample('ㅏ', '문장', '2026-10-26 13:30:00', id: 5),
    ];
    final day = savedPhonemeDayHistory(source, 'ㅏ', DateTime(2026, 10, 26));
    expect(day.map((r) => r.id).toList(), [2, 1]);
    final whole = savedPhonemeHistory(source, 'ㅏ');
    expect(whole.map((r) => r.id).toList(), [2, 1, 3]);
  });

  test('date matching uses local time and invalid dates are ignored', () {
    final selected = [
      sample('ㅏ', '모음', '2026-10-26T15:00:00Z'),
      sample('ㅏ', '모음', 'not-a-date', id: 2),
    ];
    final converted = feedbackRecordedAt(selected.first)!;
    final filtered = savedPhonemeDayHistory(
      selected, 'ㅏ', DateTime(converted.year, converted.month, converted.day));
    expect(filtered.length, 1);
    expect(filtered.first.id, 1);
  });

  test('a missing score is not mislabeled as 0 points', () {
    final noScore = sample('ㅏ', '모음', '2026-10-26T13:00:00',
      audio: null, visual: null);
    final zeroScore = sample('ㅏ', '모음', '2026-10-26T14:00:00',
      id: 2, audio: 0, visual: 0);
    expect(noScore.hasAudioTotalScore, isFalse);
    expect(noScore.hasVisualTotalScore, isFalse);
    expect(zeroScore.hasAudioTotalScore, isTrue);
    expect(zeroScore.hasVisualTotalScore, isTrue);
  });

  testWidgets('day results list opens each stored result separately', (tester) async {
    final source = [
      sample('ㅏ', '모음', '2026-10-26T08:00:00', id: 1),
      sample('ㅏ', '모음', '2026-10-26T19:30:00', id: 2),
      sample('ㅏ', '모음', '2026-10-25T12:00:00', id: 3),
    ];
    await tester.pumpWidget(MaterialApp(home: CalendarDayResultsScreen(
      selectedDate: DateTime(2026, 10, 26),
      phoneme: 'ㅏ', records: source,
    )));
    expect(find.text('ㅏ · 저장된 분석 결과 2건'), findsOneWidget);
    expect(find.byKey(const Key('calendar_saved_result_0')), findsOneWidget);
    expect(find.byKey(const Key('calendar_saved_result_1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('calendar_saved_result_0')));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewResultDetailScreen), findsOneWidget);
  });

  testWidgets('trend includes all dates and only the selected phoneme', (tester) async {
    final source = [
      sample('ㅏ', '모음', '2026-10-26T08:00:00', id: 1),
      sample('ㅏ', '모음', '2026-10-25T12:00:00', id: 2),
      sample('ㄱ', '자음', '2026-10-26T11:00:00', id: 3),
    ];
    await tester.pumpWidget(MaterialApp(home: PhonemeProgressChartScreen(
      phoneme: 'ㅏ', records: source,
    )));
    expect(find.byKey(const Key('phoneme_progress_chart')), findsOneWidget);
    expect(find.text('전체 분석 기록'), findsOneWidget);
    expect(find.byKey(const Key('phoneme_history_0')), findsOneWidget);
    expect(find.byKey(const Key('phoneme_history_1')), findsOneWidget);
    expect(find.byKey(const Key('phoneme_history_2')), findsNothing);
  });

  testWidgets('calendar graph and arrow lead to their respective pages', (tester) async {
    await DemoScenarios.select(DemoScenario.reviewing);
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    DemoScenarios.feedbackResults.addAll([
      sample('ㅏ', '모음', day.add(const Duration(hours: 9)).toIso8601String(), id: 11),
      sample('ㅏ', '모음', day.add(const Duration(hours: 20)).toIso8601String(), id: 12),
      sample('ㅏ', '모음', day.subtract(const Duration(days: 4)).toIso8601String(), id: 13),
    ]);
    await tester.pumpWidget(MaterialApp(home: LearningCalendarScreen(
      initialLatestActivity: true, onPractice: (_) {},
    )));
    await tester.pumpAndSettle();
    final arrow = find.byKey(const Key('calendar_day_results_ㅏ'));
    await tester.ensureVisible(arrow);
    await tester.tap(arrow);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDayResultsScreen), findsOneWidget);
    expect(find.text('ㅏ · 저장된 분석 결과 2건'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    final graph = find.byKey(const Key('calendar_trend_ㅏ'));
    await tester.ensureVisible(graph);
    await tester.tap(graph);
    await tester.pumpAndSettle();
    expect(find.byType(PhonemeProgressChartScreen), findsOneWidget);
    expect(find.text('ㅏ 발음의 학습 변화'), findsOneWidget);
    expect(find.text('3건'), findsOneWidget);
  });
}
