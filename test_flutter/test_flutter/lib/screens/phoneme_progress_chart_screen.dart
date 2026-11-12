import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/feedback_result.dart';
import '../services/pronunciation_record_filter.dart';
import '../ui/app_style.dart';
import 'review_result_detail_screen.dart';

/// A timeline of *saved* analysis scores for one consonant/vowel.
/// The x axis is chronological attempt order (not an evenly spaced date axis).
class PhonemeProgressChartScreen extends StatelessWidget {
  final String phoneme;
  final List<FeedbackResult> records;

  const PhonemeProgressChartScreen({
    super.key,
    required this.phoneme,
    required this.records,
  });

  @override
  Widget build(BuildContext context) {
    final history = savedPhonemeHistory(records, phoneme);
    final ascending = history.reversed.toList();
    final hasAnyScores = ascending.any(
      (r) => r.hasAudioTotalScore || r.hasVisualTotalScore);
    final firstDate = ascending.isEmpty ? null : feedbackRecordedAt(ascending.first);
    final lastDate = ascending.isEmpty ? null : feedbackRecordedAt(ascending.last);

    return Scaffold(
      backgroundColor: AppStyle.background,
      appBar: AppBar(title: Text('$phoneme · 학습 변화')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 17, 20, 28),
        children: [
          Text('$phoneme 발음의 학습 변화', style: AppStyle.heading(size: 23)),
          const SizedBox(height: 6),
          const Text('전체 기간의 저장된 분석 결과를 연습 순서대로 보여줘요.',
            style: TextStyle(color: AppStyle.muted, fontSize: 12)),
          const SizedBox(height: 17),
          Container(
            decoration: AppStyle.card(),
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 17),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('음성·입모양 점수 변화',
                    style: AppStyle.heading(size: 17)),
                  const Spacer(),
                  Text('${ascending.length}건', style: const TextStyle(
                    color: AppStyle.muted, fontSize: 12)),
                ]),
                const SizedBox(height: 14),
                const Wrap(spacing: 16, runSpacing: 8, children: [
                  _ChartLegend(color: AppStyle.coral, label: '음성'),
                  _ChartLegend(color: Color(0xFF428F9A), label: '입모양'),
                ]),
                const SizedBox(height: 14),
                if (ascending.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 45),
                    child: Center(child: Text(
                      '저장된 분석 결과가 아직 없어요.\n'
                      '분석 결과를 저장하면 변화가 표시돼요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppStyle.muted, height: 1.5))),
                  )
                else if (!hasAnyScores)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 45),
                    child: Center(child: Text('표시할 점수 데이터가 없어요.',
                      style: TextStyle(color: AppStyle.muted))),
                  )
                else ...[
                  LayoutBuilder(builder: (context, constraints) {
                    final width = math.max(constraints.maxWidth,
                        ascending.length * 36.0 + 50.0);
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        height: 220,
                        child: CustomPaint(
                          key: const Key('phoneme_progress_chart'),
                          painter: _ScoreTimelinePainter(ascending),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 5),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(firstDate == null ? '' : feedbackDateLabel(firstDate),
                        style: const TextStyle(color: AppStyle.muted, fontSize: 11)),
                      const Text('연습 순서 →', style: TextStyle(
                        color: AppStyle.muted, fontSize: 11)),
                      Text(lastDate == null ? '' : feedbackDateLabel(lastDate),
                        style: const TextStyle(color: AppStyle.muted, fontSize: 11)),
                    ]),
                  if (ascending.length == 1) ...[
                    const SizedBox(height: 10),
                    const Text('다음 연습 결과가 저장되면 점수 변화를 비교할 수 있어요.',
                      style: TextStyle(color: AppStyle.muted, fontSize: 11)),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 23),
          Text('전체 분석 기록', style: AppStyle.heading(size: 18)),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const Text('저장된 결과가 없어요.', style: TextStyle(color: AppStyle.muted))
          else
            for (var index = 0; index < history.length; index++) ...[
              _HistoryTile(
                key: Key('phoneme_history_$index'),
                record: history[index],
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ReviewResultDetailScreen(result: history[index]),
                )),
              ),
              const SizedBox(height: 9),
            ],
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 11, height: 11, decoration: BoxDecoration(
        color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: AppStyle.muted)),
    ]);
}

