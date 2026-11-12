import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../ui/app_style.dart';
import '../widgets/practice_visuals.dart';
import '../widgets/face_guide_painter.dart';
import '../services/temporary_video_file.dart';
import 'assessment_status_screen.dart';

/// Record five sentences, then run the sentence-only voice analysis API.
/// The legacy consonant/vowel feedback flow is independent.
class InitialAssessmentScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const InitialAssessmentScreen({super.key, required this.onFinished});

  @override
  State<InitialAssessmentScreen> createState() => _InitialAssessmentScreenState();
}

class _InitialAssessmentScreenState extends State<InitialAssessmentScreen> {
  static const _sentences = [
    '오늘은 날씨가 좋아요.',
    '바다에 작은 배가 떠 있어요.',
    '친구와 함께 학교에 가요.',
    '우리 동네에 꽃이 피었어요.',
    '아침마다 책을 읽어요.',
  ];

  CameraController? _camera;
  // Cache the selected camera; reuse its initialized controller between sentences.
  CameraDescription? _cachedFrontCamera;
  Future<void>? _cameraReleaseFuture;
  final List<XFile> _tempVideos = [];
  int _index = 0;
  bool _recording = false;
  bool _working = false;
  bool _finished = false;
  String? _error;
  Future<void>? _cleanupFuture;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    CameraController? nextCamera;
    try {
      // Chrome may keep the old camera texture/stream until disposal finishes.
      // Always wait for that disposal before opening the next recording.
      await _cameraReleaseFuture;
      if (!mounted || _cleanupFuture != null) return;

      var frontCamera = _cachedFrontCamera;
      if (frontCamera == null) {
        final cameras = await availableCameras();
        if (cameras.isEmpty) throw StateError('사용 가능한 카메라가 없습니다.');
        frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        _cachedFrontCamera = frontCamera;
      }

      nextCamera = CameraController(
        frontCamera, ResolutionPreset.medium, enableAudio: true,
      );
      await nextCamera.initialize();
      if (!mounted || _cleanupFuture != null) {
        await nextCamera.dispose();
        return;
      }
      setState(() {
        _camera = nextCamera;
        _error = null;
      });
    } catch (error) {
      try {
        await nextCamera?.dispose();
      } catch (_) {
        // Cleanup errors must not replace the camera initialization error.
      }
      debugPrint('문장 진단 카메라 초기화 실패: $error');
      if (mounted && _cleanupFuture == null) {
        setState(() {
          _camera = null;
          _error = '카메라를 다시 연결하지 못했어요. 카메라·마이크 권한을 확인해 주세요.';
        });
      }
    }
  }

  Future<void> _releaseCameraAfterRecording(CameraController camera) async {
    try {
      // The CameraPreview leaves the widget tree on the next frame.
      // Disposing its stream earlier can leave a black Chrome preview.
      await WidgetsBinding.instance.endOfFrame;
      await camera.dispose();
    } catch (error) {
      debugPrint('문장 진단 이전 카메라 해제 실패: $error');
    }
  }

  /// Keep the live camera preview open between sentences. Reinitializing a
  /// CameraController for every recording caused the long loading screen.
  /// Each completed sentence still produces its own independent XFile.
  Future<void> _toggleRecording() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _working || _finished) {
      return;
    }
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (!_recording) {
        await camera.startVideoRecording();
        if (mounted) setState(() => _recording = true);
      } else {
        final stopwatch = Stopwatch()..start();
        final file = await camera.stopVideoRecording();

        // Do not advance if the camera failed to finalize the recording.
        // The normal path needs only one size check; retry briefly for a
        // filesystem that is still flushing its completed video.
        var bytes = await file.length();
        for (var attempt = 0; bytes == 0 && attempt < 3; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          bytes = await file.length();
        }
        if (bytes == 0) {
          throw StateError('녹화 영상이 비어 있어 저장할 수 없습니다.');
        }
        if (!mounted) {
          await deleteTemporaryVideo(file);
          return;
        }

        _tempVideos.add(file);
        final currentSentence = _index + 1;
        final isLastSentence = _index == _sentences.length - 1;
        debugPrint('문장 $currentSentence 녹화 완료: $bytes bytes, '
            '종료 처리 ${stopwatch.elapsedMilliseconds}ms');

        if (isLastSentence) {
          // The camera is no longer needed once all five videos are ready.
          setState(() {
            _recording = false;
            _camera = null;
            _finished = true;
          });
          _cameraReleaseFuture = _releaseCameraAfterRecording(camera);
          await _cameraReleaseFuture;
        } else {
          // Crucial change: do NOT dispose/reinitialize the camera here.
          // Only switch the prompt; the existing CameraPreview stays mounted.
          setState(() {
            _recording = false;
            _index++;
          });
          // Chrome's MediaRecorder finishes its cleanup in an async callback.
          // Give it a short turn to release the old recorder before the next
          // Start button becomes enabled; camera stream itself remains open.
          if (kIsWeb) {
            await Future<void>.delayed(const Duration(milliseconds: 150));
          }
          debugPrint('문장 ${_index + 1} 카메라 재사용 준비 완료');
        }
      }
    } catch (error) {
      debugPrint('문장 ${_index + 1} 촬영 실패: $error');
      if (mounted) {
        setState(() {
          _recording = camera.value.isRecordingVideo;
          _error = '카메라 촬영 또는 영상 저장 중 문제가 발생했습니다. '
              '카메라를 다시 연결해 주세요.';
        });
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Fallback for a browser or Android device whose existing camera session
  /// cannot start another recording. Does not delete earlier sentence videos.
  Future<void> _reconnectCamera() async {
    if (_working || _recording || _finished) return;
    final oldCamera = _camera;
    setState(() {
      _working = true;
      _camera = null;
      _error = null;
    });
    try {
      if (oldCamera != null) {
        _cameraReleaseFuture = _releaseCameraAfterRecording(oldCamera);
      }
      await _initializeCamera();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cleanUp() => _cleanupFuture ??= _performCleanUp();

  Future<void> _performCleanUp() async {
    final camera = _camera;
    try {
      if (camera != null && camera.value.isInitialized && camera.value.isRecordingVideo) {
        final file = await camera.stopVideoRecording();
        _tempVideos.add(file);
      }
    } catch (_) {
      // Device may already have closed the camera.
    }
    for (final video in _tempVideos) {
      try {
        await deleteTemporaryVideo(video);
      } catch (_) {
        // Best-effort removal of temporary recordings.
      }
    }
    // A stopped recording may still be releasing its previous camera stream.
    try {
      await _cameraReleaseFuture;
    } catch (_) {
      // Best-effort shutdown.
    }
    await camera?.dispose();
  }

  Future<void> _finish() async {
    if (_working || _recording) return;
    setState(() => _working = true);
    await _cleanUp();
    if (mounted) widget.onFinished();
  }

  Future<void> _showAssessmentStatus() async {
    if (_working || !_finished) return;
    if (_tempVideos.length != _sentences.length) {
      setState(() => _error = '문장 영상 개수가 맞지 않습니다. 다시 촬영해 주세요.');
      return;
    }
    setState(() => _working = true);
    // Do NOT clean up here: the analysis route still needs all five XFiles.
    final navigator = Navigator.of(context);
    try {
      await navigator.push<void>(
        MaterialPageRoute<void>(builder: (_) => AssessmentAnalysisScreen(
          sentences: List<String>.unmodifiable(_sentences),
          videos: List<XFile>.unmodifiable(_tempVideos),
          onFinished: () {
            navigator.pop(); // Close report route first.
            widget.onFinished(); // Then close initial assessment; dispose cleans files.
          },
        )),
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    unawaited(_cleanUp());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final canCapture = !_working && !_finished &&
        camera != null && camera.value.isInitialized;
    return Scaffold(
      backgroundColor: AppStyle.background,
      appBar: AppBar(title: const Text('초기 발음 진단')),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Text(_finished ? '문장 촬영 완료' : '문장을 읽어 보세요',
            style: AppStyle.heading(size: 24)),
          const SizedBox(height: 6),
          Text(_finished ? '문장 음성 분석을 시작할 수 있어요.'
              : '평소 속도로 또박또박 읽어 보세요. 각 문장은 한 번씩만 촬영해요.',
            style: const TextStyle(color: AppStyle.muted, fontSize: 13)),
          const SizedBox(height: 17),
          LinearProgressIndicator(
            value: _finished ? 1 : (_index + 1) / _sentences.length,
            minHeight: 7,
            borderRadius: BorderRadius.circular(10),
            color: AppStyle.coral,
            backgroundColor: AppStyle.softBorder,
          ),
          const SizedBox(height: 9),
          Text(_finished ? '5 / 5 문장 촬영 완료'
              : '${_index + 1} / ${_sentences.length} 문장',
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppStyle.muted, fontSize: 12)),
          const SizedBox(height: 19),
          if (_finished) ...[
            PracticeSurface(color: AppStyle.paleCoral,
              child: Column(children: [
                const Icon(Icons.check_circle_outline_rounded,
                  color: AppStyle.coral, size: 58),
                const SizedBox(height: 12),
                Text('문장 촬영을 마쳤어요', style: AppStyle.heading(size: 20)),
                const SizedBox(height: 9),
                const Text('촬영한 문장 5개를 차례대로 음성 분석해요. '
                    '분석 결과는 음성 인식 문장과 기준 문장의 비교이며, '
                    '발음 정확도 점수는 아니에요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppStyle.muted,
                    fontSize: 13, height: 1.5)),
              ])),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _working ? null : _showAssessmentStatus,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('문장 음성 분석 시작'),
            )),
          ] else ...[
            PracticeSurface(color: AppStyle.paleCoral,
              child: Text(_sentences[_index],
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppStyle.ink,
                  fontWeight: FontWeight.w800, fontSize: 22))),
            const SizedBox(height: 15),
            const PracticeSectionTitle('카메라 촬영'),
            const SizedBox(height: 10),
            Container(
              height: (MediaQuery.of(context).size.height * 0.38)
                  .clamp(240.0, 350.0),
              clipBehavior: Clip.antiAlias,
              decoration: AppStyle.card(radius: 20),
              child: _error != null
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, textAlign: TextAlign.center)))
                : camera == null || !camera.value.isInitialized
                  ? const Center(child: CircularProgressIndicator())
                  : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    // Original November 3 camera preview framing and face guide.
                    // This widget is unchanged from the restored camera UI.
                    child: CustomPaint(
                      foregroundPainter: const FaceGuidePainter(),
                      child: CameraPreview(camera),
                    ),
                  ),
            ),
            const SizedBox(height: 13),
            Text(_recording
                ? '녹화 중 · 문장을 다 읽으면 종료를 눌러 주세요.'
                : '전면 카메라로 녹화한 문장에서 목소리만 분석해요.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppStyle.muted, fontSize: 12)),
            const SizedBox(height: 20),
            if (_error != null && !_working && !_recording)
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _reconnectCamera,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('카메라 다시 연결'),
              ))
            else
              SizedBox(width: double.infinity, child: FilledButton.icon(
                onPressed: canCapture ? _toggleRecording : null,
                icon: Icon(_recording
                    ? Icons.stop_circle_outlined : Icons.videocam_outlined),
                label: Text(_recording ? '촬영 종료' : '촬영 시작'),
              )),
            const SizedBox(height: 9),
            SizedBox(width: double.infinity, child: TextButton(
              onPressed: _working || _recording ? null : _finish,
              child: const Text('진단 중단하고 학습하기'),
            )),
          ],
        ],
      )),
    );
  }
}
