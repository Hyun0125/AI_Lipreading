import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_flutter/models/feedback_result.dart';
import 'package:test_flutter/screens/feedback_screen.dart';
import 'package:test_flutter/screens/review_result_detail_screen.dart';
import 'package:test_flutter/widgets/practice_visuals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final sample = FeedbackResult.fromJson({
    'category': '모음',
    'target_item': 'ㅏ',
    'target_pronunciation': 'ㅏ',
    'whisper_result': '아',
    'audio_total_score': 82.0,
    'visual_total_score': 88.0,
    'feedbacks': ['입을 자연스럽게 벌려 보세요.'],
  });

  testWidgets('v7 practice tabs switch without changing data', (tester) async {
    var selected = '요약';
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StatefulBuilder(builder: (context, update) {
        return PracticeTabs(
          selected: selected,
          onSelected: (value) => update(() => selected = value),
        );
      })),
    ));
    expect(find.byKey(const Key('practice_tab_요약')), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice_tab_음성')));
    await tester.pump();
    expect(selected, '음성');
  });

  testWidgets('immediate result keeps its three analysis tabs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FeedbackResultScreen(result: sample),
    ));
    await tester.pumpAndSettle();
    expect(find.text('발음 분석 결과'), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice_tab_음성')));
    await tester.pumpAndSettle();
    expect(find.text('음성 세부 분석'), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice_tab_입모양')));
    await tester.pumpAndSettle();
    expect(find.text('입모양 세부 분석'), findsOneWidget);
  });

  testWidgets('saved result reuses the same visual tab design', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReviewResultDetailScreen(result: sample),
    ));
    await tester.pumpAndSettle();
    expect(find.text('저장된 발음 결과'), findsOneWidget);
    expect(find.byKey(const Key('practice_tab_요약')), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice_tab_음성')));
    await tester.pumpAndSettle();
    expect(find.text('음성 세부 분석'), findsOneWidget);
  });
}
