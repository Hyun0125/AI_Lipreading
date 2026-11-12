import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models/sentence_analysis_result.dart';
import '../services/sentence_analysis_api.dart';
import '../ui/app_style.dart';

import '../widgets/sentence_practice_feedback.dart';
import 'articulation_catalog_screen.dart';
import 'sentence_audio_detail_screen.dart';

/// Progress counts completed sentence requests, not model inference percent.
/// The current sentence and elapsed time are reported separately.
class AssessmentAnalysisScreen extends StatefulWidget {
  final VoidCallback onFinished;
  final List<String> sentences;
  final List<XFile> videos;

  const AssessmentAnalysisScreen({
    super.key,
    required this.onFinished,
    required this.sentences,
    required this.videos,
  });

  @override
  State<AssessmentAnalysisScreen> createState() => _AssessmentAnalysisScreenState();
}

class _AssessmentAnalysisScreenState extends State<AssessmentAnalysisScreen> {
  final List<SentenceAnalysisResult> _results = [];
  bool _running = false;
  String? _error;
  int _activeIndex = 0;
  int _elapsedSeconds = 0;
  int _attempts = 0;
  String _stage = '분석 준비 중';
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _analyzeRemaining();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _running) {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  String _describeError(Object error) {
    final value = error.toString();
    return value.replaceFirst(RegExp(r'^(Exception|Bad state):\s*'), '');
  }

  Future<void> _analyzeRemaining() async {
    if (_running) return;
    if (widget.sentences.length != widget.videos.length || widget.videos.isEmpty) {
      setState(() => _error = '문장과 영상 개수가 일치하지 않습니다.');
      return;
    }
    setState(() {
      _running = true;
      _error = null;
      _activeIndex = _results.length;
      _stage = '영상 파일 검증 중';
      _elapsedSeconds = 0;
      _attempts++;
    });
    _startClock();

    try {
      for (var i = _results.length; i < widget.sentences.length; i++) {
        if (!mounted) return;
        setState(() {
          _activeIndex = i;
          _stage = '영상 파일 검증 중';
          _elapsedSeconds = 0;
        });
        debugPrint('문장 분석 시작: ${i + 1}/${widget.sentences.length}');
        final result = await SentenceAnalysisApi.analyzeVideo(
          sentence: widget.sentences[i],
          video: widget.videos[i],
          onStatus: (stage) {
            if (mounted && _running) {
              setState(() => _stage = stage);
            }
          },
        );
        if (!mounted) return;
        setState(() {
          _results.add(result);
          _stage = '${i + 1}번째 문장 분석 완료';
        });
        debugPrint('문장 분석 완료: ${i + 1}/${widget.sentences.length}');
      }
    } catch (error, stack) {
      debugPrint('문장 ${_activeIndex + 1} 분석 요청 실패: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        setState(() => _error = _describeError(error));
      }
    } finally {
      _clock?.cancel();
      _clock = null;
      if (mounted) setState(() => _running = false);
    }
  }

  void _openReport() {
    if (_running || _results.length != widget.sentences.length) return;
    Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute<void>(builder: (_) => AssessmentReportScreen(
        onFinished: widget.onFinished,
        results: List<SentenceAnalysisResult>.unmodifiable(_results),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completed = _results.length;
    final total = widget.sentences.length;
    final allDone = completed == total && total > 0;
    final failed = _error != null && !_running;
    final active = _activeIndex + 1;
    final min = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final sec = (_elapsedSeconds % 60).toString().padLeft(2, '0');

    return PopScope(
      canPop: !_running,
      child: Scaffold(
        appBar: AppBar(title: const Text('문장 음성 분석')),
        body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 98, height: 98,
                    decoration: const BoxDecoration(shape: BoxShape.circle,
                      color: AppStyle.paleCoral),
                    child: Icon(
                      allDone ? Icons.check_circle_outline_rounded
                          : failed ? Icons.error_outline_rounded
                          : Icons.pending_actions_rounded,
                      color: AppStyle.coral, size: 49,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(allDone ? '문장 분석 결과가 준비됐어요'
                      : failed ? '${active}번째 문장을 분석하지 못했어요'
                      : '문장 음성을 분석하고 있어요',
                    textAlign: TextAlign.center,
                    style: AppStyle.heading(size: 23)),
                  const SizedBox(height: 12),
                  Text('$completed / $total 문장 분석 완료',
                    style: const TextStyle(fontSize: 14, color: AppStyle.muted)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    // Only COMPLETED requests advance the determinate bar.
                    value: total == 0 ? 0 : completed / total,
                    color: AppStyle.coral, backgroundColor: AppStyle.softBorder,
                    minHeight: 7, borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(height: 18),
                  if (_running) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: AppStyle.card(),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('현재 ${active} / $total 번째 문장',
                          style: const TextStyle(fontWeight: FontWeight.w800,
                            fontSize: 15, color: AppStyle.ink)),
                        const SizedBox(height: 6),
                        Text(_stage,
                          style: const TextStyle(fontSize: 13, color: AppStyle.muted)),
                        const SizedBox(height: 8),
                        Row(children: [
                          const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2,
                              color: AppStyle.coral)),
                          const SizedBox(width: 10),
                          Expanded(child: Text('경과 시간 $min:$sec · 결과 대기 중',
                            style: const TextStyle(fontSize: 12, color: AppStyle.muted))),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 3),
                  ],
                  if (failed) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: AppStyle.card(),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${active}번째 문장에서 요청이 실패했습니다.',
                          style: const TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w800, color: AppStyle.ink)),
                        const SizedBox(height: 8),
                        SelectableText(_error!,
                          style: const TextStyle(fontSize: 12, color: AppStyle.coral,
                            height: 1.5)),
                        const SizedBox(height: 7),
                        Text(_attempts > 1
                            ? '재시도 ${_attempts - 1}회 · 완료한 앞 문장은 다시 전송하지 않습니다.'
                            : '완료한 앞 문장은 다시 전송하지 않습니다.',
                          style: const TextStyle(fontSize: 12,
                            color: AppStyle.muted)),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    decoration: AppStyle.card(),
                    padding: const EdgeInsets.all(16),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded, color: AppStyle.coral),
                      SizedBox(width: 11),
                      Expanded(child: Text('문장 일치 수는 Whisper 인식 텍스트 비교 결과예요. '
                          'ETRI 발음 점수는 분석 후 리포트에서 별도로 확인할 수 있어요.',
                        style: TextStyle(fontSize: 12, height: 1.5))),
                    ]),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(width: double.infinity, child: FilledButton(
                    onPressed: allDone ? _openReport
                        : failed ? _analyzeRemaining : null,
                    child: Text(allDone ? '나의 발음 리포트 보기'
                        : failed ? '${active}번째 문장 다시 시도' : '분석 중...'),
                  )),
                ],
              ),
            ),
          );
        })),
      ),
    );
  }
}

