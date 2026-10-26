import 'package:flutter/material.dart';

import '../ui/app_style.dart';
import '../widgets/practice_visuals.dart';

import '../models/feedback_result.dart';
import '../services/demo_scenarios.dart';

// 복습모드 피드백 상세 화면
// 저장된 피드백 결과를 다시 확인할 때 사용한다.
class ReviewResultDetailScreen extends StatefulWidget {
  final FeedbackResult result; // 저장된 피드백 결과 데이터

  const ReviewResultDetailScreen({
    super.key,
    required this.result,
  });

  @override
  State<ReviewResultDetailScreen> createState() =>
      _ReviewResultDetailScreenState();
}

class _ReviewResultDetailScreenState extends State<ReviewResultDetailScreen> {
  String selectedTab = '요약'; // 현재 선택된 탭

  FeedbackResult get result => widget.result; // widget.result를 간단히 사용하기 위한 getter

  // 닫기 버튼 위젯
  // 현재 화면을 종료하고 이전 화면으로 돌아가는 X 버튼


  // 상단 탭 버튼 위젯
  // 요약, 음성, 입모양 탭을 전환하는 데 사용한다.


  // 회색 배경의 작은 제목 위젯
  // 기본 정보, 발음 평가 요약, 음성 점수 같은 섹션 제목에 사용한다.
  Widget pillTitle(String text) => PracticeSectionTitle(text);

  // 점수 카드 위젯
  // 음성 점수, 입모양 점수, 종합 점수를 요약해서 보여준다.
  Widget scoreCard({
    required String title,
    required double score,
    required String label,
  }) => Expanded(child: PracticeMetric(
    title: title, score: score, label: label));

  // 한 줄 정보 표시 위젯
  // 왼쪽에는 항목 이름, 오른쪽에는 값을 표시한다.
  Widget infoRow(String title, String value) =>
      PracticeInfoRow(title: title, value: value);

  // 피드백 문장 목록 위젯
  // 저장된 피드백 문장들을 목록 형태로 표시한다.
  Widget feedbackList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: result.feedbacks.map((feedback) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '• $feedback',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }

  // 요약 탭 화면
  // 기본 정보, 음성/입모양/종합 점수, 피드백 목록을 보여준다.
  Widget summaryContent() {
    final double totalScore =
        (result.audioTotalScore + result.visualTotalScore) / 2;

    return ListView(
      children: [
        pillTitle('기본 정보'),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppStyle.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppStyle.softBorder),
          ),
          child: Column(
            children: [
              infoRow('목표 발음', result.targetPronunciation),
              infoRow('Whisper 인식 결과', result.whisperResult),
              infoRow('음성 인식 일치 여부', result.isCorrect ? '일치' : '불일치'),
              infoRow('저장 날짜', result.createdAt),
            ],
          ),
        ),

        const SizedBox(height: 26),

        pillTitle('발음 평가 요약'),
        const SizedBox(height: 16),

        Row(
          children: [
            scoreCard(
              title: '음성 점수',
              score: result.audioTotalScore,
              label: '분석',
            ),
            const SizedBox(width: 12),
            scoreCard(
              title: '입모양 점수',
              score: result.visualTotalScore,
              label: '분석',
            ),
            const SizedBox(width: 12),
            scoreCard(
              title: '종합 점수',
              score: totalScore,
              label: '평균',
            ),
          ],
        ),

        const SizedBox(height: 26),

        pillTitle('피드백'),
        const SizedBox(height: 16),

        feedbackList(),

