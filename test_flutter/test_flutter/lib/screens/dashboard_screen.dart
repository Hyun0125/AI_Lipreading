import 'package:flutter/material.dart';

import '../services/demo_scenarios.dart';
import '../services/learning_progress.dart';
import '../services/review_queue.dart';
import '../ui/app_style.dart';

/// The dashboard suggests a NEXT ACTION based on local learning/review data.
/// Suggestions are NEVER claimed to be AI diagnosis results.
class DashboardScreen extends StatefulWidget {
  final ValueChanged<String> onPractice;
  final VoidCallback onAssess;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenLearning;
  final VoidCallback onOpenReview;
  const DashboardScreen({super.key, required this.onPractice,
    required this.onAssess, required this.onOpenHistory,
    required this.onOpenLearning, required this.onOpenReview});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Set<String> _completed = {};
  Set<String> _queue = {};
  List<LearningActivity> _activities = [];

  @override
  void initState() {
    super.initState();
    _refresh();
    LearningProgress.revision.addListener(_refresh);
  }

  @override
  void dispose() {
    LearningProgress.revision.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final completed = await LearningProgress.read();
    final queue = await ReviewQueue.read();
    final activities = await LearningProgress.readActivities();
    activities.sort((a,b)=>b.at.compareTo(a.at));
    if (mounted) {
      setState(() {
        _completed = completed;
        _queue = queue;
        _activities = activities;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const total = LearningProgress.totalPhonemes; // 자음 19 + 모음 21
    final count = _completed.length.clamp(0, total).toInt();
    final recent = <String>[];
    for (final activity in _activities) {
      if (!recent.contains(activity.phoneme)) recent.add(activity.phoneme);
      if (recent.length >= 5) break;
    }
    final unfinished = const ['ㅏ','ㅓ','ㅗ','ㅜ','ㅣ','ㄱ','ㄴ','ㅂ','ㅁ']
      .firstWhere((item)=>!_completed.contains(item), orElse: ()=>'ㅏ');
    final hasHistory = _activities.isNotEmpty;
    final reviewFirst = _queue.isNotEmpty &&
      (DemoScenarios.current==DemoScenario.reviewing ||
        _queue.length>=2);
    final actionTitle = reviewFirst ? '오늘의 복습' :
      hasHistory ? '이어서 학습하기' : '첫 발음 학습 시작하기';
    final actionDetail = reviewFirst ?
      '복습 목록에 저장된 발음을 다시 연습해 보세요.' :
      hasHistory ? '최근에 배운 ${recent.first} 발음을 다시 확인해 보세요.' :
      '모음 ㅏ부터 발음 방법을 알아보세요.';
    final action = reviewFirst ? widget.onOpenReview :
      hasHistory ? () => widget.onPractice(recent.first) :
      () => widget.onPractice(unfinished);
    final title = reviewFirst ? '오늘은 복습부터 시작해 볼까요?' :
      hasHistory ? '오늘도 발음을 연습해 볼까요?' :
      '발음 학습을 시작해 볼까요?';

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppStyle.coral,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 34),
        children: [
          const Text('발음한걸음', style: TextStyle(
            color: AppStyle.muted, fontSize: 12)),
          const SizedBox(height: 5),
          Text('홈', style: AppStyle.heading(size: 29)),
          const SizedBox(height: 21),
          Text(title, style: AppStyle.heading(size: 21)),
          const SizedBox(height: 6),
          const Text('내 속도에 맞춰 발음을 차근차근 배워요.',
            style: TextStyle(color: AppStyle.muted, fontSize: 13)),
          const SizedBox(height: 19),
          Container(
            decoration: AppStyle.card(color: AppStyle.paleCoral),
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('나에게 필요한 다음 단계',
                  style: TextStyle(color: AppStyle.coral, fontSize: 12,
                    fontWeight: FontWeight.w800))),
                Icon(reviewFirst ? Icons.repeat_rounded : Icons.menu_book_rounded,
                  color: AppStyle.coral),
              ]),
              const SizedBox(height: 15),
              Text(actionTitle, style: AppStyle.heading(size: 19)),
              const SizedBox(height: 7),
              Text(actionDetail, style: const TextStyle(
                fontSize: 13, height: 1.5, color: AppStyle.muted)),
              const SizedBox(height: 17),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                key: const Key('home_primary_action'),
                onPressed: action,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('시작하기'),
              )),
            ]),
          ),
          const SizedBox(height: 17),
          if (!hasHistory) ...[
            Container(decoration: AppStyle.card(), padding: const EdgeInsets.all(17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('현재 발음 상태 확인하기', style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 7),
                const Text('초기 문장 진단을 먼저 진행할 수도 있어요. '
                  '현재 문장 AI 분석은 연결 전입니다.',
                  style: TextStyle(color: AppStyle.muted, height: 1.5, fontSize: 12)),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: widget.onAssess,
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('발음 진단하기')),
              ]),
            ),
          ],
          Container(decoration: AppStyle.card(), padding: const EdgeInsets.all(17),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('나의 학습 현황', style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 11),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('$count', style: AppStyle.heading(size: 30)),
                  const SizedBox(width: 5),
                  Padding(padding: const EdgeInsets.only(bottom: 4),
                    child: Text('/ $total개 기초 발음 연습 완료',
                      style: const TextStyle(color: AppStyle.muted))),
                ]),
                const SizedBox(height: 12),
                ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: count/total,
                    minHeight: 8,
                    backgroundColor: AppStyle.softBorder,
                    color: AppStyle.coral)),
                const SizedBox(height: 8),
                const Text('촬영·분석을 1회 이상 완료한 서로 다른 글자 기준이에요. 정확도 점수가 아니에요.',
                  style: TextStyle(color: AppStyle.muted, fontSize: 11)),
              ]),
            ),
          const SizedBox(height: 25),
          Text('바로가기', style: AppStyle.heading(size: 18)),
          const SizedBox(height: 11),
          Row(children: [
            Expanded(child: _Shortcut(title: '발음 학습', subtitle: '모음·자음 배우기',
              icon: Icons.menu_book_outlined, onTap: widget.onOpenLearning)),
            const SizedBox(width: 10),
            Expanded(child: _Shortcut(title: '나의 복습', subtitle: '다시 연습하기',
              icon: Icons.repeat_rounded, onTap: widget.onOpenReview)),
          ]),
          const SizedBox(height: 24),
          Container(decoration: AppStyle.card(color: AppStyle.softInk),
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('최근 학습', style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800))),
                if (hasHistory)
                  TextButton.icon(
                    key: const Key('home_open_calendar'),
                    onPressed: widget.onOpenHistory,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.chevron_right, size: 17),
                    label: const Text('기록 보기')),
              ]),
              Text(hasHistory ? recent.join(' · ') :
                '발음 연습 후 기록이 이곳에 표시돼요.',
                style: const TextStyle(color: AppStyle.muted, fontSize: 13)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _Shortcut({required this.title, required this.subtitle,
    required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        constraints: const BoxConstraints(minHeight: 133),
        decoration: AppStyle.card(radius: 16),
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppStyle.coral, size: 26),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppStyle.muted)),
        ]),
      )),
  );
}