class _ScoreTimelinePainter extends CustomPainter {
  final List<FeedbackResult> history;
  const _ScoreTimelinePainter(this.history);

  static const _audioColor = AppStyle.coral;
  static const _visualColor = Color(0xFF428F9A);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 36.0;
    const right = 14.0;
    const top = 12.0;
    const bottom = 19.0;
    final graphWidth = math.max(size.width - left - right, 1.0);
    final graphHeight = math.max(size.height - top - bottom, 1.0);

    for (final score in [0, 25, 50, 75, 100]) {
      final y = top + (100 - score) / 100 * graphHeight;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y),
        Paint()..color = AppStyle.softBorder..strokeWidth = 1);
      final label = TextPainter(
        text: TextSpan(text: '$score', style: const TextStyle(
          color: AppStyle.muted, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(left - label.width - 8, y - label.height / 2));
    }

    Offset point(int index, double score) {
      final x = history.length == 1
        ? left + graphWidth / 2
        : left + index / (history.length - 1) * graphWidth;
      return Offset(x, top + (100 - score.clamp(0.0, 100.0)) / 100 * graphHeight);
    }

    void series(Color color, bool Function(FeedbackResult) available,
        double Function(FeedbackResult) value) {
      final points = <Offset>[];
      for (var index = 0; index < history.length; index++) {
        if (!available(history[index])) continue;
        points.add(point(index, value(history[index])));
      }
      if (points.isEmpty) return;
      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      if (points.length >= 2) {
        final path = Path()..moveTo(points.first.dx, points.first.dy);
        for (final p in points.skip(1)) { path.lineTo(p.dx, p.dy); }
        canvas.drawPath(path, linePaint);
      }
      for (final p in points) {
        canvas.drawCircle(p, 4.3, Paint()..color = AppStyle.paper);
        canvas.drawCircle(p, 3.3, Paint()..color = color);
      }
    }

    series(_audioColor, (r) => r.hasAudioTotalScore, (r) => r.audioTotalScore);
    series(_visualColor, (r) => r.hasVisualTotalScore, (r) => r.visualTotalScore);
  }

  @override
  bool shouldRepaint(covariant _ScoreTimelinePainter oldDelegate) =>
      oldDelegate.history != history;
}

class _HistoryTile extends StatelessWidget {
  final FeedbackResult record;
  final VoidCallback onTap;
  const _HistoryTile({super.key, required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = feedbackRecordedAt(record);
    final labels = <String>[
      if (record.hasAudioTotalScore)
        '음성 ${feedbackScoreLabel(record.audioTotalScore)}',
      if (record.hasVisualTotalScore)
        '입모양 ${feedbackScoreLabel(record.visualTotalScore)}',
    ];
    return Material(
      color: AppStyle.paper,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: AppStyle.card(radius: 15),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.insights_outlined, color: AppStyle.coral),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date == null ? '시간 정보 없음'
                    : '${feedbackDateLabel(date)}  ${feedbackTimeLabel(date)}',
                  style: const TextStyle(fontWeight: FontWeight.w800,
                    fontSize: 13, color: AppStyle.ink)),
                const SizedBox(height: 4),
                Text(labels.isEmpty ? '저장된 분석 결과' : labels.join(' · '),
                  style: const TextStyle(color: AppStyle.muted, fontSize: 11)),
              ],
            )),
            const Icon(Icons.chevron_right_rounded, color: AppStyle.coral),
          ]),
        ),
      ),
    );
  }
}
