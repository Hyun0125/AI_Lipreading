// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_flutter/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch shows the new start screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SpeechTrainerApp());
    await tester.pumpAndSettle();
    expect(find.text('시작하기'), findsOneWidget);
    expect(find.textContaining('소리를 눈으로'), findsOneWidget);
  });
}
