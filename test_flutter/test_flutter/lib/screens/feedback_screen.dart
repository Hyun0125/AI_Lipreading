import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../ui/app_style.dart';
import '../widgets/practice_visuals.dart';

import '../config/app_config.dart';
import '../models/feedback_result.dart';
import '../services/feedback_api.dart';
import '../services/review_queue.dart';
import '../services/demo_scenarios.dart';
import '../services/learning_progress.dart';
import '../services/recorded_video_player.dart';

// 얼굴 가이드라인을 그리는 CustomPainter
class FaceGuidePainter extends CustomPainter {
  const FaceGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect fullRect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    );

    final Rect faceRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.65,
      height: size.height * 0.75,
    );

    // saveLayer를 사용해야 BlendMode.clear가 타원 안쪽만 투명하게 제거된다.
    canvas.saveLayer(fullRect, Paint());

    // 전체 미리보기 영역을 먼저 반투명 회색으로 덮는다.
    final Paint outsidePaint = Paint()
      ..color = Colors.grey.shade600.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    canvas.drawRect(fullRect, outsidePaint);

    // 얼굴 타원 영역만 투명하게 뚫는다.
    final Paint clearPaint = Paint()
      ..blendMode = BlendMode.clear;

    canvas.drawOval(faceRect, clearPaint);

    canvas.restore();

    // 얼굴 영역 테두리
    final Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawOval(faceRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
// 닫기 버튼 위젯
Widget closeButton({
  required BuildContext context,
  Future<void> Function()? onClose,
}) {
  return Positioned(
    top: 6,
    right: 10,
    child: GestureDetector(
      onTap: () async {
        if (onClose != null) {
          await onClose();
        } else {
          Navigator.pop(context);
        }
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
class FeedbackScreen extends StatefulWidget {
  final String item;
  final String category;

  const FeedbackScreen({
    super.key,
    required this.item,
    required this.category,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;

  VideoPlayerController? _videoController;

  XFile? _recordedVideo;

  bool _isRecording = false;
  bool _hasRecordedVideo = false;
  bool _isSaving = false;
  bool _isClosing = false;
  bool _cameraBusy = false;
  String? _cameraError;
  String? _videoPreviewError;

  @override
  void initState() {
    super.initState();
    _initializeCameraFuture = initializeFrontCamera();
  }

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

  void _showCaptureError(String message, Object error) {
    debugPrint('$message: $error');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  Future<void> initializeFrontCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('사용 가능한 카메라가 없습니다.');
      }
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      _cameraController = controller;
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraError = null);
    } catch (error) {
      if (mounted) {
        setState(() => _cameraError =
          '카메라·마이크를 사용할 수 없습니다. 권한과 기기 연결을 확인해 주세요.');
      }
      debugPrint('카메라 초기화 실패: $error');
    }
  }

  Future<void> startRecording() async {
    final controller = _cameraController;
    if (_cameraBusy || _isSaving || controller == null ||
        !controller.value.isInitialized || controller.value.isRecordingVideo) {
      return;
    }
    setState(() => _cameraBusy = true);
    try {
      await controller.startVideoRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _hasRecordedVideo = false;
        _recordedVideo = null;
        _videoPreviewError = null;
      });
    } catch (error) {
      _showCaptureError('촬영을 시작하지 못했어요. 카메라·마이크 권한을 확인해 주세요.', error);
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  Future<void> stopRecording() async {
    final controller = _cameraController;
    if (_cameraBusy || controller == null || !controller.value.isRecordingVideo) {
      return;
    }
    setState(() => _cameraBusy = true);
    try {
      final video = await controller.stopVideoRecording();
      // XFile은 Android와 Chrome에서 모두 길이를 읽을 수 있다.
      final size = await video.length();
      if (size == 0) throw StateError('녹화된 영상이 비어 있습니다.');
      debugPrint('녹화 완료: ${video.name} ($size bytes)');
      // 영상 재생 기능이 지원되지 않아도 서버 업로드는 가능해야 한다.
      try {
        await _initializeVideoPlayer(video.path);
      } catch (error) {
        debugPrint('영상 미리보기 준비 실패(업로드 가능): $error');
        if (mounted) {
          setState(() => _videoPreviewError =
            '이 기기에서는 영상 미리보기를 사용할 수 없어요. 업로드는 가능합니다.');
        }
      }
      if (!mounted) return;
      setState(() {
        _recordedVideo = video;
        _isRecording = false;
        _hasRecordedVideo = true;
      });
    } catch (error) {
      _showCaptureError('촬영을 종료하지 못했어요. 다시 시도해 주세요.', error);
      if (mounted) {
        setState(() {
          _isRecording = controller.value.isRecordingVideo;
          _hasRecordedVideo = false;
        });
      }
    } finally {
      if (mounted) setState(() => _cameraBusy = false);
    }
  }

  Future<void> _initializeVideoPlayer(String videoPath) async {
    _videoController?.removeListener(_videoPlayerListener);
    await _videoController?.dispose();
    _videoController = null;
    final player = createRecordedVideoController(videoPath);
    try {
      await player.initialize();
      await player.setLooping(false);
      await player.pause();
    } catch (_) {
      await player.dispose();
      rethrow;
    }
    if (!mounted) {
      await player.dispose();
      return;
    }
    _videoController = player;
    player.addListener(_videoPlayerListener);
    setState(() => _videoPreviewError = null);
  }

  void _videoPlayerListener() {
    if (mounted) setState(() {});
  }

  Future<void> retakeVideo() async {
    await _videoController?.pause();
    _videoController?.removeListener(_videoPlayerListener);
    await _videoController?.dispose();

    if (!mounted) return;

    setState(() {
      _videoController = null;
      _recordedVideo = null;
      _isRecording = false;
      _hasRecordedVideo = false;
      _videoPreviewError = null;
    });
  }

  Future<void> closeScreen() async {
    if (_isClosing) return;

    _isClosing = true;

    try {
      if (_cameraController != null &&
          _cameraController!.value.isRecordingVideo) {
        await _cameraController!.stopVideoRecording();
      }

      await _videoController?.pause();
    } catch (e) {
      debugPrint('화면 종료 처리 중 오류: $e');
    }

    if (!mounted) return;

    Navigator.pop(context);
  }

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
        video: _recordedVideo!,
      );

      // 분석 응답이 다른 학습 항목의 결과라면 완료 처리하지 않는다.
      if (result.targetItem != widget.item || result.category != widget.category) {
        throw const FormatException('분석 결과의 학습 항목이 요청한 발음과 다릅니다.');
      }
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      final bool? isSaved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => FeedbackResultScreen(
            result: result,
            recordPracticeOnDisplay: true,
          ),
        ),
      );

      if (!mounted) return;

      if (isSaved == true) {
        Navigator.pop(context, true);
      }
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
    _videoController?.removeListener(_videoPlayerListener);
    _videoController?.dispose();
    super.dispose();
  }

  Widget practiceGuideText() {
    return Text(
      getPracticeText(),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppStyle.ink,
      ),
    );
  }

  Widget cameraPreviewArea() {
    return FutureBuilder<void>(
      future: _initializeCameraFuture,
      builder: (context, snapshot) {
        if (_cameraError != null) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_cameraError!, textAlign: TextAlign.center),
          ));
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
            borderRadius: BorderRadius.circular(18),
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

        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  Widget recordedVideoPreviewArea() {
    if (_videoPreviewError != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(15),
        child: Text(_videoPreviewError!, textAlign: TextAlign.center),
      ));
    }
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final bool isFinished =
        _videoController!.value.position >= _videoController!.value.duration;
    final bool isPlaying = _videoController!.value.isPlaying;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: GestureDetector(
        onTap: () async {
          if (isFinished) {
            await _videoController!.seekTo(Duration.zero);
            await _videoController!.play();
          } else if (isPlaying) {
            await _videoController!.pause();
          } else {
            await _videoController!.play();
          }

          if (!mounted) return;

          setState(() {});
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

            if (!isPlaying || isFinished)
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFinished ? Icons.replay : Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 가이드라인 오버레이 뷰가 통합된 미리보기 박스
  Widget previewBox(double height) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 카메라 미리보기 또는 녹화된 영상이 전체 영역을 꽉 채우도록 배치
            Positioned.fill(
              child: _hasRecordedVideo
                  ? recordedVideoPreviewArea()
                  : cameraPreviewArea(),
            ),

            // 녹화 전/녹화 중에만 얼굴 가이드 표시
            if (!_hasRecordedVideo)
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: FaceGuidePainter(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  Widget actionButton({
    required String text,
    required VoidCallback? onTap,
    bool secondary = false,
    IconData? icon,
  }) {
    final child = icon == null ? Text(text)
      : Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 19),
          const SizedBox(width: 9),
          Text(text),
        ]);
    return SizedBox(
      width: double.infinity,
      child: secondary
        ? OutlinedButton(onPressed: onTap, child: child)
        : FilledButton(onPressed: onTap, child: child),
    );
  }

  Widget buttonArea() {
    if (_hasRecordedVideo) {
      return Column(children: [
        actionButton(
          text: _isSaving ? '분석 중...' : '분석 결과 확인하기',
          icon: Icons.analytics_outlined,
          onTap: _isSaving || _cameraBusy ? null : uploadVideo,
        ),
        const SizedBox(height: 11),
        actionButton(
          text: '다시 촬영하기',
          icon: Icons.refresh_rounded,
          secondary: true,
          onTap: _isSaving || _cameraBusy ? null : retakeVideo,
        ),
      ]);
    }
    return actionButton(
      text: _isRecording ? '촬영 종료' : '촬영 시작',
      icon: _isRecording ? Icons.stop_circle_outlined : Icons.videocam_outlined,
      onTap: _cameraBusy || _cameraError != null ? null : () {
        if (_isRecording) {
          stopRecording();
        } else {
          startRecording();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewHeight =
        (MediaQuery.of(context).size.height * 0.39).clamp(235.0, 350.0);
    final practiceLabel = widget.category == '자음'
        ? '자음 · ${widget.item}' : '모음 · ${widget.item}';
    return Scaffold(
      backgroundColor: AppStyle.background,
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          PracticeScreenHeader(
            title: '발음 연습하기',
            subtitle: '입모양과 목소리를 함께 촬영해요.',
            onBack: () { closeScreen(); },
          ),
          const SizedBox(height: 18),
          PracticeSurface(color: AppStyle.paleCoral,
            child: Column(children: [
              Text(practiceLabel, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: AppStyle.coral)),
              const SizedBox(height: 8),
              practiceGuideText(),
            ])),
          if (DemoScenarios.isActive) ...[
            const SizedBox(height: 12),
            PracticeSurface(color: AppStyle.cream,
              child: const Text(
                '시연 모드: 분석 시 영상은 실제 서버로 전송됩니다. '
                '결과 저장만 시연 세션에 적용됩니다.',
                style: TextStyle(fontSize: 12, color: AppStyle.ink))),
          ],
          const SizedBox(height: 17),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const PracticeSectionTitle('카메라 촬영'),
            Row(children: [
              Icon(_isRecording ? Icons.fiber_manual_record :
                    _hasRecordedVideo ? Icons.check_circle : Icons.face_outlined,
                color: _isRecording || _hasRecordedVideo
                    ? AppStyle.coral : AppStyle.muted, size: 16),
              const SizedBox(width: 5),
              Text(_isRecording ? '촬영 중' : _hasRecordedVideo
                  ? '촬영 완료' : '얼굴을 화면에 맞춰 주세요',
                style: const TextStyle(color: AppStyle.muted, fontSize: 11)),
            ]),
          ]),
          const SizedBox(height: 10),
          Container(
            decoration: AppStyle.card(radius: 20),
            clipBehavior: Clip.antiAlias,
            child: previewBox(previewHeight),
          ),
          const SizedBox(height: 11),
          Text(_hasRecordedVideo
              ? '촬영한 영상을 확인한 뒤 분석 결과를 확인해 주세요.'
              : _isRecording
                  ? '발음을 마쳤다면 촬영 종료를 눌러 주세요.'
                  : '얼굴을 화면 안에 맞추고 편하게 발음해 보세요.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppStyle.muted,
              fontSize: 12, height: 1.5)),
          const SizedBox(height: 21),
          buttonArea(),
        ],
      )),
    );
  }
}

