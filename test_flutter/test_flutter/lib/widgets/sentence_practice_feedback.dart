import 'package:flutter/material.dart';

import '../ui/app_style.dart';

/// AssessmentReportScreen의 각 문장 카드 안에 추가하는 위젯.
/// 백엔드의 voice_analysis JSON만 사용하며 추가 API 요청은 하지 않습니다.
/// 텍스트 차이는 발음 오류 '진단'이 아니라 재확인 후보로만 표시합니다.
class SentencePracticeFeedback extends StatelessWidget {
  final Object? voiceAnalysis;

  const SentencePracticeFeedback({
    super.key,
    required this.voiceAnalysis,
  });

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';

  static String _sources(Map<String, dynamic> candidate) {
    final sources = candidate['evidence_sources'];
    if (sources is! List) return '인식 결과 비교';
    final s = sources.map((e) => e.toString()).toSet();
    if (s.contains('whisper') && s.contains('etri')) {
      return 'Whisper·ETRI 모두에서 차이';
    }
    if (s.contains('whisper')) return 'Whisper에서만 차이';
    if (s.contains('etri')) return 'ETRI에서만 차이';
    return '인식 결과 비교';
  }

  static String _syllables(Map<String, dynamic> candidate) {
    final raw = candidate['syllable_candidates'];
    if (raw is! List) return '';
    final unique = <String>{};
    for (final item in raw) {
      final diff = _map(item);
      final expected = _text(diff['expected']);
      final recognized = _text(diff['recognized']);
      final left = expected.isEmpty ? '(없음)' : expected;
      final right = recognized.isEmpty ? '(없음)' : recognized;
      if (left != right) unique.add('$left → $right');
    }
    if (unique.isEmpty) return '';
    return unique.take(5).join('  ·  ');
  }

  static String _jamo(Map<String, dynamic> candidate) {
    final raw = candidate['syllable_candidates'];
    if (raw is! List) return '';
    final changes = <String>{};
    const positions = {'initial': '초성', 'vowel': '중성', 'final': '종성'};
    for (final item in raw) {
      final diff = _map(item);
      final jamos = diff['jamo_changes'];
      if (jamos is! List) continue;
      for (final item in jamos) {
        final change = _map(item);
        final position = positions[_text(change['position'])] ?? '자모';
        final expected = _text(change['expected']);
        final recognized = _text(change['recognized']);
        changes.add('$position ${expected.isEmpty ? "없음" : expected} → '
            '${recognized.isEmpty ? "없음" : recognized}');
      }
    }
    return changes.take(4).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _map(voiceAnalysis);
    final practice = _map(analysis['sentence_repractice']);
    final correction = _map(analysis['correction_candidates']);
    final recommended = practice['recommended'] == true;
    final rawCandidates = correction['candidates'];
    final candidates = rawCandidates is List
        ? rawCandidates.map(_map).where((c) => c.isNotEmpty).toList()
        : <Map<String, dynamic>>[];
    if (!recommended && candidates.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recommended) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: AppStyle.card(color: AppStyle.paleCoral),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.replay_rounded, color: AppStyle.coral, size: 18),
                    SizedBox(width: 7),
                    Expanded(child: Text('문장 전체 다시 연습하기',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                          color: AppStyle.ink))),
                  ]),
                  const SizedBox(height: 7),
                  Text(_text(practice['message']),
                    style: const TextStyle(fontSize: 12, height: 1.5,
                        color: AppStyle.ink)),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (candidates.isNotEmpty) ...[
            const Text('다시 확인할 단어·음절',
              style: TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 14, color: AppStyle.ink)),
            const SizedBox(height: 7),
            for (final candidate in candidates) ...[
              _CandidateComparisonCard(
                expectedWord: _text(candidate['expected_word']),
                whisperWord: _text(candidate['recognized_by_whisper']),
                etriWord: _text(candidate['recognized_by_etri']),
                sourceLabel: _sources(candidate),
                syllableDiff: _syllables(candidate),
                jamoDiff: _jamo(candidate),
              ),
              const SizedBox(height: 7),
            ],
            const Text('음성 인식 결과에서 찾은 재확인 후보예요. '
                '실제 발음 오류로 확정한 것은 아니에요.',
              style: TextStyle(fontSize: 11, height: 1.5,
                  color: AppStyle.muted)),
          ],
        ],
      ),
    );
  }
}

class _CandidateComparisonCard extends StatelessWidget {
  final String expectedWord;
  final String whisperWord;
  final String etriWord;
  final String sourceLabel;
  final String syllableDiff;
  final String jamoDiff;

  const _CandidateComparisonCard({
    required this.expectedWord,
    required this.whisperWord,
    required this.etriWord,
    required this.sourceLabel,
    required this.syllableDiff,
    required this.jamoDiff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: AppStyle.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(expectedWord.isEmpty ? '재확인 단어' : expectedWord,
            style: const TextStyle(fontWeight: FontWeight.w800,
                fontSize: 16, color: AppStyle.ink)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppStyle.softInk,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TranscriptRow(label: '기준 단어', value: expectedWord),
                if (whisperWord.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _TranscriptRow(label: 'Whisper', value: whisperWord),
                ],
                if (etriWord.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _TranscriptRow(label: 'ETRI', value: etriWord),
                ],
              ],
            ),
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppStyle.paleCoral,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(sourceLabel, style: const TextStyle(
              color: AppStyle.coral, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          if (syllableDiff.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('음절 차이: $syllableDiff',
              style: const TextStyle(fontSize: 12, height: 1.45,
                  color: AppStyle.ink)),
          ],
          if (jamoDiff.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('자모 구성 차이: $jamoDiff',
              style: const TextStyle(fontSize: 11, height: 1.45,
                  color: AppStyle.muted)),
          ],
        ],
      ),
    );
  }
}

class _TranscriptRow extends StatelessWidget {
  final String label;
  final String value;

  const _TranscriptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 76,
        child: Text(label, style: const TextStyle(
          color: AppStyle.muted, fontSize: 11, height: 1.45)),
      ),
      Expanded(
        child: Text(value, style: const TextStyle(
          color: AppStyle.ink, fontSize: 12, height: 1.45,
          fontWeight: FontWeight.w600)),
      ),
    ],
  );
}
