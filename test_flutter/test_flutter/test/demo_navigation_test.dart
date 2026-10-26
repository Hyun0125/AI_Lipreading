import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_flutter/main.dart';
import 'package:test_flutter/services/demo_scenarios.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({'intro_seen_v1': true});
    await DemoScenarios.select(DemoScenario.off);
  });
  tearDown(() async => DemoScenarios.select(DemoScenario.off));

  testWidgets('settings can select B and return to homepage', (tester) async {
    await tester.pumpWidget(const SpeechTrainerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('시연용 사용자 상태'), 200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('시연용 사용자 상태'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo_option_studied')), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo_option_studied')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo_start')));
    await tester.pumpAndSettle();
    expect(find.textContaining('시연 모드 · B'), findsOneWidget);
    expect(find.text('나의 학습 현황'), findsOneWidget);
    await tester.tap(find.text('복습'));
    await tester.pumpAndSettle();
    expect(find.text('나의 복습'), findsOneWidget);
    await tester.tap(find.text('전체 보기'));
    await tester.pumpAndSettle();
    expect(find.text('전체 학습 기록'), findsOneWidget);
  });

  testWidgets('scenario A reopens first-use journey', (tester) async {
    await tester.pumpWidget(const SpeechTrainerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('시연용 사용자 상태'), 200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('시연용 사용자 상태'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo_option_firstLaunch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo_start')));
    await tester.pumpAndSettle();
    expect(find.text('소리를 눈으로\n배우는 시간'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });
}
