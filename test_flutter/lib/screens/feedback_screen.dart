import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../config/app_config.dart';
import '../models/feedback_result.dart';
import '../services/feedback_api.dart';

// 닫기 버튼 위젯
// 현재 화면을 종료하고 이전 화면으로 돌아가는 X 버튼
Widget closeButton(BuildContext context) {
  return Positioned(
    top: 6,
    right: 10,
    child: GestureDetector(
      onTap: () {
        Navigator.pop(context);
      },
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Icon(
          Icons.close,
          size: 22,
          color: Colors.black,
        ),
      ),
    ),
  );
}


// 피드백 촬영 화면
// 사용자가 선택한 학습 항목을 발음하는 영상을 촬영하고 서버로 업로드하는 화면
class FeedbackScreen extends StatefulWidget {
  final String item; // 선택한 학습 주제
  final String category; // 선택한 학습 종류

  const FeedbackScreen({
    super.key,
    required this.item,
    required this.category,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  CameraController? _cameraController; // 카메라 미리보기와 녹화를 제어하는 컨트롤러
  Future<void>? _initializeCameraFuture; // 카메라 초기화 상태를 관리하는 Future

  VideoPlayerController? _videoController; // 촬영된 영상을 재생하기 위한 컨트롤러

  XFile? _recordedVideo; // 촬영 완료된 영상 파일

  bool _isRecording = false; // 현재 녹화 중인지 여부
  bool _hasRecordedVideo = false; // 촬영된 영상이 있는지 여부
  bool _isSaving = false; // 서버 업로드 중인지 여부

  @override
  void initState() {
    super.initState();
    _initializeCameraFuture = initializeFrontCamera();
  }

  // 사용자가 발음해야 하는 문장을 반환하는 함수
  // 자음은 단독 발음이 불가능하기 때문에 모음 'ㅏ'를 붙인 형태로 변환하여 안내한다.
  String getPracticeText() {
    final Map<String, String> consonantPracticeMap = {
      'ㄱ': '가',
      'ㄲ': '까',
      'ㅋ': '카',
      'ㅇ': '아',
      'ㅂ': '바',
      'ㅃ': '빠',
      'ㅍ': '파',
      'ㅁ': '마',
      'ㄷ': '다',
      'ㄸ': '따',
      'ㅌ': '타',
      'ㅅ': '사',
      'ㅆ': '싸',
      'ㄴ': '나',
      'ㄹ': '라',
      'ㅈ': '자',
      'ㅉ': '짜',
      'ㅊ': '차',
      'ㅎ': '하',
    };

    if (widget.category == '자음') {
      final practiceText = consonantPracticeMap[widget.item] ?? widget.item;
      return "'$practiceText'를 발음해 보세요.";
    }

    return "'${widget.item}'를 발음해 보세요.";
  }

  // 전면 카메라를 초기화하는 함수
  // 전면 카메라가 없으면 첫 번째 카메라를 대신 사용한다.
  Future<void> initializeFrontCamera() async {
    final cameras = await availableCameras();

    final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: true,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() {});
    }
  }

