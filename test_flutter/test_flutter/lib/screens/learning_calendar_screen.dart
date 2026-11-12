import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/feedback_result.dart';
import '../services/feedback_api.dart';
import '../services/learning_progress.dart';
import '../services/demo_scenarios.dart';
import '../ui/app_style.dart';
import '../services/pronunciation_record_filter.dart';
import 'calendar_day_results_screen.dart';
import 'phoneme_progress_chart_screen.dart';

const _activePhonemes = <String>{
  'ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ','ㅅ','ㅆ','ㅇ','ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ',
  'ㅏ','ㅐ','ㅑ','ㅒ','ㅓ','ㅔ','ㅕ','ㅖ','ㅗ','ㅘ','ㅙ','ㅚ','ㅛ','ㅜ','ㅝ','ㅞ','ㅟ','ㅠ','ㅡ','ㅢ','ㅣ',
};

/// 발음 연습 성공은 로컬에, 저장된 세부 분석 결과는 서버에 기록한다.
/// 로컬 촬영·분석 성공 횟수와 서버에 별도로 저장된 결과 건수를 구별한다.
/// 서버 결과에는 로컬 연습과 매칭할 공통 시도 ID가 없으므로 합산하지 않는다.
class LearningCalendarScreen extends StatefulWidget {
  final ValueChanged<String> onPractice;
  final bool initialLatestActivity;
  const LearningCalendarScreen({super.key, required this.onPractice,
    this.initialLatestActivity = false});

  @override
  State<LearningCalendarScreen> createState() => _LearningCalendarScreenState();
}

class _DayEntry {
  final String phoneme;
  bool studied = false;
  bool reviewed = false;
  int localPracticeCount = 0;
  int savedPracticeCount = 0;
  final List<FeedbackResult> savedResults = <FeedbackResult>[];

  _DayEntry(this.phoneme);
}

