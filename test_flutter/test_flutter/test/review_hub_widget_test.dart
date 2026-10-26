// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_flutter/screens/history_hub_screen.dart';
import 'package:test_flutter/screens/learning_calendar_screen.dart';
import 'package:test_flutter/services/demo_scenarios.dart';
import 'package:test_flutter/services/learning_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DemoScenarios.select(DemoScenario.reviewing);
  });
  tearDown(() async => DemoScenarios.select(DemoScenario.off));

  testWidgets('review list is automatically checked, removal offers undo', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: HistoryHubScreen(onPractice: (_) {}),
    )));
    await tester.pumpAndSettle();
    expect(find.text('오늘 복습 완료 표시'), findsNothing);
    expect(find.text('완료 취소'), findsNothing);
    expect(find.byKey(const Key('review_remove_ㄱ')), findsOneWidget);
    expect(find.byKey(const Key('review_practice_ㄱ')), findsOneWidget);
    await tester.tap(find.byKey(const Key('review_remove_ㄱ')));
    await tester.pumpAndSettle();
    expect(find.textContaining('복습 목록에서 제거했어요'), findsOneWidget);
    await tester.tap(find.text('실행 취소'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review_remove_ㄱ')), findsOneWidget);
  });

  testWidgets('review rows share one card and show a single automatic status', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: HistoryHubScreen(onPractice: (_) {}),
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('review_grouped_list')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review_grouped_list')), findsOneWidget);
    expect(find.byKey(const Key('review_rows_auto_only_v7')), findsOneWidget);
    expect(find.text('3개 발음'), findsOneWidget);
    expect(find.text('자음 ㄱ · 가'), findsOneWidget);
    expect(find.text('모음 ㅓ'), findsOneWidget);
    expect(find.text('모음 ㅜ'), findsOneWidget);
    expect(find.byKey(const Key('review_status_ㄱ')), findsOneWidget);
    expect(find.byKey(const Key('review_status_ㅓ')), findsOneWidget);
    expect(find.byKey(const Key('review_status_ㅜ')), findsOneWidget);
    expect(find.text('오늘 복습 완료'), findsOneWidget);
    expect(find.text('오늘 복습 전'), findsNWidgets(2));
    // 완료 상태는 제어용 체크박스나 버튼이 아닌 일반 텍스트다.
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('오늘 복습 완료 표시'), findsNothing);
    expect(find.text('완료 취소'), findsNothing);
    expect(find.text('연습하면 자동 완료'), findsNothing);
    expect(find.text('목록 관리'), findsNothing);
    expect(find.byKey(const Key('review_practice_ㄱ')), findsOneWidget);
    expect(find.byKey(const Key('review_remove_ㄱ')), findsOneWidget);
  });


  testWidgets('successful practice updates review status without a manual toggle', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: HistoryHubScreen(onPractice: (_) {}),
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('review_rows_auto_only_v7')));
    expect(find.byKey(const Key('review_status_ㄱ')), findsOneWidget);
    expect(find.text('오늘 복습 전'), findsNWidgets(2));

    await LearningProgress.recordSuccessfulPractice(phoneme: 'ㄱ', category: '자음');
    await tester.pumpAndSettle();
    expect(find.text('오늘 복습 완료'), findsNWidgets(2));
    expect(find.text('오늘 복습 전'), findsOneWidget);
    expect(find.text('오늘 복습 완료 표시'), findsNothing);
    expect(find.text('완료 취소'), findsNothing);
  });

  testWidgets('demo B displays dated activity rather than empty server history', (tester) async {
    await DemoScenarios.select(DemoScenario.studied);
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: HistoryHubScreen(onPractice: (_) {}),
    )));
    await tester.pumpAndSettle();
    expect(find.text('지난 학습 기록'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('review_recent_practice_records')), 180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('review_recent_practice_records')), findsOneWidget);
    expect(find.text('연습 1회'), findsWidgets);
    expect(find.text('아직 저장된 발음 분석 기록이 없어요.'), findsNothing);
  });

  testWidgets('calendar day selection stays on calendar, shows practice info', (tester) async {
    await DemoScenarios.select(DemoScenario.studied);
    await tester.pumpWidget(MaterialApp(home: LearningCalendarScreen(
      onPractice: (_) {}, initialLatestActivity: true,
    )));
    await tester.pumpAndSettle();
    expect(find.text('전체 학습 기록'), findsOneWidget);
    expect(find.text('상세 보기'), findsNothing);
    expect(find.byKey(const Key('calendar_selected_day_records')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('calendar_selected_day_records')));
    expect(find.textContaining('이 기기 연습'), findsWidgets);
    // 달력의 날짜 선택은 새 페이지를 열지 않고 아래 기록만 갱신한다.
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateKey = '${yesterday.year.toString().padLeft(4, '0')}-'
        '${yesterday.month.toString().padLeft(2, '0')}-'
        '${yesterday.day.toString().padLeft(2, '0')}';
    await tester.ensureVisible(find.byKey(Key('calendar_day_$dateKey')));
    await tester.tap(find.byKey(Key('calendar_day_$dateKey')));
    await tester.pumpAndSettle();
    expect(find.text('전체 학습 기록'), findsOneWidget);
    expect(find.byKey(const Key('calendar_selected_day_records')), findsOneWidget);
    expect(find.byKey(const Key('calendar_entry_ㅁ')), findsOneWidget);
  });
}
