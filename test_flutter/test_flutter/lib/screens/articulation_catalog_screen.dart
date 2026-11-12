import 'package:flutter/material.dart';

import '../data/pronunciation_image_data.dart';
import '../services/feedback_api.dart';
import '../services/review_queue.dart';
import '../ui/app_style.dart';
import '../ui/app_snackbar.dart';
import 'feedback_screen.dart';
import 'study_screen.dart';

/// Main study catalog: the articulation diagram, not cards, is the hero.
class ArticulationCatalogScreen extends StatefulWidget {
  final String? initialPhoneme;
  final VoidCallback? onBackToCategories;
  const ArticulationCatalogScreen({super.key, this.initialPhoneme,
    this.onBackToCategories});

  @override
  State<ArticulationCatalogScreen> createState() => _ArticulationCatalogScreenState();
}

class _ArticulationCatalogScreenState extends State<ArticulationCatalogScreen> {
  static const consonantGroups = <String, List<String>>{
    '두입술': ['ㅂ', 'ㅃ', 'ㅍ', 'ㅁ'],
    '잇몸': ['ㄷ', 'ㄸ', 'ㅌ', 'ㄴ', 'ㄹ', 'ㅅ', 'ㅆ'],
    '센입천장': ['ㅈ', 'ㅉ', 'ㅊ'],
    '여린입천장': ['ㄱ', 'ㄲ', 'ㅋ', 'ㅇ'],
    '목청': ['ㅎ'],
  };
  static const vowelGroups = <String, List<String>>{
    '단모음': ['ㅣ', 'ㅔ', 'ㅐ', 'ㅏ', 'ㅓ', 'ㅡ', 'ㅜ', 'ㅗ', 'ㅚ', 'ㅟ'],
    '이중모음': ['ㅑ', 'ㅕ', 'ㅛ', 'ㅠ', 'ㅒ', 'ㅖ', 'ㅘ', 'ㅙ', 'ㅝ', 'ㅞ', 'ㅢ'],
  };
  static const groupColors = <String, Color>{
    '두입술': Color(0xFFB85F4C),
    '잇몸': Color(0xFFA06B2B),
    '센입천장': Color(0xFF427B66),
    '여린입천장': Color(0xFF4E729F),
    '목청': Color(0xFF79669D),
    '단모음': Color(0xFF427B66),
    '이중모음': Color(0xFFB85F4C),
  };
  static const groupDescriptions = <String, String>{
    '두입술': '두 입술을 붙이거나 가까이해서 만드는 소리',
    '잇몸': '혀끝과 윗잇몸 근처에서 만드는 소리',
    '센입천장': '혀 앞부분과 단단한 입천장 쪽에서 만드는 소리',
    '여린입천장': '혀 뒷부분과 부드러운 입천장 쪽에서 만드는 소리',
    '목청': '성문에서 공기 흐름을 조절하며 만드는 소리',
    '단모음': '발음하는 동안 입 모양이 비교적 유지되는 소리',
    '이중모음': '발음하는 동안 입 모양이 움직이는 소리',
  };

  late bool _isConsonant;
  late String _group;
  late String _phoneme;
  int? _savedPracticeCount;
  bool _isLoadingSavedCount = false;
  String? _savedCountError;
  int _savedCountRequestId = 0;
  bool _inReviewQueue = false;
  bool _isLoadingReviewQueue = true;
  bool _reviewQueueLoadFailed = false;
  bool _isUpdatingReviewQueue = false;

  static const Color _reviewQueuedBackground = Color(0xFFFFEFED);
  static const Color _reviewQueuedBorder = Color(0xFFF5CEC9);

  @override
  void initState() {
    super.initState();
    _choose(widget.initialPhoneme ?? 'ㅏ');
    _readSavedPracticeCount();
    _readReviewQueue();
  }