// Display-only fallback for empty and plainly implausible Whisper output.
// The backend also filters near-silence before returning recognition text.
const String _unrecognizedSentenceMessage = '음성을 인식하지 못했어요.';

bool _isUnrecognizedSentence(SentenceAnalysisResult result) {
  final text = result.recognizedText.trim();
  if (text.isEmpty) return true;

  final compactLength = text.replaceAll(RegExp(r'\s+'), '').runes.length;
  final referenceLength =
      result.referenceText.replaceAll(RegExp(r'\s+'), '').runes.length;
  if (compactLength > (referenceLength * 3 > 40 ? referenceLength * 3 : 40)) {
    return true;
  }
  if (RegExp(r'([가-힣ㄱ-ㅎㅏ-ㅣ])\1{5,}').hasMatch(text)) return true;

  final korean = RegExp(r'[가-힣]').allMatches(text).length;
  final foreign = RegExp(r'[A-Za-z\u3400-\u9FFF]').allMatches(text).length;
  return korean == 0 || foreign > korean;
}

// ETRI's documented Korean pronunciation API returns a sentence score from
// 1 to 5 and a recognition string. Do not infer phoneme-level scores.
Map<String, dynamic>? _etriAssessment(SentenceAnalysisResult result) {
  final raw = result.voiceAnalysis['pronunciation_assessment'];
  return raw is Map ? Map<String, dynamic>.from(raw) : null;
}

double? _etriScore(SentenceAnalysisResult result) {
  final assessment = _etriAssessment(result);
  if (assessment == null || assessment['status'] == 'unavailable') return null;
  final raw = assessment['score'];
  final parsed = raw is num ? raw.toDouble() :
      raw is String ? double.tryParse(raw) : null;
  if (parsed == null || !parsed.isFinite || parsed < 1 || parsed > 5) {
    return null;
  }
  return parsed;
}

