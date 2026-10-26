import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/feedback_result.dart';
import '../services/feedback_api.dart';
import '../services/learning_progress.dart';
import '../services/demo_scenarios.dart';
import '../services/review_queue.dart';
import '../ui/app_style.dart';
import 'learning_calendar_screen.dart';
import 'review_result_detail_screen.dart';

/// 복습 탭: 오늘의 직접 지정한 복습, 지난 서버 분석 기록, 날짜별 학습 달력.
/// 자동 취약 발음 판정은 아직 구현되지 않았으므로 임의의 복습 항목을 생성하지 않는다.
class HistoryHubScreen extends StatefulWidget {
  final ValueChanged<String> onPractice;
  const HistoryHubScreen({super.key, required this.onPractice});

  @override
  State<HistoryHubScreen> createState() => _HistoryHubScreenState();
}

class _HistoryHubScreenState extends State<HistoryHubScreen> {
  Set<String> _reviewItems = {};
  Set<String> _reviewedToday = {};
  List<FeedbackResult> _results = [];
  List<LearningActivity> _localActivities = [];
  bool _serverLoading = true;
  bool _serverUnavailable = false;

  @override
  void initState() {
    super.initState();
    _load();
    LearningProgress.revision.addListener(_load);
  }

  @override
  void dispose() {
    LearningProgress.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final list = await ReviewQueue.read();
    final completed = await ReviewQueue.reviewedToday();
    final activities = await LearningProgress.readActivities();
    activities.sort((a, b) => b.at.compareTo(a.at));
    if (mounted) {
      setState(() {
        _reviewItems = list;
        _reviewedToday = completed;
        _localActivities = activities;
        _serverLoading = true;
      });
    }
    try {
      final results = await FeedbackApi.getAllReviewResults(
        userId: AppConfig.currentUserId,
      );
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _results = results;
          _serverUnavailable = false;
          _serverLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverUnavailable = true;
          _serverLoading = false;
        });
      }
    }
  }

  Future<void> _removeFromQueue(String phoneme) async {
    await ReviewQueue.setIncluded(phoneme, false);
    if (!mounted) return;
    setState(() => _reviewItems.remove(phoneme));
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text('$phoneme 발음을 복습 목록에서 제거했어요.'),
      action: SnackBarAction(
        label: '실행 취소',
        onPressed: () async {
          await ReviewQueue.setIncluded(phoneme, true);
          if (mounted) await _load();
        },
      ),
    ));
  }

  Future<void> _openCalendar() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LearningCalendarScreen(
        onPractice: widget.onPractice, initialLatestActivity: true),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _reviewItems.toList()..sort();
    final done = sorted.where(_reviewedToday.contains).length;
    final percent = sorted.isEmpty ? 0.0 : done / sorted.length;

    return RefreshIndicator(
      color: AppStyle.coral,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 23, 20, 30),
        children: [
          Text('나의 복습', style: AppStyle.heading(size: 28)),
          const SizedBox(height: 7),
          const Text('이전에 연습한 발음을 다시 확인해요.',
            style: TextStyle(color: AppStyle.muted, fontSize: 13)),
          const SizedBox(height: 23),
          if (DemoScenarios.isActive) ...[
            Container(
              decoration: AppStyle.card(color: AppStyle.paleCoral),
              padding: const EdgeInsets.all(13),
              child: const Text('시연용 예시 기록입니다. 실제 AI 분석 결과나 사용자 데이터가 아닙니다.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppStyle.ink)),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            decoration: AppStyle.card(color: AppStyle.softInk),
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('오늘의 복습', style: TextStyle(
                fontWeight: FontWeight.w700, color: AppStyle.muted, fontSize: 12)),
              const SizedBox(height: 9),
              Row(children: [
                Expanded(child: Text('${sorted.length}개 중 $done개 완료',
                  style: AppStyle.heading(size: 23))),
                const Icon(Icons.track_changes_rounded,
                  color: AppStyle.coral, size: 29),
              ]),
              const SizedBox(height: 6),
              const Text('복습 목록의 발음을 촬영·분석하면 오늘 복습이 자동 완료돼요.',
                style: TextStyle(fontSize: 11, color: AppStyle.muted)),
              const SizedBox(height: 14),
              ClipRRect(borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percent, minHeight: 7,
                  backgroundColor: AppStyle.softBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppStyle.coral),
                )),
            ]),
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('다시 연습할 발음', style: AppStyle.heading(size: 19)),
              if (sorted.isNotEmpty)
                Text('${sorted.length}개 발음',
                  style: const TextStyle(fontSize: 12, color: AppStyle.muted)),
            ],
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            _InfoCard(
              icon: Icons.bookmark_add_outlined,
              text: '복습 목록이 비어 있어요.\n학습 화면에서 발음을 선택하고 ‘복습에 추가’를 눌러 보세요.',
            )
          else
            Container(
              key: const Key('review_grouped_list'),
              decoration: AppStyle.card(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                key: const Key('review_rows_auto_only_v7'),
                children: [
                  for (final entry in sorted.asMap().entries) ...[
                    if (entry.key > 0)
                      const Divider(height: 1, color: AppStyle.softBorder),
                    _ReviewPhonemeTile(
                      phoneme: entry.value,
                      completed: _reviewedToday.contains(entry.value),
                      onPractice: () => widget.onPractice(entry.value),
                      onRemove: () => _removeFromQueue(entry.value),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 25),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('지난 학습 기록', style: AppStyle.heading(size: 19)),
            TextButton.icon(
              onPressed: _openCalendar,
              label: const Text('전체 보기'),
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              iconAlignment: IconAlignment.end,
            ),
          ]),
          const SizedBox(height: 8),
          if (DemoScenarios.current == DemoScenario.studied &&
              _localActivities.any((a) => a.type == 'practiced'))
            _RecentActivitiesCard(
              activities: _localActivities,
              onOpenCalendar: _openCalendar,
            )
          else if (_results.isNotEmpty)
            _RecentResultCard(result: _results.first)
          else if (_localActivities.any((a) => a.type == 'practiced'))
            _RecentActivitiesCard(
              activities: _localActivities,
              onOpenCalendar: _openCalendar,
            )
          else if (_serverLoading)
            const Padding(padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()))
          else if (_serverUnavailable)
            _InfoCard(
              icon: Icons.wifi_off_rounded,
              text: '서버에 연결할 수 없어 분석 기록을 불러오지 못했어요.\n'
                '날짜별 학습 기록은 ‘전체 보기’에서 확인할 수 있어요.',
              onRetry: _load,
            )
          else
            const _InfoCard(
              icon: Icons.history_rounded,
              text: '아직 저장된 발음 연습 기록이 없어요.\n'
                '촬영 후 분석 결과를 확인하면 여기에 나타나요.',
            ),
          const SizedBox(height: 18),
          const Text('복습 목록은 사용자가 직접 선택한 발음이에요.\n'
            'AI 기반 자동 복습 추천 기능은 아직 제공하지 않아요.',
            style: TextStyle(fontSize: 11, color: AppStyle.muted, height: 1.55)),
        ],
      ),
    );
  }
}