class _LearningCalendarScreenState extends State<LearningCalendarScreen> {
  late DateTime _shownMonth;
  late DateTime _selectedDate;
  Map<String, Map<String, _DayEntry>> _entries = {};
  List<FeedbackResult> _allSavedResults = [];
  bool _loading = true;
  bool _serverUnavailable = false;
  bool _initialResolved = false;
  // Keep date selection on this page; scroll to the inline detail section.
  final GlobalKey _dayRecordHeaderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _shownMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _load();
    LearningProgress.revision.addListener(_load);
  }

  @override
  void dispose() {
    LearningProgress.revision.removeListener(_load);
    super.dispose();
  }

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  _DayEntry _record(Map<String, Map<String, _DayEntry>> data,
      DateTime day, String phoneme) {
    final items = data.putIfAbsent(_dayKey(day), () => {});
    return items.putIfAbsent(phoneme, () => _DayEntry(phoneme));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final activities = await LearningProgress.readActivities();
    final data = <String, Map<String, _DayEntry>>{};
    for (final activity in activities) {
      final entry = _record(data, activity.at, activity.phoneme);
      if (activity.type == 'practiced') {
        entry.studied = true;
        entry.localPracticeCount++;
      }
      if (activity.type == 'reviewed') entry.reviewed = true;
    }

    var unavailable = false;
    var savedResults = <FeedbackResult>[];
    try {
      final results = await FeedbackApi.getAllReviewResults(
        userId: AppConfig.currentUserId,
      );
      savedResults = results;
      for (final result in results) {
        // Local practice flags are not server feedback; only actual saved
        // consonant/vowel analyses can appear in the results and trend views.
        if (!_activePhonemes.contains(result.targetItem) ||
            (result.category != '자음' && result.category != '모음')) {
          continue;
        }
        final local = feedbackRecordedAt(result);
        if (local == null) continue;
        final entry = _record(data, local, result.targetItem);
        entry.savedPracticeCount++;
        entry.savedResults.add(result);
      }
    } catch (_) {
      unavailable = true;
    }
    if (widget.initialLatestActivity && !_initialResolved) {
      _initialResolved = true;
      final recentDays = data.keys.toList()..sort();
      if (recentDays.isNotEmpty) {
        final last = DateTime.tryParse(recentDays.last);
        if (last != null) {
          _selectedDate = last;
          _shownMonth = DateTime(last.year, last.month);
        }
      }
    }
    if (mounted) {
      setState(() {
        _entries = data;
        _allSavedResults = savedResults;
        _serverUnavailable = unavailable;
        _loading = false;
      });
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _shownMonth = DateTime(_shownMonth.year, _shownMonth.month + offset);
      _selectedDate = _shownMonth;
    });
  }

  void _showRecordAggregationInfo() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppStyle.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppStyle.softBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppStyle.coral, size: 22),
            const SizedBox(width: 9),
            Text('기록 집계 기준', style: AppStyle.heading(size: 19)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AggregationInfoSection(
                title: '이 기기의 연습 기록',
                description:
                    '촬영·분석이 성공해 발음 결과 화면이 표시된 연습을 이 기기에 기록해요.',
              ),
              const SizedBox(height: 14),
              _AggregationInfoSection(
                title: '저장된 피드백 기록',
                description:
                    '발음 결과 화면에서 저장을 선택해 서버에 보관한 상세 분석 결과의 건수예요.',
              ),
              const SizedBox(height: 14),
              _AggregationInfoSection(
                title: '두 기록은 따로 집계해요',
                description:
                    '두 기록을 연결하는 공통 시도 ID가 없어서 같은 연습에서 만들어졌는지 확인할 수 없어요. '
                    '중복 계산을 피하기 위해 합산하지 않고 각각 표시해요.',
              ),
              if (DemoScenarios.isActive) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppStyle.paleCoral,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '현재 시연 모드에는 예시 기록이 포함될 수 있으며, 실제 사용자의 활동이나 AI 측정값이 아닙니다.',
                    style: TextStyle(
                      color: AppStyle.ink,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final year = _shownMonth.year;
    final month = _shownMonth.month;
    final dayCount = DateTime(year, month + 1, 0).day;
    final leadingEmpty = DateTime(year, month, 1).weekday % 7;
    final cellCount = ((dayCount + leadingEmpty + 6) ~/ 7) * 7;
    final dayEntries = _entries[_dayKey(_selectedDate)] ?? {};
    final sorted = dayEntries.values.toList()
      ..sort((a, b) => a.phoneme.compareTo(b.phoneme));

    return Scaffold(
      backgroundColor: AppStyle.background,
      appBar: AppBar(title: const Text('전체 학습 기록')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Text('날짜별 학습 기록', style: AppStyle.heading(size: 24)),
            const SizedBox(height: 5),
            const Text('날짜를 누르면 아래에서 해당 날짜의 학습 기록을 확인할 수 있어요.',
              style: TextStyle(color: AppStyle.muted, fontSize: 12)),
            const SizedBox(height: 20),
            if (DemoScenarios.isActive) ...[
              Container(
                decoration: AppStyle.card(color: AppStyle.paleCoral),
                padding: const EdgeInsets.all(12),
                child: const Text('시연용 학습 날짜·분석 기록입니다. 실제 활동이나 AI 측정값이 아닙니다.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              decoration: AppStyle.card(),
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 17),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  IconButton(tooltip: '이전 달', onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded)),
                  Text('$year년 $month월', style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
                  IconButton(tooltip: '다음 달', onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  for (final label in ['일', '월', '화', '수', '목', '금', '토'])
                    Expanded(child: Center(child: Text(label,
                      style: const TextStyle(color: AppStyle.muted,
                        fontSize: 12, fontWeight: FontWeight.w700)))),
                ]),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: cellCount,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7, crossAxisSpacing: 3,
                    mainAxisSpacing: 4, childAspectRatio: .78,
                  ),
                  itemBuilder: (context, index) {
                    final day = index - leadingEmpty + 1;
                    if (day < 1 || day > dayCount) {
                      return const SizedBox.shrink();
                    }
                    final date = DateTime(year, month, day);
                    final dayData = _entries[_dayKey(date)] ?? {};
                    final letters = dayData.keys.toList()..sort();
                    final selected = _selectedDate.year == year &&
                        _selectedDate.month == month && _selectedDate.day == day;
                    return Material(
                      color: selected ? AppStyle.paleCoral : Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        key: Key('calendar_day_${_dayKey(date)}'),
                        onTap: () {
                          setState(() => _selectedDate = date);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            final section = _dayRecordHeaderKey.currentContext;
                            if (section != null) {
                              Scrollable.ensureVisible(section,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeInOut,
                                alignment: 0.35,
                              );
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: selected
                              ? AppStyle.coral : AppStyle.softBorder),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text('$day', style: TextStyle(fontSize: 12,
                              fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
                            const SizedBox(height: 4),
                            if (letters.isNotEmpty)
                              Text('${letters.take(2).join('·')}${letters.length > 2 ? '+' : ''}',
                                maxLines: 1, overflow: TextOverflow.clip,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 9,
                                  fontWeight: FontWeight.w800, color: AppStyle.coral)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ]),
            ),
            if (_loading) ...[
              const SizedBox(height: 14),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_serverUnavailable) ...[
              const SizedBox(height: 14),
              const Text('서버 기록을 불러오지 못했어요. 기기에 기록된 발음 연습·복습 이력은 계속 볼 수 있어요.',
                style: TextStyle(fontSize: 12, color: AppStyle.muted)),
            ],
            const SizedBox(height: 22),
            Row(key: _dayRecordHeaderKey, children: [
              Expanded(child: Text('${_selectedDate.month}월 ${_selectedDate.day}일 학습 기록',
                style: AppStyle.heading(size: 18))),
              Text('${sorted.length}개 발음', style: const TextStyle(
                fontSize: 12, color: AppStyle.muted)),
            ]),
            const SizedBox(height: 9),
            // 날짜별 상세 정보를 별도 페이지 없이 같은 화면 아래에 표시한다.
            Column(key: const Key('calendar_selected_day_records'), children: [
              if (sorted.isEmpty)
                Container(decoration: AppStyle.card(),
                  padding: const EdgeInsets.all(16),
                  child: const Text('이 날짜에는 학습 기록이 없어요.')),
              for (final entry in sorted) ...[
                _DailyEntryTile(
                  key: Key('calendar_entry_${entry.phoneme}'),
                  entry: entry,
                  onTrend: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) =>
                      PhonemeProgressChartScreen(
                        phoneme: entry.phoneme,
                        records: _allSavedResults,
                      )),
                    ),
                  onDayResults: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) =>
                      CalendarDayResultsScreen(
                        selectedDate: _selectedDate,
                        phoneme: entry.phoneme,
                        records: entry.savedResults,
                      )),
                    ),
                ),
                const SizedBox(height: 10),
              ],
            ]),
            const SizedBox(height: 17),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('calendar_record_aggregation_info'),
                onPressed: _showRecordAggregationInfo,
                icon: const Icon(Icons.info_outline_rounded, size: 16),
                label: const Text('기록 집계 기준'),
                style: TextButton.styleFrom(
                  foregroundColor: AppStyle.muted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AggregationInfoSection extends StatelessWidget {
  final String title;
  final String description;

  const _AggregationInfoSection({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: AppStyle.ink,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        description,
        style: const TextStyle(
          color: AppStyle.muted,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    ],
  );
}

class _DailyEntryTile extends StatelessWidget {
  final _DayEntry entry;
  final VoidCallback onTrend;
  final VoidCallback onDayResults;
  const _DailyEntryTile({super.key, required this.entry, required this.onTrend,
    required this.onDayResults});

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      if (entry.studied) '발음 연습 완료',
      if (entry.reviewed) '복습 완료',
      if (entry.localPracticeCount > 0) '이 기기 연습 ${entry.localPracticeCount}회',
      if (entry.savedPracticeCount > 0) '저장된 피드백 ${entry.savedPracticeCount}건',
    ];
    return Container(
      decoration: AppStyle.card(), padding: const EdgeInsets.all(13),
      child: Row(children: [
        Container(width: 49, height: 49, alignment: Alignment.center,
          decoration: BoxDecoration(color: AppStyle.paleCoral,
            borderRadius: BorderRadius.circular(12)),
          child: Text(entry.phoneme, style: const TextStyle(
            color: AppStyle.coral, fontSize: 23, fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.phoneme, style: const TextStyle(
            color: AppStyle.ink, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(labels.join(' · '), style: const TextStyle(
            fontSize: 11, color: AppStyle.muted, height: 1.4)),
        ])),
        IconButton(
          key: Key('calendar_trend_${entry.phoneme}'),
          tooltip: '발음별 전체 학습 변화',
          onPressed: onTrend,
          icon: const Icon(Icons.insights_outlined, color: AppStyle.coral),
        ),
        IconButton(
          key: Key('calendar_day_results_${entry.phoneme}'),
          tooltip: '선택 날짜 분석 결과 목록',
          onPressed: onDayResults,
          icon: const Icon(Icons.arrow_forward_rounded, color: AppStyle.coral),
        ),
      ]),
    );
  }
}