String? _etriRecognized(SentenceAnalysisResult result) {
  final assessment = _etriAssessment(result);
  if (_etriScore(result) == null || assessment == null) return null;
  final raw = assessment['recognized_text'];
  if (raw is! String || raw.trim().isEmpty) return null;
  return raw.trim();
}


// 문장 인식 결과의 '차이'를 학습 추천으로 연결합니다.
// 실제 발음 오류를 판정하거나 ETRI 문장 점수를 음소 점수로 변환하지 않습니다.
const String _supportedConsonants = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
// 현재 학습 기준 자료가 준비되지 않은 ㅒ·ㅖ는 추천에서 제외합니다.
const String _supportedVowels = 'ㅏㅐㅑㅓㅔㅕㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ';

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, val) => MapEntry(key.toString(), val));
}

String _str(Object? value) => value?.toString().trim() ?? '';

bool _isSupportedPhoneme(String phoneme, String position) {
  if (position == 'initial') return _supportedConsonants.contains(phoneme);
  if (position == 'vowel') return _supportedVowels.contains(phoneme);
  // 현재 자음 수업은 초성 연습 위주이므로 종성 오류는 잘못 연결하지 않습니다.
  return false;
}

class _JamoEvidence {
  final String phoneme;
  final String referenceSyllable;
  final String recognizedSyllable;
  final String position;
  final bool singleChange;
  final int order;
  final Set<String> sources = <String>{};

  _JamoEvidence({
    required this.phoneme,
    required this.referenceSyllable,
    required this.recognizedSyllable,
    required this.position,
    required this.singleChange,
    required this.order,
  });

  int get quality => (sources.length >= 2 ? 100 : 0) +
      (singleChange ? 20 : 0);

  String get sourceLabel {
    if (sources.contains('whisper') && sources.contains('etri')) {
      return 'Whisper·ETRI 모두에서 차이';
    }
    if (sources.contains('whisper')) return 'Whisper에서만 차이';
    if (sources.contains('etri')) return 'ETRI에서만 차이';
    return '음성 인식 결과에서 차이';
  }
}

class _PhonemeRecommendation {
  final String phoneme;
  _JamoEvidence bestEvidence;
  int occurrenceCount;

  _PhonemeRecommendation(this.phoneme, this.bestEvidence)
      : occurrenceCount = 1;

  bool get isVowel => _supportedVowels.contains(phoneme);
  int get rank => bestEvidence.quality +
      (occurrenceCount > 5 ? 5 : occurrenceCount) * 2;

  String get description =>
      '‘${bestEvidence.referenceSyllable}’ → '
      '‘${bestEvidence.recognizedSyllable}’ 인식 차이를 확인해 보세요.';
}

