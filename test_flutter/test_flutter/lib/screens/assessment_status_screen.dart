import 'package:flutter/material.dart';
import '../ui/app_style.dart';

/// Screens 04–05: honest integration states. No invented score, recommendation,
/// or percentage is shown while the sentence assessment endpoint is missing.
class AssessmentAnalysisScreen extends StatelessWidget {
  final VoidCallback onFinished;
  const AssessmentAnalysisScreen({super.key, required this.onFinished});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI 통합 발음 분석')),
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      child: Column(children: [
        const Spacer(),
        Container(
          width: 106, height: 106,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppStyle.paleCoral,
          ),
          child: const Icon(Icons.pending_actions_rounded,
            color: AppStyle.coral, size: 51),
        ),
        const SizedBox(height: 25),
        Text('문장 촬영이 완료되었어요', style: AppStyle.heading(size: 24)),
        const SizedBox(height: 13),
        const Text('초기 문장 AI 분석 서버가 아직 연결되지 않았습니다.\n'
            '실제 분석 진행률이나 점수는 표시하지 않아요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppStyle.muted, height: 1.65)),
        const SizedBox(height: 25),
        Container(
          width: double.infinity,
          decoration: AppStyle.card(),
          padding: const EdgeInsets.all(16),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: AppStyle.coral),
            SizedBox(width: 11),
            Expanded(child: Text('촬영 파일은 진단 화면 종료 시 삭제를 시도했어요. '
                '문장 분석 결과는 아직 생성되지 않았습니다.',
              style: TextStyle(fontSize: 12, height: 1.5))),
          ]),
        ),
        const Spacer(),
        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) =>
              AssessmentReportScreen(onFinished: onFinished)),
          ),
          child: const Text('진단 상태 확인'),
        )),
      ]),
    )),
  );
}

class AssessmentReportScreen extends StatelessWidget {
  final VoidCallback onFinished;
  const AssessmentReportScreen({super.key, required this.onFinished});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('나의 발음 리포트')),
    body: SafeArea(child: ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 25),
      children: [
        Text('나의 발음 리포트', style: AppStyle.heading(size: 29)),
        const SizedBox(height: 7),
        const Text('촬영 완료 · AI 분석 기능 연동 전',
          style: TextStyle(color: AppStyle.muted, fontSize: 13)),
        const SizedBox(height: 23),
        Container(
          decoration: AppStyle.card(color: AppStyle.paleCoral),
          padding: const EdgeInsets.all(18),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('현재는 개인별 발음 분석이 제공되지 않아요',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                color: AppStyle.ink)),
            SizedBox(height: 9),
            Text('초기 문장 진단 API가 연결되면 분석에 근거한 취약 발음과 '
                '맞춤 학습을 안내할 예정이에요.',
              style: TextStyle(color: AppStyle.muted, fontSize: 12, height: 1.55)),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('자음·모음 연습부터 시작해요', style: TextStyle(
          fontWeight: FontWeight.w800, color: AppStyle.ink, fontSize: 19)),
        const SizedBox(height: 12),
        const _BasicPracticeInfo(letter: 'ㅏ', label: '모음 학습',
          description: '혀의 위치와 입 모양을 그림으로 확인해요.'),
        const SizedBox(height: 10),
        const _BasicPracticeInfo(letter: 'ㅂ', label: '자음 학습',
          description: '조음 위치부터 연습해 보세요.'),
        const SizedBox(height: 16),
        const Text('위의 항목은 기본 학습 예시이며 AI 진단 결과가 아니에요.',
          style: TextStyle(fontSize: 12, color: AppStyle.muted)),
        const SizedBox(height: 27),
        FilledButton(
          onPressed: onFinished,
          child: const Text('발음 학습 시작'),
        ),
      ],
    )),
  );
}

class _BasicPracticeInfo extends StatelessWidget {
  final String letter;
  final String label;
  final String description;
  const _BasicPracticeInfo({required this.letter, required this.label,
    required this.description});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: AppStyle.card(),
    child: Row(children: [
      Container(
        width: 53, height: 53,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppStyle.paleCoral,
          borderRadius: BorderRadius.circular(13)),
        child: Text(letter, style: const TextStyle(
          color: AppStyle.ink, fontSize: 24, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(description, style: const TextStyle(
            color: AppStyle.muted, fontSize: 12)),
        ],
      )),
    ]),
  );
}
