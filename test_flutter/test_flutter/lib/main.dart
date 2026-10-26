import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/app_shell.dart';
import 'ui/app_style.dart';
import 'services/accessibility_settings.dart';
import 'services/demo_scenarios.dart';
import 'screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AccessibilitySettings.load();
  await DemoScenarios.load();
  runApp(const SpeechTrainerApp());
}

class SpeechTrainerApp extends StatelessWidget {
  const SpeechTrainerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '발음 한걸음',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppStyle.coral,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: AppStyle.background,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppStyle.background,
            elevation: 0,
            centerTitle: false,
          ),
          filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
            backgroundColor: AppStyle.coral,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppStyle.softBorder,
            disabledForegroundColor: AppStyle.muted,
            minimumSize: const Size.fromHeight(53),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          )),
          textTheme: const TextTheme(
            headlineSmall: TextStyle(fontWeight: FontWeight.w800, color: AppStyle.ink),
            titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppStyle.ink),
          ),
        ),
        builder: (context, child) => ValueListenableBuilder<double>(
          valueListenable: AccessibilitySettings.textScale,
          builder: (context, scale, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const LaunchGate(),
      );
}

/// Persistent onboarding is separate from an AI diagnosis result: dismissing
/// onboarding must NEVER be treated as a successful AI assessment.
class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key});
  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  bool? _introduced;
  bool _demoIntroductionFinished = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _introduced = prefs.getBool('intro_seen_v1') ?? false);
    }
  }

  Future<void> _finishIntroduction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_seen_v1', true);
    if (mounted) setState(() => _introduced = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_introduced == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (DemoScenarios.current == DemoScenario.firstLaunch &&
        !_demoIntroductionFinished) {
      return OnboardingStartScreen(onFinished: () async {
        if (mounted) setState(() => _demoIntroductionFinished = true);
      });
    }
    if (!_introduced!) {
      return OnboardingStartScreen(onFinished: _finishIntroduction);
    }
    return const AppShell();
  }
}