List<_PhonemeRecommendation> _extractPhonemeRecommendations(
    List<SentenceAnalysisResult> results) {
  // 동일 음절을 두 모델이 다르게 기록한 경우는 한 사례로 묶고 출처만 합칩니다.
  final evidenceByKey = <String, _JamoEvidence>{};
  var sequence = 0;

  for (var sentenceIndex = 0; sentenceIndex < results.length; sentenceIndex++) {
    final analysis = results[sentenceIndex].voiceAnalysis;
    final correction = _asStringMap(analysis['correction_candidates']);
    final candidates = correction['candidates'];
    if (candidates is! List) continue;

    for (final rawCandidate in candidates) {
      final candidate = _asStringMap(rawCandidate);
      final syllables = candidate['syllable_candidates'];
      if (syllables is! List) continue;
      final wordIndex = _str(candidate['word_index']);

      for (final rawSyllable in syllables) {
        final syllable = _asStringMap(rawSyllable);
        final reference = _str(syllable['expected']);
        final recognized = _str(syllable['recognized']);
        if (reference.isEmpty || recognized.isEmpty || reference == recognized) {
          continue;
        }
        final changes = syllable['jamo_changes'];
        if (changes is! List || changes.isEmpty) continue;
        final source = _str(syllable['source']);
        final syllableIndex = _str(syllable['reference_syllable_index']);
        // 하나의 음절에서 초·중·종성 중 몇 부분이 달라졌는지 구분합니다.
        final singleChange = changes.length == 1;

        for (final rawChange in changes) {
          final change = _asStringMap(rawChange);
          final position = _str(change['position']);
          final expected = _str(change['expected']);
          final recognizedJamo = _str(change['recognized']);
          if (expected.isEmpty || expected == recognizedJamo ||
              !_isSupportedPhoneme(expected, position)) continue;

          final key = '$sentenceIndex|$wordIndex|$syllableIndex|'
              '$reference|$recognized|$position|$expected|$recognizedJamo';
          final record = evidenceByKey.putIfAbsent(key, () => _JamoEvidence(
            phoneme: expected,
            referenceSyllable: reference,
            recognizedSyllable: recognized,
            position: position,
            singleChange: singleChange,
            order: sequence++,
          ));
          if (source == 'whisper' || source == 'etri') {
            record.sources.add(source);
          }
        }
      }
    }
  }

  final byPhoneme = <String, _PhonemeRecommendation>{};
  for (final evidence in evidenceByKey.values) {
    final current = byPhoneme[evidence.phoneme];
    if (current == null) {
      byPhoneme[evidence.phoneme] =
          _PhonemeRecommendation(evidence.phoneme, evidence);
    } else {
      current.occurrenceCount++;
      if (evidence.quality > current.bestEvidence.quality) {
        current.bestEvidence = evidence;
      }
    }
  }

  final ranked = byPhoneme.values.toList()
    ..sort((a, b) {
      final byRank = b.rank.compareTo(a.rank);
      if (byRank != 0) return byRank;
      return a.bestEvidence.order.compareTo(b.bestEvidence.order);
    });

  final selected = ranked.take(3).toList();
  // 자음과 모음 모두 후보가 있다면 최대 3개 안에 각 종류를 하나 이상 안내합니다.
  if (selected.length == 3) {
    final hasConsonant = ranked.any((item) => !item.isVowel);
    final hasVowel = ranked.any((item) => item.isVowel);
    if (hasConsonant && hasVowel) {
      final selectedHasConsonant = selected.any((item) => !item.isVowel);
      final selectedHasVowel = selected.any((item) => item.isVowel);
      if (!selectedHasVowel) {
        selected[2] = ranked.firstWhere((item) => item.isVowel);
      } else if (!selectedHasConsonant) {
        selected[2] = ranked.firstWhere((item) => !item.isVowel);
      }
      selected.sort((a, b) {
        final byRank = b.rank.compareTo(a.rank);
        if (byRank != 0) return byRank;
        return a.bestEvidence.order.compareTo(b.bestEvidence.order);
      });
    }
  }
  return selected;
}

void _openRecommendedPhoneme(BuildContext context, String phoneme) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (detailContext) => Scaffold(
      backgroundColor: AppStyle.background,
      body: SafeArea(child: ArticulationCatalogScreen(
        initialPhoneme: phoneme,
        onBackToCategories: () => Navigator.of(detailContext).pop(),
      )),
    ),
  ));
}

