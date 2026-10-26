import 'package:flutter/material.dart';

import '../services/demo_scenarios.dart';
import '../ui/app_style.dart';
import 'articulation_catalog_screen.dart';
import 'dashboard_screen.dart';
import 'feedback_screen.dart';
import 'history_hub_screen.dart';
import 'initial_assessment_screen.dart';
import 'learning_calendar_screen.dart';
import 'learning_home_screen.dart';
import 'onboarding_screen.dart';
import 'review_practice_screen.dart';
import 'settings_home_screen.dart';

/// Bottom-bar roots are separate from full-screen detail routes.
/// Home → learning → practice → feedback and Review → calendar (inline date details)
/// share the existing analysis and database services.
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  void _setTab(int next) => setState(() => _tab = next);

  void _openDetails(String phoneme) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: AppStyle.background,
        body: SafeArea(child: ArticulationCatalogScreen(
          initialPhoneme: phoneme,
          onBackToCategories: () => Navigator.of(context).pop(),
        )),
      ),
    ));
  }

  void _openPicker(bool consonant) {
    // 모음/자음 카드를 누르면 중간 음소 선택 목록 없이 큰 조음 그림으로 진입.
    _openDetails(consonant ? 'ㅂ' : 'ㅏ');
  }

  void _openReviewPractice(String phoneme) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ReviewPracticeScreen(
        phoneme: phoneme,
        onStudy: () => _openDetails(phoneme),
        onRecord: () => _openRecording(phoneme),
      ),
    ));
  }

  void _openRecording(String phoneme) {
    const consonants = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FeedbackScreen(
        item: phoneme,
        category: consonants.contains(phoneme) ? '자음' : '모음',
      ),
    ));
  }

  void _openCalendar() => Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => LearningCalendarScreen(
      onPractice: _openReviewPractice,
      initialLatestActivity: true,
    ),
  ));

  Future<void> _switchScenario(DemoScenario scenario) async {
    await DemoScenarios.select(scenario);
    if (!mounted) return;
    setState(() => _tab = 0);
    if (scenario == DemoScenario.firstLaunch) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (routeContext) => OnboardingStartScreen(
          onFinished: () async {
            if (routeContext.mounted) Navigator.of(routeContext).pop();
          },
        ),
      ));
    }
  }

  Future<void> _retakeAssessment() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (routeContext) => InitialAssessmentScreen(
        onFinished: () => Navigator.of(routeContext).pop(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(
        onPractice: _openDetails,
        onAssess: _retakeAssessment,
        onOpenHistory: _openCalendar,
        onOpenLearning: () => _setTab(1),
        onOpenReview: () => _setTab(2),
      ),
      LearningHomeScreen(onSelectPhonemes: _openPicker),
      HistoryHubScreen(onPractice: _openReviewPractice),
      SettingsHomeScreen(onAssess: _retakeAssessment,
        onSelectScenario: _switchScenario),
    ];

    return Scaffold(
      backgroundColor: AppStyle.background,
      body: SafeArea(child: ValueListenableBuilder<int>(
        valueListenable: DemoScenarios.revision,
        builder: (context, revision, _) => Column(children: [
          if (DemoScenarios.isActive)
            Material(color: AppStyle.paleCoral,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
                child: Row(children: [
                  const Icon(Icons.science_outlined, color: AppStyle.coral, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('시연 모드 · ${DemoScenarios.current.title} · 가상 데이터',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  TextButton(onPressed: () => _switchScenario(DemoScenario.off),
                    child: const Text('종료')),
                ]),
              ),
            ),
          Expanded(child: KeyedSubtree(
            key: ValueKey('root_${_tab}_$revision'),
            child: pages[_tab],
          )),
        ]),
      )),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(color: Colors.white,
            border: Border(top: BorderSide(color: AppStyle.softBorder))),
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 5),
          child: Row(children: [
            _NavigationItem(title: '홈', icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded, active: _tab==0,
              onTap: () => _setTab(0)),
            _NavigationItem(title: '학습', icon: Icons.menu_book_outlined,
              selectedIcon: Icons.menu_book_rounded, active: _tab==1,
              onTap: () => _setTab(1)),
            _NavigationItem(title: '복습', icon: Icons.repeat_rounded,
              selectedIcon: Icons.autorenew_rounded, active: _tab==2,
              onTap: () => _setTab(2)),
            _NavigationItem(title: '설정', icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded, active: _tab==3,
              onTap: () => _setTab(3)),
          ]),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final bool active;
  final VoidCallback onTap;
  const _NavigationItem({required this.title, required this.icon,
    required this.selectedIcon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(button: true, selected: active, label: '$title 탭',
      child: InkWell(
        onTap: onTap,
        child: SizedBox(height: 62,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(active ? selectedIcon : icon,
              color: active ? AppStyle.coral : AppStyle.muted, size: 24),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(
              color: active ? AppStyle.ink : AppStyle.muted,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              fontSize: 11)),
          ]),
        ),
      ),
    ),
  );
}
