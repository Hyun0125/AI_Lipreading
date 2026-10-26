import 'package:flutter/material.dart';

import '../services/accessibility_settings.dart';
import '../services/demo_scenarios.dart';
import '../services/learning_progress.dart';
import '../ui/app_style.dart';

class DemoSelectionScreen extends StatefulWidget {
  final ValueChanged<DemoScenario> onApply;
  const DemoSelectionScreen({super.key, required this.onApply});

  @override
  State<DemoSelectionScreen> createState() => _DemoSelectionScreenState();
}

class _DemoSelectionScreenState extends State<DemoSelectionScreen> {
  late DemoScenario selection;
  @override
  void initState() {
    super.initState();
    selection = DemoScenarios.current;
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    title: '시연용 사용자 상태',
    children: [
      const Text('발표에서 보여줄 사용자 상태를 선택해요. 일반 모드의 학습 기록과 '
        '서버 데이터는 변경되지 않습니다.',
        style: TextStyle(color: AppStyle.muted, height: 1.55)),
      const SizedBox(height: 18),
      Container(
        decoration: AppStyle.card(),
        child: Material(type: MaterialType.transparency,
          child: RadioGroup<DemoScenario>(
          groupValue: selection,
          onChanged: (value) {
            if (value != null) {
              setState(() => selection = value);
            }
          },
          child: Column(children: [
            for (final scenario in DemoScenario.values)
              RadioListTile<DemoScenario>(
                key: Key('demo_option_${scenario.name}'),
                value: scenario,
                activeColor: AppStyle.coral,
                title: Text(scenario.title, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800)),
                subtitle: Text(scenario.description,
                  style: const TextStyle(fontSize: 11, color: AppStyle.muted)),
              ),
          ]),
        )),
      ),
      const SizedBox(height: 15),
      Container(decoration: AppStyle.card(color: AppStyle.paleCoral),
        padding: const EdgeInsets.all(14),
        child: const Text('A: 최초 실행 · B: 자음 2개와 모음 3개 학습 이력 · '
          'C: 복습 목록과 예시 분석 결과\n'
          '시연 중 영상 분석을 요청하면 실제 분석 서버로 전송될 수 있습니다. '
          '예시 점수에는 시연용 표시가 유지됩니다.',
          style: TextStyle(fontSize: 12, height: 1.6))),
      const SizedBox(height: 22),
      FilledButton(
        key: const Key('demo_start'),
        onPressed: () {
          // Pop the settings detail first; the shell owns the route reset.
          Navigator.of(context).pop();
          widget.onApply(selection);
        },
        child: const Text('선택한 상태로 시연 시작'),
      ),
    ],
  );
}

class TextSizeScreen extends StatelessWidget {
  const TextSizeScreen({super.key});

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    title: '글자 크기',
    children: [
      const Text('앱 전체의 글자를 크게 표시할 수 있어요.',
        style: TextStyle(color: AppStyle.muted)),
      const SizedBox(height: 18),
      ValueListenableBuilder<double>(
        valueListenable: AccessibilitySettings.textScale,
        builder: (context, scale, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final entry in const <(double, String)>[
                (1.0, '보통'), (1.18, '크게'), (1.35, '아주 크게'),
              ])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: (entry.$1 - scale).abs() < .01,
                  selectedColor: AppStyle.paleCoral,
                  onSelected: (_) => AccessibilitySettings.setTextScale(entry.$1),
                ),
            ]),
            const SizedBox(height: 18),
            Container(decoration: AppStyle.card(color: AppStyle.softInk),
              padding: const EdgeInsets.all(18),
              child: const Text('입을 크게 벌리고 ‘아’ 하고 발음해 보세요.',
                style: TextStyle(fontSize: 16, height: 1.5))),
          ],
        ),
      ),
    ],
  );
}

class PermissionGuideScreen extends StatelessWidget {
  const PermissionGuideScreen({super.key});
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    title: '카메라·마이크 권한',
    children: [
      Container(decoration: AppStyle.card(), padding: const EdgeInsets.all(16),
        child: const Material(type: MaterialType.transparency,
          child: Column(children: [
            ListTile(leading: Icon(Icons.camera_alt_outlined, color: AppStyle.coral),
              title: Text('카메라'), subtitle: Text('입모양과 얼굴 영상 촬영')),
            Divider(),
            ListTile(leading: Icon(Icons.mic_none_rounded, color: AppStyle.coral),
              title: Text('마이크'), subtitle: Text('발음하는 음성 녹음')),
          ]))),
      const SizedBox(height: 17),
      const Text('기기에서 권한을 변경하려면',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 9),
      Container(decoration: AppStyle.card(color: AppStyle.softInk),
        padding: const EdgeInsets.all(16),
        child: const Text('기기 설정 → 앱 → 발음한걸음 → 권한 → 카메라·마이크 허용',
          style: TextStyle(height: 1.6))),
      const SizedBox(height: 13),
      const Text('이 화면은 권한 변경 방법을 안내합니다. 실제 권한 요청은 '
        '촬영 기능을 시작할 때 기기에서 진행돼요.',
        style: TextStyle(color: AppStyle.muted, fontSize: 12, height: 1.5)),
    ],
  );
}

