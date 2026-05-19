import 'package:flutter/material.dart';

import '../models/feedback_result.dart';

class ReviewResultDetailScreen extends StatefulWidget {
  final FeedbackResult result;

  const ReviewResultDetailScreen({
    super.key,
    required this.result,
  });

  @override
  State<ReviewResultDetailScreen> createState() =>
      _ReviewResultDetailScreenState();
}

class _ReviewResultDetailScreenState extends State<ReviewResultDetailScreen> {
  String selectedTab = '요약';

  FeedbackResult get result => widget.result;

  Widget closeButton(BuildContext context) {
    return Positioned(
      top: 6,
      right: 10,
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context);
        },
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: const Icon(
            Icons.close,
            size: 30,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget tabButton(String text) {
    final bool isSelected = selectedTab == text;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = text;
        });
      },
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 52,
            height: 2,
            color: isSelected ? Colors.black : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget pillTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget scoreCard({
    required String title,
    required double score,
    required String label,
  }) {
    return Expanded(
      child: Container(
        height: 148,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Colors.grey[200]!,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              score.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 72,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.green[300],
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

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
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(18),
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

  Widget audioContent() {
    return ListView(
      children: [
        pillTitle('Librosa 음성 분석'),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(18),
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

        pillTitle('Librosa 음성 평가 점수'),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(18),
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

  Widget visualContent() {
    return ListView(
      children: [
        pillTitle('입모양 분석 점수'),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              infoRow('평균 입 벌림 비율',
                  result.averageMouthOpenRatio.toStringAsFixed(4)),
              infoRow('최대 입 벌림 비율',
                  result.maxMouthOpenRatio.toStringAsFixed(4)),
              infoRow('최소 입 벌림 비율',
                  result.minMouthOpenRatio.toStringAsFixed(4)),
              infoRow('입술 움직임 변화량',
                  result.lipMovementChange.toStringAsFixed(4)),
              const Divider(height: 24),
              infoRow('평균 입 벌림 점수',
                  result.averageMouthOpenScore.toStringAsFixed(2)),
              infoRow('최대 입 벌림 점수',
                  result.maxMouthOpenScore.toStringAsFixed(2)),
              infoRow('입술 움직임 점수',
                  result.lipMovementScore.toStringAsFixed(2)),
              const Divider(height: 24),
              infoRow('입모양 최종 점수',
                  result.visualTotalScore.toStringAsFixed(2)),
            ],
          ),
        ),

        const SizedBox(height: 24),

        pillTitle('영상 파일'),
        const SizedBox(height: 16),

        Text(
          result.videoPath,
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
    Widget content;

    if (selectedTab == '음성') {
      content = audioContent();
    } else if (selectedTab == '입모양') {
      content = visualContent();
    } else {
      content = summaryContent();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                children: [
                  const Text(
                    '복습모드 - 피드백 다시 보기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      tabButton('요약'),
                      const SizedBox(width: 30),
                      tabButton('음성'),
                      const SizedBox(width: 30),
                      tabButton('입모양'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Expanded(
                    child: content,
                  ),
                ],
              ),
            ),

            closeButton(context),
          ],
        ),
      ),
    );
  }
}