/// 복습 목록은 하나의 카드 안에 한 발음씩 행으로 표시한다.
/// 완료 표시는 버튼이 아닌 오늘의 실제 연습 결과를 읽은 상태 표시다.
class _ReviewPhonemeTile extends StatelessWidget {
  final String phoneme;
  final bool completed;
  final VoidCallback onPractice;
  final VoidCallback onRemove;
  const _ReviewPhonemeTile({required this.phoneme, required this.completed,
    required this.onPractice, required this.onRemove});

  static const _consonantSyllables = <String, String>{
    'ㄱ': '가', 'ㄲ': '까', 'ㅋ': '카',
    'ㄴ': '나', 'ㄷ': '다', 'ㄸ': '따', 'ㅌ': '타',
    'ㄹ': '라', 'ㅁ': '마', 'ㅂ': '바', 'ㅃ': '빠', 'ㅍ': '파',
    'ㅅ': '사', 'ㅆ': '싸', 'ㅈ': '자', 'ㅉ': '짜', 'ㅊ': '차',
    'ㅎ': '하', 'ㅇ': '아',
  };

  @override
  Widget build(BuildContext context) {
    final syllable = _consonantSyllables[phoneme];
    final label = syllable == null
        ? '모음 $phoneme'
        : '자음 $phoneme · $syllable';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Container(
          width: 48, height: 48, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppStyle.paleCoral,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(phoneme, style: const TextStyle(
            fontSize: 23, color: AppStyle.coral, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppStyle.ink, fontWeight: FontWeight.w800,
                fontSize: 14,
              )),
            const SizedBox(height: 5),
            // 상태는 읽기 전용 표시이며 체크/취소를 직접 누를 수 없다.
            // 촬영·분석 성공 시 LearningProgress.revision을 통해 자동 갱신된다.
            Semantics(
              label: '$phoneme ${completed ? '오늘 복습 완료' : '오늘 복습 전'}',
              liveRegion: true,
              child: Row(children: [
                Icon(completed ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                  size: 14, color: completed ? AppStyle.coral : AppStyle.muted),
                const SizedBox(width: 4),
                Flexible(child: Text(
                  completed ? '오늘 복습 완료' : '오늘 복습 전',
                  key: Key('review_status_$phoneme'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppStyle.muted),
                )),
              ]),
            ),
          ],
        )),
        const SizedBox(width: 4),
        OutlinedButton(
          key: Key('review_practice_$phoneme'),
          onPressed: onPractice,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(58, 44),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.compact,
            side: const BorderSide(color: AppStyle.softBorder),
          ),
          child: const Text('복습', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w800)),
        ),
        IconButton(
          key: Key('review_remove_$phoneme'),
          onPressed: onRemove,
          tooltip: '$phoneme 복습 목록에서 삭제',
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.close_rounded, size: 19,
            color: AppStyle.muted),
        ),
      ]),
    );
  }
}

