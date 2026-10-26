import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_flutter/main.dart';
import 'package:test_flutter/services/demo_scenarios.dart';
import 'package:flutter/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({'intro_seen_v1': true});
    await DemoScenarios.select(DemoScenario.studied);
  });
  tearDown(() async => DemoScenarios.select(DemoScenario.off));

  testWidgets('accessibility, permission and about use detail screens',
      (tester) async {
    await tester.pumpWidget(const SpeechTrainerApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('글자 크기'));
    await tester.pumpAndSettle();
    expect(find.text('아주 크게'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('카메라·마이크 권한'), 170,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('카메라·마이크 권한'));
    await tester.pumpAndSettle();
    expect(find.text('기기에서 권한을 변경하려면'), findsOneWidget);
  });
}
