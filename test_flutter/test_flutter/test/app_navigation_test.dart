// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_flutter/main.dart';
import 'package:test_flutter/screens/learning_home_screen.dart';
import 'package:test_flutter/screens/articulation_catalog_screen.dart';
import 'package:test_flutter/services/demo_scenarios.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'intro_seen_v1': true});
    await DemoScenarios.select(DemoScenario.studied);
  });
  tearDown(() async => DemoScenarios.select(DemoScenario.off));

  testWidgets('four tabs, separate consonant and vowel illustration screens',
      (tester) async {
    await tester.pumpWidget(const SpeechTrainerApp());
    await tester.pumpAndSettle();
    expect(find.text('홈'), findsWidgets);
    await tester.tap(find.text('학습'));
    await tester.pumpAndSettle();
    expect(find.byType(LearningHomeScreen), findsOneWidget);
    expect(find.text('단어 학습'), findsOneWidget);
    expect(find.text('문장 학습'), findsOneWidget);
    expect(find.text('준비 중'), findsNWidgets(2));

    // 모음 카드가 자음 카드보다 먼저 배치된다.
    await tester.tap(find.text('모음 학습'));
    await tester.pumpAndSettle();
    expect(find.byType(ArticulationCatalogScreen), findsOneWidget);
    expect(find.text('단모음'), findsWidgets);
    expect(find.text('이중모음'), findsWidgets);
    expect(find.text('발음 방법'), findsOneWidget);
    expect(find.text('발음 연습하기'), findsOneWidget);
    expect(find.text('복습에 추가'), findsOneWidget);
    expect(find.text('이 발음 학습 완료로 표시'), findsNothing);
    expect(find.text('학습 완료 · 다시 누르면 취소'), findsNothing);
  });

  testWidgets('home recent history opens calendar, selected day updates inline',
      (tester) async {
    await tester.pumpWidget(const SpeechTrainerApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('home_open_calendar')), 200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('home_open_calendar')));
    await tester.pumpAndSettle();
    expect(find.text('전체 학습 기록'), findsOneWidget);
    expect(find.text('날짜별 학습 기록'), findsOneWidget);
    expect(find.text('상세 보기'), findsNothing);
    expect(find.byKey(const Key('calendar_selected_day_records')), findsOneWidget);
    final now = DateTime.now();
    final practicedDay = now.subtract(const Duration(days: 8));
    final dayKey = '${practicedDay.year.toString().padLeft(4, '0')}-'
        '${practicedDay.month.toString().padLeft(2, '0')}-'
        '${practicedDay.day.toString().padLeft(2, '0')}';
    // 현재 홈의 '기록 보기'는 최근 연습일을 선택한 달력을 연다.
    // 같은 달에 기록이 있으면 날짜만 선택하여 아래 카드의 글자를 확인한다.
    if (practicedDay.month == now.month) {
      final dateFinder = find.byKey(Key('calendar_day_$dayKey'));
      await tester.ensureVisible(dateFinder);
      await tester.tap(dateFinder);
      await tester.pumpAndSettle();
      expect(find.text('ㅏ'), findsWidgets);
      expect(find.byKey(const Key('calendar_selected_day_records')), findsOneWidget);
      expect(find.text('이날 배운 발음'), findsNothing);
    }
  });
}
