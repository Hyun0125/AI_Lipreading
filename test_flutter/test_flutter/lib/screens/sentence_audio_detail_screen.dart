import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/sentence_analysis_result.dart';
import '../ui/app_style.dart';

/// 문장별 Librosa 음성 특성 상세 화면.
/// 이 화면은 백엔드가 이미 계산한 voice_analysis.audio_features와 graphs를
/// 표시하며, 여기서 다시 음성 분석을 실행하거나 발음 점수를 만들지 않습니다.
class SentenceAudioDetailScreen extends StatelessWidget {
  final int sentenceNumber;
  final SentenceAnalysisResult result;

  const SentenceAudioDetailScreen({
    super.key,
    required this.sentenceNumber,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final voiceAnalysis = result.voiceAnalysis;
    final features = _asMap(voiceAnalysis['audio_features']);
    final duration = _asMap(features['duration']);
    final speechRate = _asMap(features['speech_rate']);
    final volume = _asMap(features['volume']);
    final pitch = _asMap(features['pitch']);
    final pause = _asMap(features['pause']);
    final voice = _asMap(features['voice']);
    final graphs = _asMap(voiceAnalysis['graphs']);
    final volumeGraph = _asMap(graphs['volume']);
    final pitchGraph = _asMap(graphs['pitch']);
    final spectrumGraph = _asMap(graphs['spectrum']);

    final volumeValues = _toDoubleList(volumeGraph['rms_dbfs']);
    final volumeTimes = _toDoubleList(volumeGraph['time_sec']);
    final pitchValues = _toDoubleList(pitchGraph['frequency_hz']);
    final pitchTimes = _toDoubleList(pitchGraph['time_sec']);
    final spectrumValues = _toDoubleList(spectrumGraph['relative_power_db']);
    final spectrumFrequencies = _toDoubleList(spectrumGraph['frequency_hz']);

    final hasFeatures = features.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text('${sentenceNumber}번째 문장 상세보기')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Text('문장별 음성 분석', style: AppStyle.heading(size: 25)),
            const SizedBox(height: 7),
            const Text(
              'Librosa로 녹음 음성의 시간·음량·음높이·쉼 특성을 분석한 결과예요.',
              style: TextStyle(color: AppStyle.muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 18),
            _InfoCard(
              title: '분석한 문장',
              children: [
                _LabeledText(label: '기준 문장', value: result.referenceText),
                const SizedBox(height: 8),
                _LabeledText(
                  label: 'Whisper 인식 문장',
                  value: result.recognizedText.trim().isEmpty
                      ? '음성을 인식하지 못했어요.'
                      : result.recognizedText,
                ),
              ],
            ),
            if (!hasFeatures) ...[
              const SizedBox(height: 14),
              _InfoCard(
                title: '음성 특성 데이터 없음',
                children: const [
                  Text(
                    '이 문장의 Librosa 분석 데이터가 응답에 포함되지 않았어요. '
                    '백엔드의 voice_analysis.audio_features 반환 여부를 확인해 주세요.',
                    style: TextStyle(color: AppStyle.muted, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 14),
              _MetricSection(
                title: '발화 시간',
                subtitle: '녹음의 에너지 크기를 기준으로 발화와 무음 구간을 추정했어요. 실제 음소 경계를 직접 판정한 값은 아니에요.',
                beforeMetrics: _DurationRatioBar(
                  speechRatio: _number(duration['speech_ratio_percent']) ?? 0,
                  silenceRatio: _number(duration['silence_ratio_percent']) ?? 0,
                ),
                metrics: [
                  _Metric('전체 녹음', _fmt(duration['total_sec']), '초'),
                  _Metric('실제 발화', _fmt(duration['speech_sec']), '초'),
                  _Metric('무음', _fmt(duration['silence_sec']), '초'),
                ],
              ),
              const SizedBox(height: 12),
              _MetricSection(
                title: '말하기 속도',
                subtitle: '음절 수와 말하기 속도는 Whisper 인식 문장에서 계산한 값이므로 인식 결과에 따라 달라질 수 있어요.',
                metrics: [
                  _Metric('음절 수', _fmt(speechRate['syllable_count'], digits: 0), '개'),
                  _Metric('단어 수', _fmt(speechRate['word_count'], digits: 0), '개'),
                  _Metric('초당 음절 수', _fmt(speechRate['syllables_per_second']), '음절/초'),
                  _Metric('분당 단어 수', _fmt(speechRate['words_per_minute']), '단어/분'),
                ],
              ),
              const SizedBox(height: 12),
              _MetricSection(
                title: '음량 특성',
                subtitle: 'dBFS는 녹음 파일의 디지털 음량 기준이며 실제 환경 소음계의 dB와 달라요.',
                metrics: [
                  _Metric('평균 음량', _fmt(volume['mean_db']), 'dBFS'),
                  _Metric('최소 음량', _fmt(volume['min_db']), 'dBFS'),
                  _Metric('최대 음량', _fmt(volume['max_db']), 'dBFS'),
                  _Metric('음량 범위', _fmt(volume['range_db']), 'dB'),
                  _Metric('음량 변화', _fmt(volume['std_db']), '표준편차'),
                ],
              ),
              const SizedBox(height: 12),
              _MetricSection(
                title: '음높이(F0)',
                subtitle: '유성음에서 추정한 기본 주파수예요. 높낮이 변화 특성을 보여주며 발음 정확도 점수는 아니에요.',
                metrics: [
                  _Metric('평균 음높이', _fmt(pitch['mean_hz']), 'Hz'),
                  _Metric('중앙 음높이', _fmt(pitch['median_hz']), 'Hz'),
                  _Metric('최저 음높이', _fmt(pitch['min_hz']), 'Hz'),
                  _Metric('최고 음높이', _fmt(pitch['max_hz']), 'Hz'),
                  _Metric('음높이 범위', _fmt(pitch['range_hz']), 'Hz'),
                  _Metric('반음 변화 폭', _fmt(pitch['range_semitones']), '반음'),
                  _Metric('음높이 변동률', _fmt(pitch['variation_percent']), '%'),
                ],
              ),
              const SizedBox(height: 12),
              _MetricSection(
                title: '쉼(휴지 구간)',
                metrics: [
                  _Metric('쉼 횟수', _fmt(pause['count'], digits: 0), '회'),
                  _Metric('전체 쉼 시간', _fmt(pause['total_sec']), '초'),
                  _Metric('평균 쉼 시간', _fmt(pause['average_sec']), '초'),
                  _Metric('가장 긴 쉼', _fmt(pause['max_sec']), '초'),
                ],
              ),
              const SizedBox(height: 12),
              _MetricSection(
                title: '유성음 비율',
                metrics: [
                  _Metric('유성음 비율', _fmt(voice['voiced_ratio_percent']), '%'),
                ],
              ),
              if (volumeValues.whereType<double>().length > 1) ...[
                const SizedBox(height: 12),
                _SignalChart(
                  title: '음량 변화 그래프',
                  description: '짧은 구간별 RMS 음량을 시간에 따라 표시해요. 마이크 거리와 입력 설정에 영향을 받으며, 실제 환경 소음계의 dB와는 달라요.',
                  values: volumeValues,
                  xStart: volumeTimes.isNotEmpty && volumeTimes.first != null
                      ? '${volumeTimes.first!.toStringAsFixed(1)}초' : '시작',
                  xEnd: volumeTimes.isNotEmpty && volumeTimes.last != null
                      ? '${volumeTimes.last!.toStringAsFixed(1)}초' : '끝',
                  xAxisTitle: '시간 (초)',
                  yAxisTitle: 'RMS 음량 (dBFS)',
                  yUnit: 'dBFS',
                  color: AppStyle.coral,
                ),
              ] else ...[
                const SizedBox(height: 12),
                _InfoCard(
                  title: '음량 변화 그래프',
                  children: const [
                    Text('이전 분석 결과에는 시간별 음량 그래프 데이터가 없어요. '
                        '백엔드 그래프 데이터를 추가한 뒤 새로 분석하면 확인할 수 있어요.',
                      style: TextStyle(color: AppStyle.muted,
                          fontSize: 12, height: 1.5)),
                  ],
                ),
              ],
              if (pitchValues.whereType<double>().length > 1) ...[
                const SizedBox(height: 12),
                _SignalChart(
                  title: '음높이 변화 그래프',
                  description: '유성음으로 감지된 구간의 기본 주파수(F0)를 시간에 따라 표시해요. 값이 비어 있는 구간은 유성음으로 감지되지 않았을 수 있어요. 음높이는 발음 정확도 점수가 아니에요.',
                  values: pitchValues,
                  xStart: pitchTimes.isNotEmpty && pitchTimes.first != null
                      ? '${pitchTimes.first!.toStringAsFixed(1)}초' : '시작',
                  xEnd: pitchTimes.isNotEmpty && pitchTimes.last != null
                      ? '${pitchTimes.last!.toStringAsFixed(1)}초' : '끝',
                  xAxisTitle: '시간 (초)',
                  yAxisTitle: '기본 주파수 (Hz)',
                  yUnit: 'Hz',
                  color: AppStyle.coral,
                ),
              ],
              if (spectrumValues.whereType<double>().length > 1) ...[
                const SizedBox(height: 12),
                _SignalChart(
                  title: '주파수 스펙트럼',
                  description: '녹음 전체의 주파수별 상대 에너지 분포예요. 가장 큰 대역을 기준(0 dB)으로 비교하며, 절대 음량이나 발음 정확도를 뜻하지 않아요.',
                  values: spectrumValues,
                  xStart: spectrumFrequencies.isNotEmpty && spectrumFrequencies.first != null
                      ? '${spectrumFrequencies.first!.toStringAsFixed(0)}Hz'
                      : '낮은 주파수',
                  xEnd: spectrumFrequencies.isNotEmpty && spectrumFrequencies.last != null
                      ? '${spectrumFrequencies.last!.toStringAsFixed(0)}Hz'
                      : '높은 주파수',
                  xAxisTitle: '주파수 (Hz)',
                  yAxisTitle: '상대 에너지 (dB)',
                  yUnit: 'dB',
                  color: AppStyle.ink,
                ),
              ],
            ],
            const SizedBox(height: 14),
            _InfoCard(
              title: '분석값의 의미',
              children: const [
                _MeaningRow(
                  title: '발화·무음 비율',
                  description: '음량 임계값으로 나눈 추정 비율이에요. 작은 소리나 주변 소음에 따라 구간 분류가 달라질 수 있어요.',
                ),
                _MeaningRow(
                  title: '말하기 속도',
                  description: 'Whisper가 인식한 한글 음절·단어 수를 발화 시간으로 나눈 값이에요. 인식 문장이 달라지면 결과도 달라져요.',
                ),
                _MeaningRow(
                  title: '음량(dBFS)',
                  description: '디지털 녹음 신호의 RMS 크기예요. 마이크 거리와 녹음 입력 설정에 영향을 받으며 실제 소리의 dB 측정값은 아니에요.',
                ),
                _MeaningRow(
                  title: '음높이(F0)',
                  description: '유성음에서 추정한 기본 주파수예요. 목소리의 높낮이 특성을 나타내며 자음·모음의 정확도를 직접 평가하지 않아요.',
                ),
                _MeaningRow(
                  title: '쉼·유성음 비율',
                  description: '검출된 발화 구간 사이의 쉼과 pYIN이 유성음으로 판단한 프레임 비율이에요. 문장 전달의 리듬을 참고하는 값이에요.',
                ),
                _MeaningRow(
                  title: '주파수 스펙트럼',
                  description: '소리에 포함된 주파수별 상대 에너지 분포예요. 소리의 구성 특성을 보여주지만 특정 음소의 정답 여부를 판정하지는 않아요.',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoCard(
              title: '결과 해석 시 참고해 주세요',
              children: const [
                Text(
                  '이 화면은 Librosa가 계산한 음성 신호의 특성을 보여줘요. '
                  '음량·음높이·말하기 속도만으로 특정 자음이나 모음의 발음 오류를 확정하거나 '
                  '발음 정확도 점수를 산출하지는 않아요. ETRI 문장 점수와 음성 인식 결과는 별도의 평가 정보예요.',
                  style: TextStyle(color: AppStyle.muted, fontSize: 12, height: 1.55),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationRatioBar extends StatelessWidget {
  final double speechRatio;
  final double silenceRatio;

  const _DurationRatioBar({
    required this.speechRatio,
    required this.silenceRatio,
  });

  @override
  Widget build(BuildContext context) {
    final speech = speechRatio.clamp(0.0, 100.0).toDouble();
    final silence = silenceRatio.clamp(0.0, 100.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: speech / 100,
            minHeight: 12,
            backgroundColor: AppStyle.softBorder,
            color: AppStyle.coral,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _RatioLegend(
              color: AppStyle.coral,
              label: '실제 발화 ${speech.toStringAsFixed(2)}%',
            ),
            _RatioLegend(
              color: AppStyle.softBorder,
              label: '무음 ${silence.toStringAsFixed(2)}%',
            ),
          ],
        ),
      ],
    );
  }
}

class _RatioLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _RatioLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 9, height: 9, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: AppStyle.muted, fontSize: 11)),
    ],
  );
}

class _MeaningRow extends StatelessWidget {
  final String title;
  final String description;

  const _MeaningRow({required this.title, required this.description});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(
          color: AppStyle.ink, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(description, style: const TextStyle(
          color: AppStyle.muted, fontSize: 11, height: 1.45)),
      ],
    ),
  );
}

class _Metric {
  final String label;
  final String value;
  final String unit;
  const _Metric(this.label, this.value, this.unit);
}

class _MetricSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? beforeMetrics;
  final List<_Metric> metrics;

  const _MetricSection({
    required this.title,
    required this.metrics,
    this.subtitle,
    this.beforeMetrics,
  });

  @override
  Widget build(BuildContext context) {
    final itemWidth = (MediaQuery.of(context).size.width - 40 - 12 - 30) / 2;
    return _InfoCard(
      title: title,
      children: [
        if (subtitle != null) ...[
          Text(subtitle!, style: const TextStyle(
            color: AppStyle.muted, fontSize: 11, height: 1.45)),
          const SizedBox(height: 10),
        ],
        if (beforeMetrics != null) ...[
          beforeMetrics!,
          const SizedBox(height: 11),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: itemWidth,
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppStyle.softInk,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(metric.label, style: const TextStyle(
                        color: AppStyle.muted, fontSize: 11)),
                      const SizedBox(height: 5),
                      Text(
                        metric.value == '측정 불가'
                            ? metric.value
                            : '${metric.value} ${metric.unit}'.trim(),
                        style: const TextStyle(
                          color: AppStyle.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: AppStyle.card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(
          color: AppStyle.ink, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}

class _LabeledText extends StatelessWidget {
  final String label;
  final String value;
  const _LabeledText({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppStyle.muted, fontSize: 11)),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(color: AppStyle.ink, fontSize: 13, height: 1.45)),
    ],
  );
}

class _SignalChart extends StatelessWidget {
  final String title;
  final String description;
  final List<double?> values;
  final String xStart;
  final String xEnd;
  final String xAxisTitle;
  final String yAxisTitle;
  final String yUnit;
  final Color color;

  const _SignalChart({
    required this.title,
    required this.description,
    required this.values,
    required this.xStart,
    required this.xEnd,
    required this.xAxisTitle,
    required this.yAxisTitle,
    required this.yUnit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final valid = values.whereType<double>().where((v) => v.isFinite).toList();
    if (valid.length < 2) return const SizedBox.shrink();
    final minValue = valid.reduce((a, b) => a < b ? a : b);
    final maxValue = valid.reduce((a, b) => a > b ? a : b);
    return _InfoCard(
      title: title,
      children: [
        Text(description, style: const TextStyle(
          color: AppStyle.muted, fontSize: 11, height: 1.5)),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(yAxisTitle, style: const TextStyle(
              color: AppStyle.muted, fontSize: 10, fontWeight: FontWeight.w700)),
            Text('범위 ${minValue.toStringAsFixed(1)}~${maxValue.toStringAsFixed(1)} $yUnit',
              style: const TextStyle(color: AppStyle.muted, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 150,
          width: double.infinity,
          child: CustomPaint(
            painter: _SignalChartPainter(values: _downsample(values), color: color),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(xStart, style: const TextStyle(color: AppStyle.muted, fontSize: 10)),
            Text(xEnd, style: const TextStyle(color: AppStyle.muted, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 3),
        Center(
          child: Text(xAxisTitle, style: const TextStyle(
            color: AppStyle.muted, fontSize: 10, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _SignalChartPainter extends CustomPainter {
  final List<double?> values;
  final Color color;
  const _SignalChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 7.0;
    const right = 7.0;
    const top = 9.0;
    const bottom = 9.0;
    final double chartWidth = math.max(1.0, size.width - left - right).toDouble();
    final double chartHeight = math.max(1.0, size.height - top - bottom).toDouble();

    final gridPaint = Paint()
      ..color = AppStyle.softBorder
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), gridPaint);
    }

    final valid = values.whereType<double>().where((v) => v.isFinite).toList();
    if (valid.length < 2) return;
    var minValue = valid.reduce((a, b) => a < b ? a : b);
    var maxValue = valid.reduce((a, b) => a > b ? a : b);
    if ((maxValue - minValue).abs() < 1e-9) {
      minValue -= 1;
      maxValue += 1;
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    var drawing = false;
    final denominator = math.max(1, values.length - 1);

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null || !value.isFinite) {
        drawing = false;
        continue;
      }
      final x = left + chartWidth * i / denominator;
      final y = top + (maxValue - value) / (maxValue - minValue) * chartHeight;
      if (!drawing) {
        path.moveTo(x, y);
        drawing = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SignalChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

List<double?> _downsample(List<double?> input, {int maxPoints = 240}) {
  if (input.length <= maxPoints) return input;
  final result = <double?>[];
  final bucketSize = input.length / maxPoints;
  for (var bucket = 0; bucket < maxPoints; bucket++) {
    final start = (bucket * bucketSize).floor();
    final end = ((bucket + 1) * bucketSize).floor().clamp(start + 1, input.length).toInt();
    final values = input.sublist(start, end)
        .whereType<double>().where((value) => value.isFinite).toList();
    result.add(values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length);
  }
  return result;
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((key, val) => MapEntry(key.toString(), val));
}

List<double?> _toDoubleList(Object? value) {
  if (value is! List) return <double?>[];
  return value.map((item) {
    if (item == null) return null;
    if (item is num) {
      final number = item.toDouble();
      return number.isFinite ? number : null;
    }
    final parsed = double.tryParse(item.toString());
    return parsed != null && parsed.isFinite ? parsed : null;
  }).toList();
}

double? _number(Object? value) {
  if (value == null) return null;
  final parsed = value is num ? value.toDouble() : double.tryParse(value.toString());
  return parsed != null && parsed.isFinite ? parsed : null;
}

String _fmt(Object? value, {int digits = 2}) {
  if (value == null) return '측정 불가';
  final number = value is num ? value.toDouble() : double.tryParse(value.toString());
  if (number == null || !number.isFinite) return '측정 불가';
  return number.toStringAsFixed(digits);
}
