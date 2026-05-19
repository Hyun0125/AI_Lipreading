import 'dart:io';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;

import '../models/feedback_result.dart';

const String baseUrl = 'http://192.168.181.44:8000';

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
  File? _savedVideoFile;

  bool _isRecording = false;
  bool _hasRecordedVideo = false;
  bool _isSaving = false;

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
      _savedVideoFile = null;
    });
  }

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

  Future<void> retakeVideo() async {
    await _videoController?.pause();
    await _videoController?.dispose();

    setState(() {
      _videoController = null;
      _recordedVideo = null;
      _savedVideoFile = null;
      _isRecording = false;
      _hasRecordedVideo = false;
    });
  }

  Future<File> saveRecordedVideoToAppStorage() async {
    if (_recordedVideo == null) {
      throw Exception('저장할 영상이 없습니다.');
    }

    final appDir = await getApplicationDocumentsDirectory();

    final fileName =
        '${widget.category}_${widget.item}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final savedPath = '${appDir.path}/$fileName';

    final savedFile = await File(_recordedVideo!.path).copy(savedPath);

    return savedFile;
  }

  Future<void> uploadVideo() async {
    if (_recordedVideo == null || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _videoController?.pause();

      final uri = Uri.parse('$baseUrl/feedback/analyze');

      final request = http.MultipartRequest('POST', uri);

      request.fields['category'] = widget.category;
      request.fields['target_item'] = widget.item;

      request.files.add(
        await http.MultipartFile.fromPath(
          'video',
          _recordedVideo!.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('서버 오류: ${response.statusCode}, ${response.body}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      final result = FeedbackResult.fromJson(
        Map<String, dynamic>.from(data),
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
                color: Colors.black.withOpacity(0.45),
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

class FeedbackResultScreen extends StatefulWidget {
  final FeedbackResult result;

  const FeedbackResultScreen({
    super.key,
    required this.result,
  });

  @override
  State<FeedbackResultScreen> createState() => _FeedbackResultScreenState();
}

class _FeedbackResultScreenState extends State<FeedbackResultScreen> {
  String selectedTab = '음성 피드백';

  bool _isSavingResult = false;

  String get audioFeedback {
    if (widget.result.feedbacks.isNotEmpty) {
      return widget.result.feedbacks[0];
    }
    return '음성 피드백이 없습니다.';
  }

  String get visualFeedback {
    if (widget.result.feedbacks.length >= 2) {
      return widget.result.feedbacks[1];
    }
    return '영상 피드백이 없습니다.';
  }

  Future<void> saveFeedbackResult() async {
    if (_isSavingResult) return;

    setState(() {
      _isSavingResult = true;
    });

    try {
      final uri = Uri.parse('$baseUrl/feedback/save');

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': widget.result.userId,

          'category': widget.result.category,
          'target_item': widget.result.targetItem,
          'video_path': widget.result.videoPath,

          'target_pronunciation': widget.result.targetPronunciation,
          'whisper_result': widget.result.whisperResult,
          'is_correct': widget.result.isCorrect,

          'speech_start_time': widget.result.speechStartTime,
          'speech_end_time': widget.result.speechEndTime,
          'speech_duration': widget.result.speechDuration,
          'volume': widget.result.volume,
          'energy_change': widget.result.energyChange,
          'average_pitch': widget.result.averagePitch,
          'pitch_change': widget.result.pitchChange,

          'speed_score': widget.result.speedScore,
          'duration_score': widget.result.durationScore,
          'stability_score': widget.result.stabilityScore,
          'pitch_score': widget.result.pitchScore,
          'volume_score': widget.result.volumeScore,
          'audio_total_score': widget.result.audioTotalScore,

          'average_mouth_open_ratio': widget.result.averageMouthOpenRatio,
          'max_mouth_open_ratio': widget.result.maxMouthOpenRatio,
          'min_mouth_open_ratio': widget.result.minMouthOpenRatio,
          'lip_movement_change': widget.result.lipMovementChange,
          'average_mouth_open_score': widget.result.averageMouthOpenScore,
          'max_mouth_open_score': widget.result.maxMouthOpenScore,
          'lip_movement_score': widget.result.lipMovementScore,
          'visual_total_score': widget.result.visualTotalScore,

          'feedbacks': widget.result.feedbacks,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('서버 오류: ${response.statusCode}, ${response.body}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data['success'] != true) {
        throw Exception(data['message'] ?? '저장 실패');
      }

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

  Widget tabButton(String text) {
    final isSelected = selectedTab == text;

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
            width: 72,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

  Widget feedbackContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pillTitle('점수'),
        const SizedBox(height: 14),

        Center(
          child: Text(
            "음성 점수: ${widget.result.audioTotalScore.toStringAsFixed(1)}점\n"
                "영상 점수: ${widget.result.visualTotalScore.toStringAsFixed(1)}점",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 24),

        pillTitle('음성 피드백'),
        const SizedBox(height: 14),

        Text(
          audioFeedback,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const SizedBox(height: 24),

        pillTitle('영상 피드백'),
        const SizedBox(height: 14),

        Text(
          visualFeedback,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
          ),
        ),

        const Spacer(),

        Center(
          child: GestureDetector(
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
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget videoFeedbackContent() {
    return Center(
      child: Text(
        "영상 점수: ${widget.result.visualTotalScore.toStringAsFixed(1)}점\n\n"
            "$visualFeedback\n\n"
            "영상 경로:\n${widget.result.videoPath}",
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content =
    selectedTab == '음성 피드백' ? feedbackContent() : videoFeedbackContent();

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

                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      tabButton('음성 피드백'),
                      const SizedBox(width: 36),
                      tabButton('영상 피드백'),
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