// 피드백 결과 화면
class FeedbackResultScreen extends StatefulWidget {
  final FeedbackResult result;
  final bool recordPracticeOnDisplay;

  const FeedbackResultScreen({
    super.key,
    required this.result,
    this.recordPracticeOnDisplay = false,
  });

  @override
  State<FeedbackResultScreen> createState() => _FeedbackResultScreenState();
}

class _FeedbackResultScreenState extends State<FeedbackResultScreen> {
  String selectedTab = '요약';
  bool _isSavingResult = false;
  bool _inReviewQueue = false;

  @override
  void initState() {
    super.initState();
    _loadReviewStatus();
    // 결과 화면이 실제로 표시된 뒤 기록. 저장 버튼/복습 추가 버튼과 독립적.
    // 촬영 취소, 서버 통신 실패, 결과 파싱 실패 시 이 화면에 진입하지 않는다.
    if (widget.recordPracticeOnDisplay) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          await LearningProgress.recordSuccessfulPractice(
            phoneme: widget.result.targetItem,
            category: widget.result.category,
          );
        } catch (error) {
          debugPrint('발음 연습 완료 기록 저장 실패: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('연습 결과는 표시되지만 학습 기록을 저장하지 못했어요.'),
            ));
          }
        }
      });
    }
  }

  Future<void> _loadReviewStatus() async {
    final values = await ReviewQueue.read();
    if (mounted) setState(() => _inReviewQueue = values.contains(result.targetItem));
  }

  Future<void> _toggleReview() async {
    final newValue = !_inReviewQueue;
    await ReviewQueue.setIncluded(result.targetItem, newValue);
    if (mounted) {
      setState(() => _inReviewQueue = newValue);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newValue ? '복습 목록에 추가했어요.' : '복습 목록에서 삭제했어요.'),
      ));
    }
  }

  FeedbackResult get result => widget.result;

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
        SnackBar(
          content: Text(DemoScenarios.isActive
            ? '시연 모드의 임시 기록에 저장했어요. 실제 서버 기록에는 저장하지 않았습니다.'
            : '피드백 결과가 저장되었습니다.'),
        ),
      );

      Navigator.pop(context, true);
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

  Widget pillTitle(String text) => PracticeSectionTitle(text);

  Widget infoRow(String title, String value) =>
      PracticeInfoRow(title: title, value: value);

  Widget scoreCard({
    required String title,
    required double score,
    required String label,
  }) => Expanded(child: PracticeMetric(
    title: title, score: score, label: label));

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
        actionSaveButton(),
        const SizedBox(height: 24),
      ],
    );
  }

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
              infoRow(
                '음성 평가 최종 점수',
                result.audioTotalScore.toStringAsFixed(2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        actionSaveButton(),
        const SizedBox(height: 24),
      ],
    );
  }

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
        const SizedBox(height: 30),
        actionSaveButton(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget actionSaveButton() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: double.infinity, child: FilledButton.icon(
        onPressed: _isSavingResult ? null : saveFeedbackResult,
        icon: const Icon(Icons.save_outlined),
        label: Text(_isSavingResult ? '저장 중...' : '결과 저장하기'),
      )),
      const SizedBox(height: 11),
      if (result.category == '자음' || result.category == '모음')
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: _toggleReview,
          icon: Icon(_inReviewQueue ? Icons.bookmark_added_rounded
              : Icons.bookmark_add_outlined),
          label: Text(_inReviewQueue ? '복습 목록에 추가됨' : '복습에 추가'),
        )),
    ]);
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
            title: '발음 분석 결과',
            subtitle: '${result.category} ${result.targetItem} · 분석 결과 확인',
            onBack: () => Navigator.pop(context, false),
          ),
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