  // 영상 녹화를 시작하는 함수
  // 카메라가 준비되지 않았거나 이미 녹화 중이면 실행하지 않는다.
  Future<void> startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_cameraController!.value.isRecordingVideo) {
      return;
    }

    await _cameraController!.startVideoRecording();

    setState(() {
      _isRecording = true;
      _hasRecordedVideo = false;
      _recordedVideo = null;
    });
  }

  // 영상 녹화를 종료하는 함수
  // 녹화가 끝난 뒤 영상 파일 정보를 확인하고 재생 화면을 초기화한다.
  Future<void> stopRecording() async {
    if (_cameraController == null ||
        !_cameraController!.value.isRecordingVideo) {
      return;
    }

    final video = await _cameraController!.stopVideoRecording();

    debugPrint('녹화된 영상 경로: ${video.path}');

    final file = File(video.path);
    final exists = await file.exists();
    final size = await file.length();

    debugPrint('영상 파일 존재 여부: $exists');
    debugPrint('영상 파일 크기: $size bytes');

    await _initializeVideoPlayer(video.path);

    setState(() {
      _recordedVideo = video;
      _isRecording = false;
      _hasRecordedVideo = true;
    });
  }

  // 촬영된 영상을 미리보기로 재생하기 위한 VideoPlayer 초기화 함수
  // 반복 재생은 끄고, 처음에는 일시정지 상태로 둔다.
  Future<void> _initializeVideoPlayer(String videoPath) async {
    await _videoController?.dispose();

    _videoController = VideoPlayerController.file(File(videoPath));
    await _videoController!.initialize();
    await _videoController!.setLooping(false);
    await _videoController!.pause();

    if (mounted) {
      setState(() {});
    }
  }

  // 재촬영 함수
  // 기존 영상 미리보기를 제거하고 다시 카메라 촬영 상태로 돌아간다.
  Future<void> retakeVideo() async {
    await _videoController?.pause();
    await _videoController?.dispose();

    setState(() {
      _videoController = null;
      _recordedVideo = null;
      _isRecording = false;
      _hasRecordedVideo = false;
    });
  }

  // 촬영된 영상을 서버에 업로드하고 AI 분석 결과를 받는 함수
  // 분석이 끝나면 피드백 결과 화면으로 이동한다.
  Future<void> uploadVideo() async {
    if (_recordedVideo == null || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _videoController?.pause();

      final result = await FeedbackApi.analyzeVideo(
        category: widget.category,
        targetItem: widget.item,
        videoPath: _recordedVideo!.path,
      );

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FeedbackResultScreen(
            result: result,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('업로드 중 오류가 발생했습니다: $e'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // 화면 상단에 표시되는 발음 안내 문구 위젯
  Widget practiceGuideText() {
    return Text(
      getPracticeText(),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  // 카메라 미리보기 영역
  // 카메라 초기화 상태에 따라 미리보기, 오류 메시지, 로딩 화면을 표시한다.
  Widget cameraPreviewArea() {
    return FutureBuilder<void>(
      future: _initializeCameraFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (_cameraController == null ||
              !_cameraController!.value.isInitialized) {
            return const Center(
              child: Text(
                '카메라를 불러올 수 없습니다.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '카메라 오류가 발생했습니다.\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  // 촬영된 영상 미리보기 영역
  // 화면을 누르면 영상 재생과 일시정지를 전환한다.
  Widget recordedVideoPreviewArea() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: GestureDetector(
        onTap: () async {
          if (_videoController!.value.isPlaying) {
            await _videoController!.pause();
          } else {
            await _videoController!.play();
          }

          if (mounted) {
            setState(() {});
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            ),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
                size: 36,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 카메라 또는 촬영 영상이 표시되는 박스
  // 촬영 전에는 카메라 미리보기, 촬영 후에는 영상 미리보기를 보여준다.
  Widget previewBox() {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(6),
      ),
      child: _hasRecordedVideo ? recordedVideoPreviewArea() : cameraPreviewArea(),
    );
  }

  // 공통 버튼 위젯
  // 촬영하기, 촬영종료, 업로드하기, 재촬영하기 버튼에 사용한다.
  Widget actionButton({
    required String text,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: onTap == null ? Colors.grey : Colors.black,
          ),
        ),
      ),
    );
  }

  // 촬영 상태에 따라 하단 버튼을 바꾸는 함수
  // 촬영 전: 촬영하기
  // 촬영 중: 촬영종료
  // 촬영 후: 업로드하기, 재촬영하기
  Widget buttonArea() {
    if (_hasRecordedVideo) {
      return Column(
        children: [
          actionButton(
            text: _isSaving ? '업로드 중...' : '업로드하기',
            onTap: _isSaving ? null : uploadVideo,
          ),
          const SizedBox(height: 16),
          actionButton(
            text: '재촬영하기',
            onTap: _isSaving ? null : retakeVideo,
          ),
        ],
      );
    }

    return actionButton(
      text: _isRecording ? '촬영종료' : '촬영하기',
      onTap: () async {
        if (_isRecording) {
          await stopRecording();
        } else {
          await startRecording();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
              child: Column(
                children: [
                  const Text(
                    '학습모드 - 피드백받기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 40),

                  practiceGuideText(),

                  const SizedBox(height: 40),

                  previewBox(),

                  const SizedBox(height: 60),

                  buttonArea(),

                  const Spacer(),
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


// 피드백 결과 화면
// 서버에서 받은 음성 분석, 입모양 분석, 종합 피드백을 탭으로 나누어 보여주는 화면
class FeedbackResultScreen extends StatefulWidget {
  final FeedbackResult result; // 서버에서 분석한 피드백 결과 데이터

  const FeedbackResultScreen({
    super.key,
    required this.result,
  });

  @override
  State<FeedbackResultScreen> createState() => _FeedbackResultScreenState();
}

class _FeedbackResultScreenState extends State<FeedbackResultScreen> {
  String selectedTab = '요약'; // 현재 선택된 탭
  bool _isSavingResult = false; // 피드백 결과 저장 중인지 여부

  FeedbackResult get result => widget.result; // widget.result를 간단히 사용하기 위한 getter

  // 피드백 결과를 DB에 저장하는 함수
  // 저장 완료 후 이전 화면으로 돌아간다.
  Future<void> saveFeedbackResult() async {
    if (_isSavingResult) return;

    setState(() {
      _isSavingResult = true;
    });

    try {
      await FeedbackApi.saveFeedbackResult(
        result: result,
        userId: AppConfig.currentUserId,
      );

      if (!mounted) return;

      setState(() {
        _isSavingResult = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('피드백 결과가 저장되었습니다.'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSavingResult = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 중 오류가 발생했습니다: $e'),
        ),
      );
    }
  }

  // 상단 탭 버튼 위젯
  // 요약, 음성, 입모양 탭을 전환하는 데 사용한다.
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

  // 회색 배경의 작은 제목 위젯
  // 기본 정보, 발음 평가 요약, 음성 점수 같은 섹션 제목에 사용한다.
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

  // 한 줄 정보 표시 위젯
  // 왼쪽에는 항목 이름, 오른쪽에는 값을 표시한다.
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

  // 점수 카드 위젯
  // 음성 점수, 입모양 점수, 종합 점수를 요약해서 보여준다.
  Widget scoreCard({
    required String title,
    required double score,
    required String label,
  }) {
    return Expanded(
      child: Container(
        height: 148,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
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
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                score.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 68,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.green[300],
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 피드백 문장 목록 위젯
  // 서버에서 받은 피드백이 없으면 기본 문장을 표시한다.
  Widget feedbackList() {
    final feedbacks = result.feedbacks.isEmpty
        ? ['피드백이 없습니다.']
        : result.feedbacks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: feedbacks.map((feedback) {
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
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              infoRow('목표 발음', result.targetPronunciation),
              infoRow('Whisper 인식 결과', result.whisperResult),
              infoRow('음성 인식 일치 여부', result.isCorrect ? '일치' : '불일치'),
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
            const SizedBox(width: 8),
            scoreCard(
              title: '입모양 점수',
              score: result.visualTotalScore,
              label: '분석',
            ),
            const SizedBox(width: 8),
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

        const SizedBox(height: 30),

        Center(
          child: actionSaveButton(),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // 음성 탭 화면
  // Librosa 기반 음성 세부 분석값과 음성 점수를 보여준다.
  Widget audioContent() {
    return ListView(
      children: [
        pillTitle('음성 세부 분석'),
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

        pillTitle('음성 점수'),
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
              infoRow(
                '음성 평가 최종 점수',
                result.audioTotalScore.toStringAsFixed(2),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),

        Center(
          child: actionSaveButton(),
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
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(18),
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
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(18),
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

        const SizedBox(height: 30),

        Center(
          child: actionSaveButton(),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // 피드백 결과 저장 버튼
  // 저장 중에는 버튼 문구를 변경하고 비활성화한다.
  Widget actionSaveButton() {
    return GestureDetector(
      onTap: _isSavingResult ? null : saveFeedbackResult,
      child: Container(
        width: 160,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          _isSavingResult ? '저장 중...' : '저장하기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _isSavingResult ? Colors.grey : Colors.black,
          ),
        ),
      ),
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
                    '학습모드 - 피드백 결과',
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