        const SizedBox(height: 24),
      ],
    );
  }

  // 음성 탭 화면
  // Librosa 기반 음성 세부 분석값과 음성 점수를 보여준다.
  Widget audioContent() {
    final voice = result.voiceAnalysis;

    String displayNumber(double? value, int digits, String unit) {
      if (value == null) return '분석값 없음';
      return '${value.toStringAsFixed(digits)} $unit';
    }

    return ListView(
      children: [
        pillTitle('음성 세부 분석'),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppStyle.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppStyle.softBorder),
          ),
          child: Column(
            children: [
              infoRow('발화 시작 시간', result.speechStartTime.toStringAsFixed(3)),
              infoRow('발화 종료 시간', result.speechEndTime.toStringAsFixed(3)),
              infoRow('발화 길이', result.speechDuration.toStringAsFixed(3)),
              infoRow('음량', result.volume.toStringAsFixed(5)),
              infoRow('에너지 변화량', result.energyChange.toStringAsFixed(5)),
              infoRow('평균 높낮이', result.averagePitch.toStringAsFixed(2)),
              infoRow('높낮이 변화량', result.pitchChange.toStringAsFixed(1)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 저장된 새 AI 음성 분석 결과
        if (voice != null) ...[
          pillTitle('AI 음성 분석 정보'),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppStyle.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppStyle.softBorder,
              ),
            ),
            child: Column(
              children: [
                infoRow(
                  '전체 녹음 길이',
                  displayNumber(voice.totalDuration, 2, '초'),
                ),
                infoRow(
                  '실제 발화 시간',
                  displayNumber(voice.speechDuration, 2, '초'),
                ),
                infoRow(
                  '무음 시간',
                  displayNumber(voice.silenceDuration, 2, '초'),
                ),
                infoRow(
                  '말하기 속도',
                  displayNumber(voice.speechRate, 2, '음절/초'),
                ),
                infoRow(
                  '평균 음량',
                  displayNumber(voice.meanVolume, 2, 'dBFS'),
                ),
                infoRow(
                  '평균 음높이',
                  displayNumber(voice.meanPitch, 2, 'Hz'),
                ),
                infoRow(
                  '쉼 횟수',
                  displayNumber(voice.pauseCount, 0, '회'),
                ),
                infoRow(
                  '유성음 비율',
                  displayNumber(voice.voicedRatio, 2, '%'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],

        pillTitle('음성 점수'),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppStyle.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppStyle.softBorder),
          ),
          child: Column(
            children: [
              infoRow('속도 점수', result.speedScore.toStringAsFixed(2)),
              infoRow('길이 점수', result.durationScore.toStringAsFixed(2)),
              infoRow('안정성 점수', result.stabilityScore.toStringAsFixed(2)),
              infoRow('높낮이 점수', result.pitchScore.toStringAsFixed(2)),
              infoRow('음량 점수', result.volumeScore.toStringAsFixed(2)),
              const Divider(height: 24),
              infoRow('음성 평가 최종 점수',
                  result.audioTotalScore.toStringAsFixed(2)),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // 입모양 탭 화면
  // MediaPipe 기반 입모양 분석값과 입모양 점수를 보여준다.
  Widget visualContent() {
    return ListView(
      children: [
        pillTitle('입모양 세부 분석'),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppStyle.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppStyle.softBorder),
          ),
          child: Column(
            children: [
              infoRow(
                '평균 입 벌림 비율',
                result.averageMouthOpenRatio.toStringAsFixed(4),
              ),
              infoRow(
                '최대 입 벌림 비율',
                result.maxMouthOpenRatio.toStringAsFixed(4),
              ),
              infoRow(
                '최소 입 벌림 비율',
                result.minMouthOpenRatio.toStringAsFixed(4),
              ),
              infoRow(
                '입술 움직임 변화량',
                result.lipMovementChange.toStringAsFixed(4),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        pillTitle('입모양 점수'),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppStyle.paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppStyle.softBorder),
          ),
          child: Column(
            children: [
              infoRow(
                '평균 입 벌림 점수',
                result.averageMouthOpenScore.toStringAsFixed(2),
              ),
              infoRow(
                '최대 입 벌림 점수',
                result.maxMouthOpenScore.toStringAsFixed(2),
              ),
              infoRow(
                '입술 움직임 점수',
                result.lipMovementScore.toStringAsFixed(2),
              ),
              const Divider(height: 24),
              infoRow(
                '입모양 최종 점수',
                result.visualTotalScore.toStringAsFixed(2),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        pillTitle('영상 파일'),
        const SizedBox(height: 16),

        Text(
          result.id != null && result.id! < 0 ? '시연용 예시: 연결된 영상 없음' : result.videoPath,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: Colors.grey[700],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final content = selectedTab == '음성' ? audioContent()
        : selectedTab == '입모양' ? visualContent() : summaryContent();
    return Scaffold(
      backgroundColor: AppStyle.background,
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Column(children: [
          PracticeScreenHeader(
            title: '저장된 발음 결과',
            subtitle: '${result.category} ${result.targetItem} · 이전 피드백',
            onBack: () => Navigator.pop(context),
          ),
          if (result.id != null && result.id! < 0) ...[
            const SizedBox(height: 12),
            PracticeSurface(color: AppStyle.paleCoral,
              child: const Text(
                '시연용 가상 점수입니다. 실제 발음 분석 결과가 아닙니다.',
                style: TextStyle(fontSize: 12, color: AppStyle.ink))),
          ] else if (DemoScenarios.isActive) ...[
            const SizedBox(height: 12),
            const Text('시연 모드 · 직접 분석한 결과',
              style: TextStyle(fontSize: 12, color: AppStyle.muted)),
          ],
          const SizedBox(height: 16),
          PracticeTabs(
            selected: selectedTab,
            onSelected: (value) => setState(() => selectedTab = value),
          ),
          const SizedBox(height: 15),
          Expanded(child: content),
        ]),
      )),
    );
  }
}