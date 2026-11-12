import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/feedback_result.dart';

/// 시연 화면의 데이터는 실제 학습 기록/서버 DB와 분리한다.
/// 모드를 선택할 때마다 예시를 다시 설정하여 같은 시나리오를 재현할 수 있다.
enum DemoScenario { off, firstLaunch, studied, reviewing }

extension DemoScenarioLabel on DemoScenario {
  String get title => switch (this) {
    DemoScenario.off => '일반 사용 모드',
    DemoScenario.firstLaunch => 'A · 신규 사용자',
    DemoScenario.studied => 'B · 학습 기록이 있는 사용자',
    DemoScenario.reviewing => 'C · 복습 중인 사용자',
  };

  String get description => switch (this) {
    DemoScenario.off => '실제 기기 학습 기록과 서버 결과를 사용해요.',
    DemoScenario.firstLaunch => '기록 없는 상태에서 시작 화면과 초기 진단을 시연해요.',
    DemoScenario.studied => '모음 3개·자음 2개의 발음 연습 완료 및 날짜별 기록을 보여줘요.',
    DemoScenario.reviewing => '복습 항목 3개, 오늘 복습 1개, 예시 분석 기록을 보여줘요.',
  };
}

class DemoScenarios {
  static const _storageKey = 'demonstration_scenario_v1';
  static DemoScenario _scenario = DemoScenario.off;

  /// Indexed change notifier: selecting the SAME scenario also refreshes the UI.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static DemoScenario get current => _scenario;
  static bool get isActive => _scenario != DemoScenario.off;

  static final Set<String> completed = <String>{};
  static final Set<String> reviewQueue = <String>{};
  static final Set<String> reviewedToday = <String>{};
  static final List<Map<String, dynamic>> activities = <Map<String, dynamic>>[];
  static final List<FeedbackResult> feedbackResults = <FeedbackResult>[];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_storageKey);
    final scenario = DemoScenario.values.firstWhere(
      (option) => option.name == value,
      orElse: () => DemoScenario.off,
    );
    _apply(scenario);
  }

  static Future<void> select(DemoScenario scenario) async {
    // Prepare the display before publishing the mode. Never overwrite real keys.
    _apply(scenario);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, scenario.name);
  }

  static void _apply(DemoScenario scenario) {
    _scenario = scenario;
    completed.clear();
    reviewQueue.clear();
    reviewedToday.clear();
    activities.clear();
    feedbackResults.clear();

    if (scenario == DemoScenario.studied || scenario == DemoScenario.reviewing) {
      completed.addAll(['ㅏ', 'ㅓ', 'ㅗ', 'ㄱ', 'ㅁ']);
      addActivity('ㅏ', 'practiced', daysAgo: 8);
      addActivity('ㅓ', 'practiced', daysAgo: 5);
      addActivity('ㄱ', 'practiced', daysAgo: 5);
      addActivity('ㅓ', 'practiced', daysAgo: 5); // 같은 글자를 다시 연습한 예시
      addActivity('ㅗ', 'practiced', daysAgo: 2);
      addActivity('ㅁ', 'practiced', daysAgo: 1);
    }
    if (scenario == DemoScenario.reviewing) {
      completed.addAll(['ㅜ', 'ㅂ']);
      addActivity('ㅜ', 'practiced', daysAgo: 1);
      addActivity('ㅂ', 'practiced');
      reviewQueue.addAll(['ㄱ', 'ㅓ', 'ㅜ']);
      reviewedToday.add('ㅓ');
      addActivity('ㅓ', 'reviewed');
      feedbackResults.addAll([
        _example(-101, 'ㄱ', '자음', '가', 3, 68, 61,
          '입술과 턱의 움직임을 다시 살펴보세요.'),
        _example(-102, 'ㅓ', '모음', 'ㅓ', 1, 78, 74,
          '혀의 위치를 확인하고 다시 연습해 보세요.'),
      ]);
    }
    revision.value++;
  }

  static void addActivity(String phoneme, String type, {int daysAgo = 0}) {
    final day = DateTime.now().subtract(Duration(days: daysAgo));
    activities.add({
      'phoneme': phoneme,
      'type': type,
      'at': day.toIso8601String(),
    });
  }

  static FeedbackResult _example(int id, String letter, String category,
      String practice, int daysAgo, double audio, double visual,
      String advice) {
    final at = DateTime.now().subtract(Duration(days: daysAgo));
    return FeedbackResult.fromJson({
      'id': id, // Negative ids are reserved for artificial examples.
      'category': category,
      'target_item': letter,
      'target_pronunciation': practice,
      'created_at': at.toIso8601String(),
      'video_path': '',
      'whisper_result': practice,
      'is_correct': true,
      'speech_start_time': 0.2,
      'speech_end_time': 1.3,
      'speech_duration': 1.1,
      'volume': 0.06,
      'energy_change': 0.015,
      'average_pitch': 182,
      'pitch_change': 22,
      'speed_score': audio,
      'duration_score': audio,
      'stability_score': audio,
      'pitch_score': audio,
      'volume_score': audio,
      'audio_total_score': audio,
      'average_mouth_open_ratio': 0.31,
      'max_mouth_open_ratio': 0.43,
      'min_mouth_open_ratio': 0.12,
      'lip_movement_change': 0.18,
      'average_mouth_open_score': visual,
      'max_mouth_open_score': visual,
      'lip_movement_score': visual,
      'visual_total_score': visual,
      'feedbacks': ['[시연용 예시] 실제 촬영·AI 분석 결과가 아닙니다.', advice],
    });
  }

  /// In demonstration mode, saving a freshly analyzed result affects memory
  /// only, not the real FastAPI records. Examples stay marked with negative ids.
  static FeedbackResult addSessionResult(FeedbackResult result) {
    feedbackResults.insert(0, result);
    revision.value++;
    return result;
  }
}