class _RecommendedPracticeInfo extends StatelessWidget {
  final _PhonemeRecommendation recommendation;
  const _RecommendedPracticeInfo({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final item = recommendation;
    return Container(
      decoration: AppStyle.card(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openRecommendedPhoneme(context, item.phoneme),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(children: [
              Container(
                width: 53, height: 53,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppStyle.paleCoral,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(item.phoneme, style: const TextStyle(
                    color: AppStyle.ink, fontSize: 24,
                    fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 13),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.phoneme} 발음 연습',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(item.description, style: const TextStyle(
                      color: AppStyle.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('${item.isVowel ? "모음" : "자음"} 학습 · '
                      '${item.bestEvidence.sourceLabel}',
                    style: const TextStyle(
                        color: AppStyle.muted, fontSize: 11)),
                ],
              )),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded,
                  color: AppStyle.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

class AssessmentReportScreen extends StatelessWidget {
  final VoidCallback onFinished;
  final List<SentenceAnalysisResult> results;

  const AssessmentReportScreen({
    super.key,
    required this.onFinished,
    required this.results,
  });

  @override
  Widget build(BuildContext context) {
    final matches = results.where((r) =>
        !_isUnrecognizedSentence(r) && r.normalizedMatch == true).length;
    final etriScores = results.map(_etriScore).whereType<double>().toList();
    final etriAverage = etriScores.isEmpty ? null :
        etriScores.reduce((a, b) => a + b) / etriScores.length;
    final recommendations = _extractPhonemeRecommendations(results);
    return Scaffold(
      appBar: AppBar(title: const Text('나의 발음 리포트')),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 25),
        children: [
          Text('진단 결과', style: AppStyle.heading(size: 27)),
          const SizedBox(height: 7),
          const Text('Whisper 음성 인식 비교 · ETRI 발음평가',
            style: TextStyle(color: AppStyle.muted, fontSize: 13)),
          const SizedBox(height: 23),
          Container(
            decoration: AppStyle.card(color: AppStyle.paleCoral),
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('문장 인식 결과',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                  color: AppStyle.ink)),
              const SizedBox(height: 7),
              Text('음성 인식 문장 일치 $matches / ${results.length}개',
                style: const TextStyle(fontSize: 15, color: AppStyle.ink)),
              const SizedBox(height: 6),
              const Text('이 수치는 음성 인식 텍스트의 일치 횟수이며, '
                  '실제 발음 정확도 점수 또는 진단 결과는 아니에요.',
                style: TextStyle(color: AppStyle.muted, fontSize: 12, height: 1.55)),
            ]),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: AppStyle.card(color: AppStyle.paleCoral),
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ETRI 문장 발음평가',
                style: TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 17, color: AppStyle.ink)),
              const SizedBox(height: 8),
              Text(etriAverage == null
                  ? 'ETRI 평가 점수 없음'
                  : '평균 ${etriAverage.toStringAsFixed(1)} / 5.0점',
                style: AppStyle.heading(size: 21)),
              const SizedBox(height: 6),
              Text('ETRI 평가 성공: ${etriScores.length} / ${results.length}문장',
                style: const TextStyle(fontSize: 13, color: AppStyle.ink)),
              const SizedBox(height: 6),
              const Text('ETRI 점수는 1~5점 범위의 문장 단위 발음평가입니다. '
                  'Whisper의 텍스트 일치 수나 자모음 입모양 점수와는 별개예요.',
                style: TextStyle(fontSize: 12, color: AppStyle.muted, height: 1.5)),
              if (etriAverage == null) ...[
                const SizedBox(height: 8),
                const Text('백엔드에서 ETRI API 키·허용 IP·네트워크를 확인해 주세요. '
                    'Whisper 문장 비교는 계속 사용할 수 있어요.',
                  style: TextStyle(fontSize: 12, color: AppStyle.muted, height: 1.5)),
              ],
            ]),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < results.length; i++) ...[
            Container(
              decoration: AppStyle.card(),
              padding: const EdgeInsets.all(15),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('${i + 1}번째 문장',
                        style: const TextStyle(fontWeight: FontWeight.w800,
                          color: AppStyle.ink, fontSize: 15)),
                    ),
                    SizedBox(
                      height: 44,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => SentenceAudioDetailScreen(
                              sentenceNumber: i + 1,
                              result: results[i],
                            ),
                          ));
                        },
                        icon: const Icon(Icons.analytics_outlined, size: 17),
                        label: const Text('상세보기'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppStyle.coral,
                          minimumSize: const Size(0, 44),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          visualDensity: VisualDensity.standard,
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text('기준 문장: ${results[i].referenceText}',
                  style: const TextStyle(fontSize: 13, color: AppStyle.ink)),
                const SizedBox(height: 6),
                Text('Whisper 인식 문장: ${_isUnrecognizedSentence(results[i]) ? _unrecognizedSentenceMessage : results[i].recognizedText}',
                  style: const TextStyle(fontSize: 13, color: AppStyle.ink)),
                const SizedBox(height: 12),
                Text(_etriScore(results[i]) == null
                    ? 'ETRI 발음 점수: 평가 불가'
                    : 'ETRI 발음 점수: ${_etriScore(results[i])!.toStringAsFixed(1)} / 5.0점',
                  style: const TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w800, color: AppStyle.ink)),
                if (_etriRecognized(results[i]) != null) ...[
                  const SizedBox(height: 6),
                  Text('ETRI 인식 문장: ${_etriRecognized(results[i])}',
                    style: const TextStyle(fontSize: 13, color: AppStyle.ink)),
                ],
                if (_etriScore(results[i]) == null) ...[
                  const SizedBox(height: 6),
                  const Text('ETRI 평가 결과를 불러오지 못했어요.',
                    style: TextStyle(fontSize: 12, color: AppStyle.muted)),
                ],
                // No secondary mismatch verdict for a failed recognition.
                if (!_isUnrecognizedSentence(results[i])) ...[
                  const SizedBox(height: 12),
                  Text(results[i].normalizedMatch == null
                      ? '텍스트 비교 정보가 없어요.'
                      : results[i].normalizedMatch! ? '음성 인식 문장 일치'
                      : '음성 인식 문장에 차이가 있어요.',
                    style: const TextStyle(fontSize: 12, color: AppStyle.muted)),
                ],
                // ETRI 문장 전체 재연습 안내 + Whisper·ETRI 비교 교정 후보.
                // 데이터가 없는 문장은 위젯 내부에서 빈 영역으로 처리합니다.
                SentencePracticeFeedback(
                  voiceAnalysis: results[i].voiceAnalysis,
                ),
              ]),
            ),
            const SizedBox(height: 11),
          ],
          const SizedBox(height: 17),
          Text(recommendations.isEmpty
              ? '자음·모음 연습부터 시작해요'
              : '추천 발음부터 연습해요',
            style: const TextStyle(fontWeight: FontWeight.w800,
                color: AppStyle.ink, fontSize: 19)),
          const SizedBox(height: 12),
          if (recommendations.isNotEmpty) ...[
            const Text('음성 인식 결과에서 차이가 발견된 자모를 바탕으로 '
                '다시 확인할 발음을 추천해요.',
              style: TextStyle(color: AppStyle.muted, fontSize: 12,
                  height: 1.5)),
            const SizedBox(height: 12),
            for (var i = 0; i < recommendations.length; i++) ...[
              _RecommendedPracticeInfo(recommendation: recommendations[i]),
              if (i != recommendations.length - 1)
                const SizedBox(height: 10),
            ],
            const SizedBox(height: 16),
            const Text('인식 텍스트의 차이를 이용한 학습 추천이며, '
                '실제 발음 오류나 취약 음소로 확정한 것은 아니에요. '
                '카드를 누르면 해당 글자의 기존 학습 화면으로 이동해요.',
              style: TextStyle(fontSize: 12, color: AppStyle.muted,
                  height: 1.5)),
          ] else ...[
            _BasicPracticeInfo(letter: 'ㅏ', label: '모음 학습',
              description: '혀의 위치와 입 모양을 그림으로 확인해요.',
              onTap: () => _openRecommendedPhoneme(context, 'ㅏ')),
            const SizedBox(height: 10),
            _BasicPracticeInfo(letter: 'ㅂ', label: '자음 학습',
              description: '조음 위치부터 연습해 보세요.',
              onTap: () => _openRecommendedPhoneme(context, 'ㅂ')),
            const SizedBox(height: 16),
            const Text('인식 결과에서 추천할 자모를 찾지 못해 '
                '기본 학습을 안내해요. 취약 발음을 판단한 결과는 아니에요.',
              style: TextStyle(fontSize: 12, color: AppStyle.muted)),
          ],
          const SizedBox(height: 27),
          FilledButton(onPressed: onFinished, child: const Text('발음 학습 시작')),
        ],
      )),
    );
  }
}

class _BasicPracticeInfo extends StatelessWidget {
  final String letter;
  final String label;
  final String description;
  final VoidCallback? onTap;
  const _BasicPracticeInfo({required this.letter, required this.label,
    required this.description, this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    decoration: AppStyle.card(),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(children: [
            Container(
              width: 53, height: 53, alignment: Alignment.center,
              decoration: BoxDecoration(color: AppStyle.paleCoral,
                borderRadius: BorderRadius.circular(13)),
              child: Text(letter, style: const TextStyle(
                color: AppStyle.ink, fontSize: 24,
                fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(
                    fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(description, style: const TextStyle(
                    color: AppStyle.muted, fontSize: 12)),
              ],
            )),
            if (onTap != null) const Icon(Icons.chevron_right_rounded,
                color: AppStyle.muted),
          ]),
        ),
      ),
    ),
  );
}