class _RecentResultCard extends StatelessWidget {
  final FeedbackResult result;
  const _RecentResultCard({required this.result});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white, borderRadius: BorderRadius.circular(15),
    child: InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ReviewResultDetailScreen(result: result))),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: AppStyle.card(radius: 15),
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(width: 50, height: 50, alignment: Alignment.center,
            decoration: BoxDecoration(color: AppStyle.paleCoral,
              borderRadius: BorderRadius.circular(13)),
            child: Text(result.targetItem, style: const TextStyle(
              fontSize: 23, color: AppStyle.coral, fontWeight: FontWeight.w800))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${result.category} · ${result.targetPronunciation}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(result.createdAt, style: const TextStyle(
              fontSize: 11, color: AppStyle.muted)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: AppStyle.coral),
        ]),
      ),
    ),
  );
}

/// B 시연 상태처럼 서버 피드백은 없지만 성공한 연습 활동이 있는 경우의 최근 기록.
/// 학습 횟수는 동일 날짜/글자에서 여러 번 연습하면 각각 계산한다.
class _RecentActivitiesCard extends StatelessWidget {
  final List<LearningActivity> activities;
  final VoidCallback onOpenCalendar;
  const _RecentActivitiesCard({required this.activities, required this.onOpenCalendar});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<String>>{};
    for (final activity in activities) {
      if (activity.type != 'practiced') continue;
      final date = activity.at;
      final key = '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => <String>[]).add(activity.phoneme);
    }
    final dates = grouped.keys.take(3).toList();
    return Material(
      key: const Key('review_recent_practice_records'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onOpenCalendar,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: AppStyle.card(radius: 15),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var index = 0; index < dates.length; index++) ...[
              if (index > 0) const Divider(color: AppStyle.softBorder, height: 19),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(dates[index], style: const TextStyle(
                    color: AppStyle.ink, fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(grouped[dates[index]]!.toSet().join(' · '),
                    style: const TextStyle(color: AppStyle.coral,
                      fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('연습 ${grouped[dates[index]]!.length}회',
                    style: const TextStyle(color: AppStyle.muted, fontSize: 11)),
                ])),
                const Icon(Icons.chevron_right_rounded, color: AppStyle.coral),
              ]),
            ],
            if (DemoScenarios.isActive)
              const Padding(padding: EdgeInsets.only(top: 7),
                child: Text('시연용 기록', style: TextStyle(
                  color: AppStyle.muted, fontSize: 10))),
          ]),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onRetry;
  const _InfoCard({required this.text, required this.icon, this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19), decoration: AppStyle.card(),
    child: Column(children: [
      Icon(icon, size: 32, color: AppStyle.muted),
      const SizedBox(height: 9),
      Text(text, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppStyle.muted, height: 1.6)),
      if (onRetry != null) ...[
        const SizedBox(height: 10),
        TextButton(onPressed: onRetry, child: const Text('다시 연결')),
      ],
    ]),
  );
}
