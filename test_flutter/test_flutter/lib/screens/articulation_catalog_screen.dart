import 'package:flutter/material.dart';

import '../data/pronunciation_image_data.dart';
import '../services/learning_progress.dart';
import '../services/review_queue.dart';
import '../ui/app_style.dart';
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
  bool _completed = false;
  bool _inReviewQueue = false;

  @override
  void initState() {
    super.initState();
    _choose(widget.initialPhoneme ?? 'ㅏ');
    _readCompletion();
    _readReviewQueue();
    LearningProgress.revision.addListener(_readCompletion);
  }

  @override
  void dispose() {
    LearningProgress.revision.removeListener(_readCompletion);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ArticulationCatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPhoneme != null &&
        widget.initialPhoneme != oldWidget.initialPhoneme) {
      _choose(widget.initialPhoneme!);
      _readCompletion();
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

  Future<void> _readCompletion() async {
    final phoneme = _phoneme;
    final done = (await LearningProgress.read()).contains(phoneme);
    if (mounted && _phoneme == phoneme) {
      setState(() => _completed = done);
    }
  }

  void _selectPhoneme(String phoneme) {
    setState(() => _choose(phoneme));
    _readCompletion();
    _readReviewQueue();
  }

  Future<void> _readReviewQueue() async {
    final phoneme = _phoneme;
    final reviewed = (await ReviewQueue.read()).contains(phoneme);
    if (mounted && _phoneme == phoneme) {
      setState(() => _inReviewQueue = reviewed);
    }
  }

  Future<void> _toggleReviewQueue() async {
    final phoneme = _phoneme;
    final included = !_inReviewQueue;
    await ReviewQueue.setIncluded(phoneme, included);
    if (mounted && _phoneme == phoneme) {
      setState(() => _inReviewQueue = included);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(included ? '$phoneme 발음을 복습 목록에 추가했어요.'
            : '$phoneme 발음을 복습 목록에서 삭제했어요.'),
      ));
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
    if (mounted) _readCompletion();
  }

  String? _imagePath() {
    final original = pronunciationImagePaths[_phoneme];
    if (original == null) return null;
    if (_isConsonant && !original.endsWith('/a.png')) {
      final filename = original.split('/').last;
      return 'lib/assets/images/pronunciation/focus/$filename';
    }
    return original;
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
                  if (_completed) ...[
                    const Icon(Icons.check_circle_rounded,
                      key: Key('practice_complete_indicator'),
                      color: AppStyle.sage, size: 20),
                    const SizedBox(width: 6),
                  ],
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
                child: const Row(children: [
                  Icon(Icons.touch_app_outlined,
                      color: AppStyle.sage, size: 17),
                  SizedBox(width: 8),
                  Expanded(child: Text('아래 글자를 누르면 그림이 바뀌어요.',
                    style: TextStyle(color: AppStyle.ink, fontSize: 12))),
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
          onPressed: _toggleReviewQueue,
          icon: Icon(_inReviewQueue ? Icons.bookmark_added_rounded
              : Icons.bookmark_add_outlined),
          label: Text(_inReviewQueue ? '복습 목록에 추가됨 · 누르면 삭제' : '복습에 추가'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppStyle.coral,
            minimumSize: const Size.fromHeight(51),
            side: const BorderSide(color: AppStyle.softBorder),
          ),
        ),
        if (_completed) ...[
          const SizedBox(height: 10),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_rounded, color: AppStyle.sage, size: 17),
            SizedBox(width: 6),
            Text('1회 이상 발음 연습 완료',
              style: TextStyle(color: AppStyle.muted, fontSize: 12)),
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