  @override
  void dispose() {
    // In-flight count requests are ignored by mounted/request-id checks.
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArticulationCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPhoneme != null &&
        widget.initialPhoneme != oldWidget.initialPhoneme) {
      _choose(widget.initialPhoneme!);
      _inReviewQueue = false;
      _isLoadingReviewQueue = true;
      _reviewQueueLoadFailed = false;
      _readSavedPracticeCount();
      _readReviewQueue();
    }
  }

  void _choose(String phoneme) {
    for (final group in consonantGroups.entries) {
      if (group.value.contains(phoneme)) {
        _isConsonant = true;
        _group = group.key;
        _phoneme = phoneme;
        return;
      }
    }
    for (final group in vowelGroups.entries) {
      if (group.value.contains(phoneme)) {
        _isConsonant = false;
        _group = group.key;
        _phoneme = phoneme;
        return;
      }
    }
    _isConsonant = true;
    _group = '두입술';
    _phoneme = 'ㅂ';
  }

  /// Count only records explicitly saved through /feedback/save.
  /// Shows the last known count immediately and refreshes it through COUNT(*).
  Future<void> _readSavedPracticeCount({bool forceRefresh = false}) async {
    final phoneme = _phoneme;
    final category = _isConsonant ? '자음' : '모음';
    final requestId = ++_savedCountRequestId;
    final cachedCount = FeedbackApi.cachedSavedPracticeCount(
      category: category,
      targetItem: phoneme,
    );

    if (mounted) {
      setState(() {
        _savedPracticeCount = cachedCount;
        // Revisited phonemes are displayed immediately from the session cache.
        _isLoadingSavedCount = cachedCount == null;
        _savedCountError = null;
      });
    }

    try {
      final count = await FeedbackApi.getSavedPracticeCount(
        category: category,
        targetItem: phoneme,
        forceRefresh: forceRefresh,
      );

      // Ignore an older response if another phoneme was selected meanwhile.
      if (!mounted || requestId != _savedCountRequestId ||
          _phoneme != phoneme || (_isConsonant ? '자음' : '모음') != category) {
        return;
      }

      setState(() {
        _savedPracticeCount = count;
        _isLoadingSavedCount = false;
        _savedCountError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('저장된 $category $phoneme 연습 횟수 조회 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted || requestId != _savedCountRequestId ||
          _phoneme != phoneme || (_isConsonant ? '자음' : '모음') != category) {
        return;
      }
      setState(() {
        _isLoadingSavedCount = false;
        // Retain a cached value, but let the user retry a failed refresh.
        _savedCountError = _savedPracticeCount == null
            ? '발음 연습 기록을 불러오지 못했어요.'
            : '최신 발음 연습 기록을 확인하지 못했어요.';
      });
    }
  }

  void _selectPhoneme(String phoneme) {
    setState(() {
      _choose(phoneme);
      _inReviewQueue = false;
      _isLoadingReviewQueue = true;
      _reviewQueueLoadFailed = false;
    });
    _readSavedPracticeCount();
    _readReviewQueue();
  }

  Future<void> _readReviewQueue() async {
    final phoneme = _phoneme;
    try {
      final reviewed = (await ReviewQueue.read()).contains(phoneme);
      if (mounted && _phoneme == phoneme) {
        setState(() {
          _inReviewQueue = reviewed;
          _isLoadingReviewQueue = false;
          _reviewQueueLoadFailed = false;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('복습 목록 상태 조회 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted && _phoneme == phoneme) {
        setState(() {
          _inReviewQueue = false;
          _isLoadingReviewQueue = false;
          _reviewQueueLoadFailed = true;
        });
      }
    }
  }

  Future<void> _retryReadReviewQueue() async {
    if (_isLoadingReviewQueue) return;
    setState(() {
      _isLoadingReviewQueue = true;
      _reviewQueueLoadFailed = false;
    });
    await _readReviewQueue();
  }

  Future<void> _toggleReviewQueue() async {
    if (_isUpdatingReviewQueue || _isLoadingReviewQueue ||
        _reviewQueueLoadFailed) return;

    final phoneme = _phoneme;
    final included = !_inReviewQueue;
    setState(() => _isUpdatingReviewQueue = true);
    try {
      await ReviewQueue.setIncluded(phoneme, included);
      if (!mounted || _phoneme != phoneme) return;
      setState(() => _inReviewQueue = included);
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar.info(
        included
            ? '$phoneme 발음을 복습 목록에 추가했어요.'
            : '$phoneme 발음을 복습 목록에서 제거했어요.',
        icon: included
            ? Icons.bookmark_added_outlined
            : Icons.bookmark_remove_outlined,
      ));
    } catch (error, stackTrace) {
      debugPrint('복습 목록 변경 실패: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted && _phoneme == phoneme) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBar.error('복습 목록을 업데이트하지 못했어요. 다시 시도해 주세요.'),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingReviewQueue = false);
    }
  }

  void _selectGroup(String group, List<String> phonemes) {
    _selectPhoneme(phonemes.first);
  }

  void _goToStudy() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => StudyScreen(
          item: _phoneme,
          category: _isConsonant ? '자음' : '모음',
        ),
      ));

  Future<void> _goToFeedback() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FeedbackScreen(
          item: _phoneme,
          category: _isConsonant ? '자음' : '모음',
        ),
      ));
    if (mounted) {
      _readSavedPracticeCount();
      setState(() {
        _isLoadingReviewQueue = true;
        _reviewQueueLoadFailed = false;
      });
      _readReviewQueue();
    }
  }

  String? _imagePath() {
    // 자음·모음 모두 pronunciation_image_data.dart의 정식 경로를 사용합니다.
    // 자음만 focus/ 폴더로 강제 전환하면 pubspec.yaml에 등록되지 않은
    // 경로를 찾게 되어 조음 그림을 불러오지 못할 수 있습니다.
    return pronunciationImagePaths[_phoneme];
  }

  @override
  Widget build(BuildContext context) {
    final groups = _isConsonant ? consonantGroups : vowelGroups;
    final accent = groupColors[_group] ?? AppStyle.sage;
    final imagePath = _imagePath();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 34),
      children: [
        if (widget.onBackToCategories != null) ...[
          Align(alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBackToCategories,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('발음 학습'),
            )),
          const SizedBox(height: 3),
        ],
        Text(_isConsonant ? '자음 학습' : '모음 학습',
          style: AppStyle.heading(size: 27)),
        const SizedBox(height: 6),
        const Text('그림으로 이해하고, 직접 발음해 보세요.',
          style: TextStyle(color: AppStyle.muted, fontSize: 13)),
        const SizedBox(height: 14),
        Text(_isConsonant ? '조음 위치 선택' : '모음 종류 선택', style: TextStyle(
          color: AppStyle.ink, fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 11),
        SizedBox(
          height: 43,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final entry in groups.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _PositionChip(
                    name: entry.key,
                    color: groupColors[entry.key] ?? AppStyle.sage,
                    selected: _group == entry.key,
                    onTap: () => _selectGroup(entry.key, entry.value),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AppStyle.card(radius: 23),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 0),
                child: Row(children: [
                  Container(width: 4, height: 27, decoration: BoxDecoration(
                    color: accent, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$_group 소리', style: const TextStyle(
                        fontSize: 16, color: AppStyle.ink,
                        fontWeight: FontWeight.w800,
                      )),
                      const SizedBox(height: 4),
                      Text(groupDescriptions[_group] ?? '',
                        style: const TextStyle(color: AppStyle.muted,
                            fontSize: 11, height: 1.35)),
                    ],
                  )),
                  Text(_phoneme, style: TextStyle(
                    color: accent, fontWeight: FontWeight.w900,
                    fontSize: 37, height: 1,
                  )),
                ]),
              ),
              LayoutBuilder(builder: (context, constraints) {
                final width = constraints.maxWidth;
                final diagramHeight = _isConsonant
                    ? (width * .76).clamp(220.0, 295.0).toDouble()
                    : (width * .69).clamp(208.0, 270.0).toDouble();
                return SizedBox(
                  height: diagramHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 6),
                    child: imagePath == null
                      ? const Center(child: Text('조음 그림 준비 중'))
                      : Image.asset(
                          imagePath,
                          fit: BoxFit.contain,
                          semanticLabel: '$_phoneme 발음 조음 위치 그림',
                          errorBuilder: (context, error, stackTrace) =>
                            const Center(child: Text('조음 그림을 불러오지 못했어요.')),
                        ),
                  ),
                );
              }),
              Container(
                color: AppStyle.softInk,
                padding: const EdgeInsets.fromLTRB(17, 12, 17, 12),
                child: Row(children: [
                  if (_isLoadingSavedCount && _savedPracticeCount == null) ...[
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: AppStyle.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('발음 연습 기록 확인 중...',
                        style: TextStyle(color: AppStyle.muted, fontSize: 12)),
                    ),
                  ] else if ((_savedPracticeCount ?? 0) > 0) ...[
                    const Icon(Icons.history_rounded,
                        color: AppStyle.sage, size: 17),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: '발음 연습 기록 '),
                          TextSpan(
                            text: '${_savedPracticeCount ?? 0}건',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ]),
                        style: const TextStyle(
                          color: AppStyle.ink,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.touch_app_outlined,
                        color: AppStyle.sage, size: 17),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('아래 글자를 누르면 그림이 바뀌어요.',
                        style: TextStyle(color: AppStyle.ink, fontSize: 12)),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 23),
        Row(children: [
          Text(_isConsonant ? '발음 선택' : '모음 선택',
              style: AppStyle.heading(size: 19)),
          const Spacer(),
          Text('${groups[_group]!.length}개', style: const TextStyle(
              color: AppStyle.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 11),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final phoneme in groups[_group]!)
            _LetterButton(
              value: phoneme,
              selected: phoneme == _phoneme,
              accent: accent,
              onTap: () => _selectPhoneme(phoneme),
            ),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: _goToStudy,
            icon: const Icon(Icons.menu_book_outlined, size: 19),
            label: const Text('발음 방법'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppStyle.ink,
              side: const BorderSide(color: AppStyle.softBorder, width: 1.5),
              minimumSize: const Size(0, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              textStyle: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w800),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: FilledButton.icon(
            onPressed: _goToFeedback,
            icon: const Icon(Icons.mic_none_rounded, size: 20),
            label: const Text('발음 연습하기'),
            style: FilledButton.styleFrom(
              backgroundColor: AppStyle.ink,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              textStyle: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w800),
            ),
          )),
        ]),
        const SizedBox(height: 13),
        OutlinedButton.icon(
          onPressed: _isUpdatingReviewQueue || _isLoadingReviewQueue
              ? null
              : (_reviewQueueLoadFailed
                  ? _retryReadReviewQueue
                  : _toggleReviewQueue),
          icon: _isUpdatingReviewQueue || _isLoadingReviewQueue
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppStyle.coral,
                  ),
                )
              : Icon(_inReviewQueue ? Icons.bookmark_rounded
                  : Icons.bookmark_add_outlined),
          label: Text(_isLoadingReviewQueue
              ? '복습 상태 확인 중...'
              : _reviewQueueLoadFailed
                  ? '복습 상태 다시 확인'
                  : _inReviewQueue
                      ? '복습 목록에서 제거'
                      : '복습 목록에 추가'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppStyle.coral,
            backgroundColor: _inReviewQueue
                ? _reviewQueuedBackground
                : Colors.white,
            minimumSize: const Size.fromHeight(51),
            side: BorderSide(
              color: _inReviewQueue
                  ? _reviewQueuedBorder
                  : AppStyle.softBorder,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (_savedCountError != null) ...[
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline_rounded,
                color: AppStyle.muted, size: 16),
            const SizedBox(width: 6),
            Flexible(child: Text(_savedCountError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppStyle.muted, fontSize: 12))),
            TextButton(
              onPressed: () => _readSavedPracticeCount(forceRefresh: true),
              style: TextButton.styleFrom(
                foregroundColor: AppStyle.coral,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('다시 확인', style: TextStyle(fontSize: 11)),
            ),
          ]),
        ],
      ],
    );
  }
}

class _PositionChip extends StatelessWidget {
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _PositionChip({required this.name, required this.color,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? color : AppStyle.paper,
    borderRadius: BorderRadius.circular(25),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: selected ? color : AppStyle.softBorder),
        ),
        child: Text(name, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppStyle.ink,
        )),
      ),
    ),
  );
}

class _LetterButton extends StatelessWidget {
  final String value;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _LetterButton({required this.value, required this.selected,
      required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? accent : AppStyle.paper,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 62, height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : AppStyle.softBorder,
          ),
        ),
        child: Text(value, style: TextStyle(
          color: selected ? Colors.white : AppStyle.ink,
          fontSize: 25, fontWeight: FontWeight.w800,
        )),
      ),
    ),
  );
}
