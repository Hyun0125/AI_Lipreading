import 'package:flutter/material.dart';

import '../services/demo_scenarios.dart';
import '../ui/app_style.dart';
import 'settings_detail_screens.dart';

class SettingsHomeScreen extends StatelessWidget {
  final VoidCallback onAssess;
  final ValueChanged<DemoScenario> onSelectScenario;
  const SettingsHomeScreen({super.key, required this.onAssess,
    required this.onSelectScenario});

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 23, 20, 34),
    children: [
      Text('설정', style: AppStyle.heading(size: 28)),
      const SizedBox(height: 22),
      const _SettingsHeading('학습 관리'),
      _SettingsGroup(children: [
        _SettingsRow(title: '발음 다시 진단하기',
          subtitle: '현재 발음 상태 다시 확인', icon: Icons.assignment_turned_in_outlined,
          onTap: onAssess),
        _SettingsRow(title: '학습 진행 상태 초기화',
          subtitle: '연습 완료 글자 수만 초기화', icon: Icons.restart_alt_rounded,
          onTap: () => _push(context, const ResetProgressScreen())),
      ]),
      const SizedBox(height: 23),
      const _SettingsHeading('화면 및 접근성'),
      _SettingsGroup(children: [
        _SettingsRow(title: '글자 크기',
          subtitle: '보통 · 크게 · 아주 크게', icon: Icons.text_fields_rounded,
          onTap: () => _push(context, const TextSizeScreen())),
        _SettingsRow(title: '카메라·마이크 권한',
          subtitle: '기기 권한 확인 방법', icon: Icons.camera_alt_outlined,
          onTap: () => _push(context, const PermissionGuideScreen())),
      ]),
      const SizedBox(height: 23),
      const _SettingsHeading('시연 및 테스트'),
      _SettingsGroup(children: [
        _SettingsRow(title: '시연용 사용자 상태',
          subtitle: '${DemoScenarios.current.title} · A/B/C 전환',
          icon: Icons.groups_2_outlined,
          onTap: () => _push(context,
            DemoSelectionScreen(onApply: onSelectScenario))),
      ]),
      const SizedBox(height: 23),
      const _SettingsHeading('정보 및 데이터 관리'),
      _SettingsGroup(children: [
        _SettingsRow(title: '개인정보 및 촬영 데이터 안내',
          subtitle: '영상·음성 처리 및 저장 정보', icon: Icons.shield_outlined,
          onTap: () => _push(context, const PrivacyGuideScreen())),
        _SettingsRow(title: '앱 정보', subtitle: '프로젝트 소개 및 버전',
          icon: Icons.info_outline_rounded,
          onTap: () => _push(context, const AboutAppScreen())),
      ]),
    ],
  );
}

class _SettingsHeading extends StatelessWidget {
  final String text;
  const _SettingsHeading(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Text(text, style: const TextStyle(
      color: AppStyle.muted, fontSize: 12, fontWeight: FontWeight.w800)),
  );
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: AppStyle.card(),
    child: Material(type: MaterialType.transparency, child: Column(children: [
      for (var i=0; i<children.length; i++) ...[
        if (i>0) const Divider(color: AppStyle.softBorder, height: 1, indent: 15, endIndent: 15),
        children[i],
      ],
    ])),
  );
}

class _SettingsRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _SettingsRow({required this.title, required this.subtitle,
    required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    leading: Container(width: 39, height: 39,
      decoration: BoxDecoration(color: AppStyle.paleCoral,
        borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Icon(icon, color: AppStyle.coral, size: 22)),
    title: Text(title, style: const TextStyle(
      fontSize: 14, fontWeight: FontWeight.w800)),
    subtitle: Text(subtitle,
      style: const TextStyle(fontSize: 11, color: AppStyle.muted)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppStyle.muted),
    onTap: onTap,
  );
}
