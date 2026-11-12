import 'package:flutter/material.dart';

import '../ui/app_style.dart';
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
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 700;
    final illustrationHeight = (screenHeight * 0.29).clamp(175.0, 235.0).toDouble();

    return Scaffold(
      backgroundColor: AppStyle.cream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: isCompact ? 18 : 30,
                          bottom: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // App identity: this is the first screen, not Home.
                            Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppStyle.paleCoral,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(
                                    Icons.record_voice_over_outlined,
                                    color: AppStyle.coral,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text('바른발음', style: AppStyle.heading(size: 20)),
                                const Spacer(),
                              ],
                            ),
                            SizedBox(height: isCompact ? 24 : 31),
                            Text(
                              '소리를 눈으로,\n발음을 차근차근.',
                              style: AppStyle.heading(size: isCompact ? 29 : 32),
                            ),
                            const SizedBox(height: 11),
                            const Text(
                              '입모양을 보고, 발음을 연습하고,\n내 변화를 하나씩 확인해 보세요.',
                              style: TextStyle(
                                color: AppStyle.muted,
                                fontSize: 13,
                                height: 1.55,
                              ),
                            ),
                            SizedBox(height: isCompact ? 19 : 25),
                            // Keep the supplied, original articulation image.
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                              decoration: AppStyle.card(radius: 22),
                              child: Column(
                                children: [
                                  Image.asset(
                                    'lib/assets/images/welcome_main.png',
                                    height: illustrationHeight,
                                    width: double.infinity,
                                    fit: BoxFit.contain,
                                    semanticLabel: '입과 혀의 발음 기관을 보여주는 그림',
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    '눈으로 살피는 입모양과 발음',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppStyle.coral,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 17),
                            // A short overview, not an extra navigation menu.
                            const Row(
                              children: [
                                Expanded(child: _IntroStep(
                                  icon: Icons.visibility_outlined,
                                  label: '보고 배우기',
                                )),
                                SizedBox(width: 8),
                                Expanded(child: _IntroStep(
                                  icon: Icons.mic_none_rounded,
                                  label: '말하며 연습',
                                )),
                                SizedBox(width: 8),
                                Expanded(child: _IntroStep(
                                  icon: Icons.insights_rounded,
                                  label: '변화 확인',
                                )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Keep the existing action and its consent/assessment flow.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => _next(context),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('시작하기'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 19),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '다음 화면에서 촬영·녹음 안내를 확인할 수 있어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppStyle.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroStep extends StatelessWidget {
  final IconData icon;
  final String label;

  const _IntroStep({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
    decoration: BoxDecoration(
      color: AppStyle.paleCoral,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppStyle.coral, size: 21),
        const SizedBox(height: 7),
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppStyle.ink,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
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