class ResetProgressScreen extends StatefulWidget {
  const ResetProgressScreen({super.key});
  @override
  State<ResetProgressScreen> createState() => _ResetProgressScreenState();
}

class _ResetProgressScreenState extends State<ResetProgressScreen> {
  bool working = false;
  Future<void> _reset() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('발음 연습 진행률을 초기화할까요?'),
        content: const Text('홈의 완료 글자 수만 초기화합니다. 서버에 저장된 발음 분석 '
          '결과는 삭제하지 않습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('초기화')),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => working = true);
    await LearningProgress.resetProgress();
    if (!mounted) return;
    setState(() => working = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('발음 연습 진행률을 초기화했어요.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => _DetailScaffold(
    title: '학습 진행 상태 초기화',
    children: [
      Container(decoration: AppStyle.card(), padding: const EdgeInsets.all(20),
        child: const Column(children: [
          Icon(Icons.restart_alt_rounded, color: AppStyle.coral, size: 45),
          SizedBox(height: 12),
          Text('발음 연습 진행률을 처음부터 시작합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          SizedBox(height: 10),
          Text('녹화·분석 결과나 과거 학습 날짜는 삭제되지 않습니다. '
            '시연 모드에서는 실제 사용자의 학습 기록에도 영향을 주지 않습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppStyle.muted, height: 1.5)),
        ])),
      const SizedBox(height: 18),
      FilledButton(onPressed: working ? null : _reset,
        child: Text(working ? '초기화 중...' : '발음 연습 진행률 초기화')),
    ],
  );
}

class PrivacyGuideScreen extends StatelessWidget {
  const PrivacyGuideScreen({super.key});
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    title: '개인정보 및 촬영 데이터',
    children: const [
      _InformationSection('카메라와 마이크를 사용하는 이유',
        '발음의 입모양과 음성을 수집하여 분석하기 위해 사용합니다.'),
      _InformationSection('개별 발음 분석',
        '사용자가 분석을 요청하면 촬영 영상이 설정된 FastAPI 서버로 전송됩니다. '
        '결과 저장을 선택하면 분석 결과가 서버 기록에 추가됩니다.'),
      _InformationSection('초기 문장 진단',
        '현재 초기 진단 서버는 연결되지 않았습니다. 진단 화면 종료 시 '
        '임시 촬영 파일 삭제를 시도하며, 실제 점수는 생성하지 않습니다.'),
      _InformationSection('보관 및 삭제',
        '서버에 보관되는 원본 영상의 보관 기간과 삭제 방법은 '
        '최종 서버 구현 정책을 확인해야 합니다. 앱에 서버 기록 삭제 기능은 없습니다.'),
    ],
  );
}

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});
  @override
  Widget build(BuildContext context) => _DetailScaffold(
    title: '앱 정보',
    children: [
      Container(decoration: AppStyle.card(color: AppStyle.paleCoral),
        padding: const EdgeInsets.all(25),
        child: const Column(children: [
          Icon(Icons.record_voice_over_outlined,
            size: 52, color: AppStyle.coral),
          SizedBox(height: 12),
          Text('발음한걸음', style: TextStyle(
            fontSize: 25, fontWeight: FontWeight.w900)),
          SizedBox(height: 9),
          Text('AI를 활용한 청각장애인을 위한 발음 학습도우미',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppStyle.muted, height: 1.5)),
        ])),
      const SizedBox(height: 18),
      const _InformationSection('프로젝트 소개',
        '자음·모음 조음 원리를 시각적으로 확인하고, '
        '직접 발음해 본 뒤 피드백과 복습으로 연결합니다.'),
      const _InformationSection('현재 제공 범위',
        '자음·모음 학습, 촬영과 기존 서버 분석, 저장된 결과 조회, '
        '복습 목록 및 달력, 시연용 A/B/C 상태를 제공합니다. '
        '단어·문장 학습과 문장 진단 AI 분석은 준비 중입니다.'),
      const Text('UI 시안 반영 v7 · 졸업프로젝트 시연용',
        style: TextStyle(color: AppStyle.muted, fontSize: 12)),
    ],
  );
}

class _InformationSection extends StatelessWidget {
  final String title;
  final String description;
  const _InformationSection(this.title, this.description);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(decoration: AppStyle.card(), padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(description, style: const TextStyle(
          color: AppStyle.muted, height: 1.6, fontSize: 13)),
      ])),
  );
}

class _DetailScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _DetailScaffold({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppStyle.background,
    appBar: AppBar(title: Text(title)),
    body: SafeArea(child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 17, 20, 35),
      children: children,
    )),
  );
}
