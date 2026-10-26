import 'package:flutter/material.dart';

import '../ui/app_style.dart';
import '../widgets/mouth_sketch.dart';
import 'initial_assessment_screen.dart';

/// Screen 01 — only shown on the first launch.
class OnboardingStartScreen extends StatelessWidget {
  final Future<void> Function() onFinished;
  const OnboardingStartScreen({super.key, required this.onFinished});

  Future<void> _next(BuildContext context) async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OnboardingConsentScreen(),
      ),
    );
    if (completed == true) await onFinished();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppStyle.cream,
    body: SafeArea(child: Column(children: [
      Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 38, 24, 14),
        children: [
          Text('소리를 눈으로\n배우는 시간',
            style: AppStyle.heading(size: 36)),
          const SizedBox(height: 12),
          const Text('나에게 맞는 자음·모음 발음 훈련',
            style: TextStyle(fontSize: 15, color: AppStyle.muted)),
          const SizedBox(height: 35),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppStyle.card(radius: 22),
            child: const Column(children: [
              MouthSketch(height: 235),
              SizedBox(height: 9),
              Text('시각적 발음 학습', style: TextStyle(
                color: AppStyle.coral, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      )),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 21),
        child: Column(children: [
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: () => _next(context),
            child: const Text('시작하기'),
          )),
          const SizedBox(height: 10),
          const Text('영상과 음성을 함께 활용해요',
            style: TextStyle(color: AppStyle.muted, fontSize: 12)),
        ]),
      ),
    ])),
  );
}

/// Screen 02 — explains recording and asks for permission before initializing
/// the camera. Dismissing it never implies permission was granted.
class OnboardingConsentScreen extends StatefulWidget {
  const OnboardingConsentScreen({super.key});

  @override
  State<OnboardingConsentScreen> createState() => _OnboardingConsentScreenState();
}

class _OnboardingConsentScreenState extends State<OnboardingConsentScreen> {
  bool _checked = false;
  bool _busy = false;

  Future<void> _goToAssessment() async {
    if (!_checked || _busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final finished = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (routeContext) => InitialAssessmentScreen(
          onFinished: () => navigator.pop(true),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (finished == true) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('촬영·녹음 동의')),
    body: SafeArea(child: ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 25),
      children: [
        Text('정확한 발음 분석을 위해\n다음 기능을 사용해요.',
          style: AppStyle.heading(size: 25)),
        const SizedBox(height: 20),
        _PermissionInfo(
          icon: Icons.camera_alt_outlined,
          title: '카메라',
          subtitle: '입술과 얼굴의 움직임을 촬영해요.',
        ),
        const SizedBox(height: 12),
        _PermissionInfo(
          icon: Icons.mic_none_rounded,
          title: '마이크',
          subtitle: '발음하는 음성을 녹음해요.',
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppStyle.card(color: AppStyle.paleCoral),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('내 데이터는 어떻게 처리되나요?', style: TextStyle(
              fontWeight: FontWeight.w800, color: AppStyle.ink)),
            SizedBox(height: 8),
            Text('초기 문장 진단 영상은 현재 서버에 전송되지 않아요. '
                '진단 화면을 종료할 때 임시 촬영 파일 삭제를 시도합니다. '
                '개별 발음 피드백을 요청하는 경우에만 해당 영상이 설정된 분석 서버로 전송됩니다.',
              style: TextStyle(color: AppStyle.muted, fontSize: 12, height: 1.6)),
          ]),
        ),
        const SizedBox(height: 14),
        CheckboxListTile(
          value: _checked,
          onChanged: (value) => setState(() => _checked = value ?? false),
          title: const Text('촬영·녹음 안내를 확인했어요',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          activeColor: AppStyle.coral,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 25),
        SizedBox(width: double.infinity, child: FilledButton(
          onPressed: _checked && !_busy ? _goToAssessment : null,
          child: const Text('동의하고 다음으로'),
        )),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(true),
          child: const Text('나중에 진단하기',
            style: TextStyle(color: AppStyle.muted)),
        ),
      ],
    )),
  );
}

class _PermissionInfo extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _PermissionInfo({
    required this.icon, required this.title, required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    decoration: AppStyle.card(),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: AppStyle.paleCoral,
          borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, color: AppStyle.coral),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(
            color: AppStyle.muted, fontSize: 12)),
        ],
      )),
    ]),
  );
}
