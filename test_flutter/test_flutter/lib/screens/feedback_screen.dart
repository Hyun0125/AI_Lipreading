import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';

import '../ui/app_style.dart';
import '../ui/app_snackbar.dart';
import '../widgets/practice_visuals.dart';
import '../widgets/face_guide_painter.dart';

import '../config/app_config.dart';
import '../models/feedback_result.dart';
import '../services/feedback_api.dart';
import '../services/review_queue.dart';
import '../services/demo_scenarios.dart';
import '../services/learning_progress.dart';
import '../services/recorded_video_player.dart';

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
  CameraDescription? _cachedFrontCamera;
  Future<void>? _cameraReleaseFuture;

  VideoPlayerController? _videoController;

  XFile? _recordedVideo;

  bool _isRecording = false;
  bool _hasRecordedVideo = false;
  bool _isSaving = false;
  bool _isClosing = false;
  bool _cameraBusy = false;
  bool _isRestartingCamera = false;
  String? _cameraError;
  String? _videoPreviewError;

  @override
  void initState() {
    super.initState();
    _initializeCameraFuture = initializeFrontCamera();
  }

  String getPracticeText() {
    final Map<String, String> consonantPracticeMap = {
      'ㄱ': '그',
      'ㄲ': '끄',
      'ㅋ': '크',
      'ㅇ': '으',
      'ㅂ': '브',
      'ㅃ': '쁘',
      'ㅍ': '프',
      'ㅁ': '므',
      'ㄷ': '드',
      'ㄸ': '뜨',
      'ㅌ': '트',
      'ㅅ': '스',
      'ㅆ': '쓰',
      'ㄴ': '느',
      'ㄹ': '르',
      'ㅈ': '즈',
      'ㅉ': '쯔',
      'ㅊ': '츠',
      'ㅎ': '흐',
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
    ScaffoldMessenger.of(context).showSnackBar(AppSnackBar.error(message));
  }

  Future<void> initializeFrontCamera() async {
    CameraController? controller;
    try {
      // Camera enumeration is needed only on the first opening.
      var frontCamera = _cachedFrontCamera;
      if (frontCamera == null) {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          throw StateError('사용 가능한 카메라가 없습니다.');
        }
        frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        _cachedFrontCamera = frontCamera;
      }
      controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      // The preview must use the NEW initialized controller after a retake.
      setState(() {
        _cameraController = controller;
        _cameraError = null;
      });
    } catch (error) {
      // Avoid leaking the camera stream if initialization fails midway.
      try {
        await controller?.dispose();
      } catch (disposeError) {
        debugPrint('카메라 초기화 실패 후 정리 오류: $disposeError');
      }
      if (mounted) {
        setState(() {
          _cameraController = null;
          _cameraError =
              '카메라·마이크를 사용할 수 없습니다. 권한과 기기 연결을 확인해 주세요.';
        });
      }
      debugPrint('카메라 초기화 실패: $error');
    }
  }

  // Free the camera when the recorded-video UI takes over. This moves most
  // camera teardown time off the user's '다시 촬영하기' button press.
  Future<void> _releaseCameraAfterRecording(CameraController oldCamera) async {
    try {
      // Let the old CameraPreview leave the widget tree before disposing its
      // browser/native texture. Avoids the black preview seen on Chrome.
      await WidgetsBinding.instance.endOfFrame;
      await oldCamera.dispose();
    } catch (error) {
      debugPrint('녹화 후 카메라 미리 정리 실패: $error');
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
      // Switch to the recorded video before releasing the camera stream.
      // CameraPreview is then removed on the next frame while we prepare the
      // playback UI. Retake no longer has to wait for this camera disposal.
      if (!mounted) return;
      final cameraToRelease = _cameraController;
      setState(() {
        _recordedVideo = video;
        _isRecording = false;
        _hasRecordedVideo = true;
        _cameraController = null;
        _videoPreviewError = null;
      });
      if (cameraToRelease != null) {
        _cameraReleaseFuture = _releaseCameraAfterRecording(cameraToRelease);
      }

      // Playback initialization can proceed while the old camera is released.
      // Even if preview is unsupported, uploading the video stays possible.
      try {
        await _initializeVideoPlayer(video.path);
      } catch (error) {
        debugPrint('영상 미리보기 준비 실패(업로드 가능): $error');
        if (mounted) {
          setState(() => _videoPreviewError =
            '이 기기에서는 영상 미리보기를 사용할 수 없어요. 업로드는 가능합니다.');
        }
      }
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
    if (_cameraBusy || _isSaving) return;

    final previousVideoPlayer = _videoController;
    final previousCamera = _cameraController;
    final pendingCameraRelease = _cameraReleaseFuture;

    final retakeWatch = Stopwatch()..start();

    // Keep the proven black-screen fix: discard the previous preview/stream,
    // then open a NEW controller. The old stream has usually been released
    // already while the user was reviewing the recorded video.
    setState(() {
      _cameraBusy = true;
      _isRestartingCamera = true;
      _videoController = null;
      _cameraController = null;
      _initializeCameraFuture = null;
      _cameraError = null;
      _videoPreviewError = null;
    });

    try {
      previousVideoPlayer?.removeListener(_videoPlayerListener);

      // Dispose recorded player and wait for any ongoing old-camera release
      // concurrently, rather than one after the other.
      Future<void> releasePlayer() async {
        if (previousVideoPlayer == null) return;
        try {
          await previousVideoPlayer.pause();
        } catch (error) {
          debugPrint('이전 영상 일시정지 실패(재촬영 계속): $error');
        }
        await previousVideoPlayer.dispose();
      }

      Future<void> finishReleasingCamera() async {
        if (pendingCameraRelease != null) await pendingCameraRelease;
        if (previousCamera != null) {
          // Fallback for a retake before the old camera was released.
          await WidgetsBinding.instance.endOfFrame;
          await previousCamera.dispose();
        }
      }

      await Future.wait<void>([releasePlayer(), finishReleasingCamera()]);
      if (!mounted) return;
      _cameraReleaseFuture = null;
      final cleanupMs = retakeWatch.elapsedMilliseconds;

      // Only initialization remains on the common retake path.
      final initializeFuture = initializeFrontCamera();
      _initializeCameraFuture = initializeFuture;
      await initializeFuture;
      if (!mounted) return;
      debugPrint('재촬영 준비시간: 전체 ${retakeWatch.elapsedMilliseconds}ms '
          '(이전 리소스 정리 ${cleanupMs}ms, '
          '카메라 초기화 ${retakeWatch.elapsedMilliseconds - cleanupMs}ms)');

      setState(() {
        _recordedVideo = null;
        _hasRecordedVideo = false;
        _isRecording = false;
        _videoPreviewError = null;
      });
    } catch (error) {
      debugPrint('재촬영 카메라 재설정 실패: $error');
      if (mounted) {
        setState(() {
          _recordedVideo = null;
          _hasRecordedVideo = false;
          _isRecording = false;
          _cameraError =
              '카메라 미리보기를 다시 시작하지 못했어요. 촬영 화면을 다시 열어 주세요.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestartingCamera = false;
          _cameraBusy = false;
        });
      }
    }
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
        AppSnackBar.error('업로드 중 오류가 발생했습니다: $e'),
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

  // 미리보기 영역을 실제 카메라/영상의 종횡비에 맞춰 잡는다.
  // 고정 높이 + BoxFit.contain 조합으로 생기던 검은 여백을 방지한다.
  double _mediaAspectRatio(BuildContext context) {
    if (_hasRecordedVideo) {
      final player = _videoController;
      if (player != null && player.value.isInitialized) {
        final ratio = player.value.aspectRatio;
        if (ratio.isFinite && ratio > 0) return ratio;
      }
    }

    final camera = _cameraController;
    if (camera != null && camera.value.isInitialized) {
      final size = camera.value.previewSize;
      if (size != null && size.width > 0 && size.height > 0) {
        var ratio = size.width / size.height;
        // 모바일 네이티브 카메라는 센서 크기를 가로 방향으로 보고할 수 있다.
        // 세로 화면에서만 표시 비율을 뒤집고, Chrome 웹은 원본 비율을 쓴다.
        if (!kIsWeb &&
            MediaQuery.orientationOf(context) == Orientation.portrait &&
            ratio > 1) {
          ratio = 1 / ratio;
        }
        return ratio;
      }
    }

    // 초기화 대기 중에만 사용하는 임시 비율 (Chrome 기본 가로 영상).
    return 3 / 2;
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
          final camera = _cameraController;
          if (camera == null || !camera.value.isInitialized) {
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

          // CameraPreview의 비율을 그대로 사용한다.
          // previewSize.width/height를 뒤집거나 검은 배경에 끼워 넣지 않는다.
          return CameraPreview(camera);
        }

        return const Center(child: CircularProgressIndicator());
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
    final player = _videoController;
    if (player == null || !player.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final bool isFinished = player.value.position >= player.value.duration;
    final bool isPlaying = player.value.isPlaying;

    return GestureDetector(
      onTap: () async {
        if (isFinished) {
          await player.seekTo(Duration.zero);
          await player.play();
        } else if (isPlaying) {
          await player.pause();
        } else {
          await player.play();
        }
        if (!mounted) return;
        setState(() {});
      },
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // 바깥 AspectRatio가 녹화 영상의 크기와 일치하므로
          // 영상이 잘리거나 검은 테두리가 생기지 않는다.
          VideoPlayer(player),
          if (!isPlaying || isFinished)
            Center(child: Container(
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
            )),
        ],
      ),
    );
  }

  // 얼굴 가이드와 카메라가 동일한 영상 프레임 안에 그려지도록 배치한다.
  Widget previewBox(BuildContext context) {
    return AspectRatio(
      aspectRatio: _mediaAspectRatio(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _isRestartingCamera
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                fit: StackFit.expand,
                children: [
                  _hasRecordedVideo
                      ? recordedVideoPreviewArea()
                      : cameraPreviewArea(),
                  if (!_hasRecordedVideo)
                    const IgnorePointer(
                      child: CustomPaint(
                        painter: FaceGuidePainter(),
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
      onTap: _cameraBusy || _isRestartingCamera ||
              _cameraError != null ||
              _cameraController?.value.isInitialized != true
          ? null : () {
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
            child: previewBox(context),
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
  bool _reviewBusy = false;
  bool _reviewStatusLoaded = false;

  static const Color _reviewQueuedBackground = Color(0xFFFFEFED);
  static const Color _reviewQueuedBorder = Color(0xFFF5CEC9);

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
            ScaffoldMessenger.of(context).showSnackBar(
              AppSnackBar.error('연습 결과는 표시되지만 학습 기록을 저장하지 못했어요.'),
            );
          }
        }
      });
    }
  }

  Future<void> _loadReviewStatus() async {
    if (_reviewBusy) return;
    setState(() => _reviewBusy = true);
    try {
      final values = await ReviewQueue.read();
      if (mounted) {
        setState(() {
          _inReviewQueue = values.contains(result.targetItem);
          _reviewStatusLoaded = true;
        });
      }
    } catch (error) {
      debugPrint('복습 목록 상태 조회 실패: $error');
      if (mounted) {
        setState(() => _reviewStatusLoaded = false);
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBar.error('복습 목록 상태를 확인하지 못했어요. 다시 시도해 주세요.'),
        );
      }
    } finally {
      if (mounted) setState(() => _reviewBusy = false);
    }
  }

  Future<void> _toggleReview() async {
    if (_reviewBusy || !_reviewStatusLoaded) return;
    final newValue = !_inReviewQueue;
    setState(() => _reviewBusy = true);
    try {
      await ReviewQueue.setIncluded(result.targetItem, newValue);
      if (!mounted) return;
      setState(() => _inReviewQueue = newValue);
      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar.info(
        newValue ? '복습 목록에 추가했어요.' : '복습 목록에서 삭제했어요.',
        icon: newValue
            ? Icons.bookmark_added_outlined
            : Icons.bookmark_remove_outlined,
      ));
    } catch (error) {
      debugPrint('복습 목록 변경 실패: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppSnackBar.error('복습 목록을 업데이트하지 못했어요. 다시 시도해 주세요.'),
        );
      }
    } finally {
      if (mounted) setState(() => _reviewBusy = false);
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

      ScaffoldMessenger.of(context).showSnackBar(AppSnackBar.info(
        DemoScenarios.isActive
            ? '시연 모드의 임시 기록에 저장했어요. 실제 서버 기록에는 저장하지 않았습니다.'
            : '피드백 결과가 저장되었습니다.',
        icon: Icons.check_circle_outline_rounded,
      ));

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSavingResult = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar.error('저장 중 오류가 발생했습니다: $e'),
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

  Map<dynamic, dynamic>? get analysisMeta {
    final value = result.voiceAnalysis?.raw['analysis_meta'];
    return value is Map ? value : null;
  }

  Widget unavailableAnalysisContent() => ListView(children: [
    pillTitle('평가 안내'),
    const SizedBox(height: 16),
    feedbackList(),
    const SizedBox(height: 24),
    actionSaveButton(),
  ]);

  Widget summaryContent() {
    final meta = analysisMeta;
    if (meta != null && meta['module'] == 'jamo' && (meta['status'] != 'ok' || meta['visual_available'] == false)) {
      return unavailableAnalysisContent();
    }
    if (meta != null && meta['module'] == 'sentence') {
      final assessment = result.voiceAnalysis?.raw['pronunciation_assessment'];
      return ListView(children: [
        pillTitle('문장 분석 결과'),
        const SizedBox(height: 16),
        infoRow('목표 문장', result.targetPronunciation),
        infoRow('음성 인식 결과', result.whisperResult),
        infoRow('인식 문장 일치', result.isCorrect ? '일치' : '불일치'),
        if (assessment is Map && assessment['score'] != null)
          infoRow('ETRI 발음 점수 (원본 척도)', '${assessment['score']}'),
        const SizedBox(height: 16),
        feedbackList(),
        const SizedBox(height: 24),
        actionSaveButton(),
      ]);
    }
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
    if (analysisMeta?['module'] == 'jamo' && analysisMeta?['status'] != 'ok') {
      return unavailableAnalysisContent();
    }
    final voice = result.voiceAnalysis;
    if (analysisMeta?['module'] == 'sentence' && voice != null) {
      String metric(double? value, String unit) => value == null
          ? '분석값 없음' : '${value.toStringAsFixed(2)} $unit';
      return ListView(children: [
        pillTitle('AI 음성 분석 정보'),
        const SizedBox(height: 16),
        infoRow('전체 녹음 길이', metric(voice.totalDuration, '초')),
        infoRow('실제 발화 시간', metric(voice.speechDuration, '초')),
        infoRow('무음 시간', metric(voice.silenceDuration, '초')),
        infoRow('말하기 속도', metric(voice.speechRate, '음절/초')),
        infoRow('평균 음량', metric(voice.meanVolume, 'dB')),
        infoRow('평균 음높이', metric(voice.meanPitch, 'Hz')),
        infoRow('쉼 횟수', metric(voice.pauseCount, '회')),
        infoRow('유성음 비율', metric(voice.voicedRatio, '%')),
        const SizedBox(height: 16),
        feedbackList(),
        const SizedBox(height: 24),
        actionSaveButton(),
      ]);
    }

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

        if (voice != null && voice.audioFeatures.isNotEmpty) ...[
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
    if (analysisMeta?['visual_available'] == false) {
      return unavailableAnalysisContent();
    }
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _reviewBusy
                ? null
                : (_reviewStatusLoaded ? _toggleReview : _loadReviewStatus),
            icon: _reviewBusy
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
            label: Text(_reviewBusy
                ? '처리 중...'
                : !_reviewStatusLoaded
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
        ),
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