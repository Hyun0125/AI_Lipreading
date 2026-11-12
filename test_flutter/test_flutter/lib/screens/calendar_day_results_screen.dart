import 'package:flutter/material.dart';

import '../models/feedback_result.dart';
import '../services/pronunciation_record_filter.dart';
import '../ui/app_style.dart';
import 'review_result_detail_screen.dart';

/// Shows *all* saved analyses for one phoneme on the selected calendar day.
/// One record still uses this page, so the calendar arrow always means the same thing.
class CalendarDayResultsScreen extends StatelessWidget {
  final DateTime selectedDate;
  final String phoneme;
  final List<FeedbackResult> records;

  const CalendarDayResultsScreen({
    super.key,
    required this.selectedDate,
    required this.phoneme,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final daily = savedPhonemeDayHistory(records, phoneme, selectedDate);
    return Scaffold(
      backgroundColor: AppStyle.background,
      appBar: AppBar(title: Text('$phoneme · 해당 날짜 결과')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text('${selectedDate.year}년 ${selectedDate.month}월 '
              '${selectedDate.day}일', style: AppStyle.heading(size: 22)),
          const SizedBox(height: 6),
          Text('$phoneme · 저장된 분석 결과 ${daily.length}건',
            style: const TextStyle(color: AppStyle.muted, fontSize: 13)),
          const SizedBox(height: 18),
          if (daily.isEmpty)
            Container(
              key: const Key('calendar_day_no_saved_results'),
              decoration: AppStyle.card(),
              padding: const EdgeInsets.all(20),
              child: const Text('이 날짜에는 저장된 분석 결과가 없어요.\n'
                '연습 완료 기록과 서버에 저장된 피드백은 서로 다를 수 있어요.',
                style: TextStyle(color: AppStyle.muted, height: 1.5)),
            )
          else
            for (var index = 0; index < daily.length; index++) ...[
              _SavedResultTile(
                key: Key('calendar_saved_result_$index'),
                result: daily[index],
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ReviewResultDetailScreen(result: daily[index]),
                )),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _SavedResultTile extends StatelessWidget {
  final FeedbackResult result;
  final VoidCallback onTap;
  const _SavedResultTile({super.key, required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final at = feedbackRecordedAt(result);
    final scoreLabels = <String>[
      if (result.hasAudioTotalScore)
        '음성 ${feedbackScoreLabel(result.audioTotalScore)}',
      if (result.hasVisualTotalScore)
        '입모양 ${feedbackScoreLabel(result.visualTotalScore)}',
    ];
    return Material(
      color: AppStyle.paper,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: AppStyle.card(radius: 16),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppStyle.paleCoral,
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.analytics_outlined, color: AppStyle.coral),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(at == null ? '시간 정보 없음' : feedbackTimeLabel(at),
                  style: const TextStyle(color: AppStyle.ink,
                    fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(scoreLabels.isEmpty
                    ? '저장된 피드백 확인'
                    : scoreLabels.join(' · '),
                  style: const TextStyle(color: AppStyle.muted, fontSize: 12)),
              ],
            )),
            const Icon(Icons.chevron_right_rounded, color: AppStyle.coral),
          ]),
        ),
      ),
    );
  }
}
