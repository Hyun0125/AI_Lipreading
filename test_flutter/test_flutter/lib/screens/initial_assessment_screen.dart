import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../ui/app_style.dart';
import '../widgets/practice_visuals.dart';
import '../services/temporary_video_file.dart';
import 'assessment_status_screen.dart';

/// VIDEO + AUDIO collection only. A specialist must provide the sentence-level
/// analysis API before this can yield any personalized diagnosis or score.
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
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('사용 가능한 카메라가 없습니다.');
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(camera, ResolutionPreset.medium, enableAudio: true);
      _camera = controller;
      await controller.initialize();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = '카메라 또는 마이크를 사용할 수 없습니다. 기기 권한을 확인해 주세요.');
    }
  }

  Future<void> _toggleRecording() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _working) return;
    setState(() => _working = true);
    try {
      if (!_recording) {
        await camera.startVideoRecording();
        if (mounted) setState(() => _recording = true);
      } else {
        final file = await camera.stopVideoRecording();
        _tempVideos.add(file);
        if (mounted) {
          setState(() {
            _recording = false;
            if (_index < _sentences.length - 1) {
              _index++;
            } else {
              _finished = true;
            }
          });
        }
      }
    } catch (error) {
      if (mounted) setState(() => _error = '녹화 중 문제가 발생했습니다. 다시 시도해 주세요.');
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
    await camera?.dispose();
  }

  Future<void> _finish() async {
    if (_working) return;
    setState(() => _working = true);
    await _cleanUp();
    if (mounted) widget.onFinished();
  }

  Future<void> _showAssessmentStatus() async {
    if (_working || !_finished) return;
    setState(() => _working = true);
    await _cleanUp();
    if (!mounted) return;
    final navigator = Navigator.of(context);
    await navigator.push<void>(
      MaterialPageRoute<void>(builder: (_) => AssessmentAnalysisScreen(
        onFinished: () {
          navigator.pop(); // Close analysis/report route first.
          widget.onFinished(); // Then close the initial assessment route.
        },
      )),
    );
    if (mounted) setState(() => _working = false);
  }

  @override
  void dispose() {
    unawaited(_cleanUp());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final canCapture = _error == null && !_working && camera != null &&
        camera.value.isInitialized;
    return Scaffold(
      backgroundColor: AppStyle.background,
      appBar: AppBar(title: const Text('초기 발음 진단')),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          Text(_finished ? '문장 촬영 완료' : '문장을 읽어 보세요',
            style: AppStyle.heading(size: 24)),
          const SizedBox(height: 6),
          Text(_finished ? '진단 상태를 확인할 수 있어요.'
              : '평소 속도로 또박또박 읽어 보세요.',
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
                const Text('분석 모듈은 아직 연결되지 않았습니다. '
                    '발음 점수나 취약 발음을 임의로 표시하지 않아요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppStyle.muted,
                    fontSize: 13, height: 1.5)),
              ])),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _working ? null : _showAssessmentStatus,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('진단 상태 확인'),
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
                    child: CameraPreview(camera)),
            ),
            const SizedBox(height: 13),
            Text(_recording
                ? '녹화 중 · 문장을 다 읽으면 종료를 눌러 주세요.'
                : '전면 카메라로 입모양과 목소리를 함께 녹화해요.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppStyle.muted, fontSize: 12)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: canCapture ? _toggleRecording : null,
              icon: Icon(_recording
                  ? Icons.stop_circle_outlined : Icons.videocam_outlined),
              label: Text(_recording ? '촬영 종료 · 다음 문장' : '촬영 시작'),
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
