import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/feedback_result.dart';
import '../services/demo_scenarios.dart';
import '../services/feedback_api.dart';
import '../ui/app_style.dart';
import 'review_result_detail_screen.dart';

/// Unlike feedback (immediate result), this page decides the NEXT action:
/// inspect previous evidence, revise articulation, or record again.
class ReviewPracticeScreen extends StatefulWidget {
  final String phoneme;
  final VoidCallback onStudy;
  final VoidCallback onRecord;

  const ReviewPracticeScreen({
    super.key,
    required this.phoneme,
    required this.onStudy,
    required this.onRecord,
  });

  @override
  State<ReviewPracticeScreen> createState() => _ReviewPracticeScreenState();
}

class _ReviewPracticeScreenState extends State<ReviewPracticeScreen> {
  List<FeedbackResult> _results = [];
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await FeedbackApi.getAllReviewResults(
        userId: AppConfig.currentUserId,
      );
      final found = results.where((item) => item.targetItem == widget.phoneme)
        .toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() { _results = found; _loading = false; _offline = false; });
    } catch (_) {
      if (mounted) setState(() { _results = []; _loading = false; _offline = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneme = widget.phoneme;
    return Scaffold(
      backgroundColor: AppStyle.background,
      appBar: AppBar(title: Text('$phoneme 복습하기')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 15, 20, 30), children: [
        Container(
          decoration: AppStyle.card(color: AppStyle.paleCoral),
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            Text(phoneme, style: AppStyle.heading(size: 51)),
            const SizedBox(height: 7),
            Text('지난번에 배운 발음을 다시 연습해요.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppStyle.muted, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 22),
        Text('이전 연습 결과', style: AppStyle.heading(size: 19)),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(18),
            child: CircularProgressIndicator()))
        else if (_offline)
          Container(decoration: AppStyle.card(), padding: const EdgeInsets.all(16),
            child: const Text('서버에 연결할 수 없어요. 이전 결과는 확인할 수 없지만 '
              '발음 방법 학습과 재연습은 계속할 수 있어요.'))
        else if (_results.isEmpty)
          Container(decoration: AppStyle.card(), padding: const EdgeInsets.all(16),
            child: const Text('저장된 분석 결과가 없어요. 발음 방법을 살펴보거나 바로 연습할 수 있어요.'))
        else
          for (final result in _results.take(3)) ...[
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ReviewResultDetailScreen(result: result))),
                child: Container(
                  decoration: AppStyle.card(),
                  padding: const EdgeInsets.all(15),
                  child: Row(children: [
                    const Icon(Icons.analytics_outlined, color: AppStyle.coral),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(result.createdAt, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(DemoScenarios.isActive ? '시연용 분석 결과' : '저장된 피드백 보기',
                          style: const TextStyle(fontSize: 11, color: AppStyle.muted)),
                      ])),
                    const Icon(Icons.chevron_right_rounded, color: AppStyle.muted),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 25),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: widget.onStudy,
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('조음 그림 다시 보기'),
        )),
        const SizedBox(height: 11),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: widget.onRecord,
          icon: const Icon(Icons.mic_none_rounded),
          label: const Text('바로 발음 연습하기'),
        )),
        const SizedBox(height: 15),
        const Text('복습은 이전 결과를 확인한 뒤 같은 발음의 학습·촬영 화면으로 '
          '돌아가는 과정이에요. AI 자동 추천 기능은 아직 연결되지 않았어요.',
          style: TextStyle(fontSize: 11, height: 1.5, color: AppStyle.muted)),
      ]),
    );
  }
}
