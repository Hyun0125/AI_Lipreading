import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_scenarios.dart';
import 'review_queue.dart';

/// 연습(촬영 + 분석 응답 + 피드백 화면 표시)이 성공한 글자만 진도에 포함한다.
/// 기존 수동 '학습 완료' 기록(v3)은 자동으로 인정하지 않는다.
class LearningActivity {
  final String phoneme;
  final String type; // practiced / reviewed
  final DateTime at;

  const LearningActivity({required this.phoneme, required this.type, required this.at});

  Map<String, dynamic> toJson() => {
    'phoneme': phoneme,
    'type': type,
    'at': at.toIso8601String(),
  };

  static LearningActivity? fromText(String text) {
    try {
      final map = jsonDecode(text) as Map<String, dynamic>;
      final date = DateTime.tryParse(map['at']?.toString() ?? '');
      final phoneme = map['phoneme']?.toString() ?? '';
      if (date == null || phoneme.isEmpty) return null;
      return LearningActivity(
        phoneme: phoneme,
        type: map['type']?.toString() ?? '',
        at: date,
      );
    } catch (_) {
      return null;
    }
  }
}

class LearningProgress {
  // 새 키를 사용해 이전 버전에서 손으로 누른 완료 기록을 진행률에서 제외한다.
  static const _completedKey = 'practiced_phonemes_v1';
  static const _activityKey = 'learning_activities_v2';

  static const consonants = <String>{
    'ㄱ','ㄲ','ㄴ','ㄷ','ㄸ','ㄹ','ㅁ','ㅂ','ㅃ','ㅅ','ㅆ','ㅇ',
    'ㅈ','ㅉ','ㅊ','ㅋ','ㅌ','ㅍ','ㅎ',
  };
  static const vowels = <String>{
    'ㅏ','ㅐ','ㅑ','ㅒ','ㅓ','ㅔ','ㅕ','ㅖ','ㅗ','ㅘ','ㅙ','ㅚ',
    'ㅛ','ㅜ','ㅝ','ㅞ','ㅟ','ㅠ','ㅡ','ㅢ','ㅣ',
  };
  static const totalPhonemes = 40;

  /// 홈/조음 학습 화면을 촬영 성공 직후 갱신하기 위한 알림.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static bool isSupported(String phoneme, String category) =>
      (category == '자음' && consonants.contains(phoneme)) ||
      (category == '모음' && vowels.contains(phoneme));

  /// 한 번 이상 분석까지 완료한 서로 다른 음소. 반복 연습해도 수는 증가하지 않음.
  static Future<Set<String>> read() async {
    if (DemoScenarios.isActive) return DemoScenarios.completed.toSet();
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_completedKey) ?? <String>[])
        .where((phoneme) => consonants.contains(phoneme) || vowels.contains(phoneme))
        .toSet();
  }

  static Future<List<LearningActivity>> readActivities() async {
    if (DemoScenarios.isActive) {
      return DemoScenarios.activities
          .map((value) => LearningActivity.fromText(jsonEncode(value)))
          .whereType<LearningActivity>()
          .toList();
    }
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_activityKey) ?? const <String>[])
        .map(LearningActivity.fromText)
        .whereType<LearningActivity>()
        .toList();
  }

  static Future<void> _appendActivity(String phoneme, String type) async {
    if (DemoScenarios.isActive) {
      DemoScenarios.addActivity(phoneme, type);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final activities = prefs.getStringList(_activityKey) ?? <String>[];
    activities.add(jsonEncode(LearningActivity(
      phoneme: phoneme, type: type, at: DateTime.now(),
    ).toJson()));
    await prefs.setStringList(_activityKey, activities);
  }

  /// 서버 분석에 성공하고 해당 결과 화면이 정상 표시된 경우에만 호출.
  /// 반환값: 처음으로 완료한 음소인지 여부.
  static Future<bool> recordSuccessfulPractice({
    required String phoneme,
    required String category,
  }) async {
    if (!isSupported(phoneme, category)) return false;

    if (DemoScenarios.isActive) {
      final isNew = DemoScenarios.completed.add(phoneme);
      DemoScenarios.addActivity(phoneme, 'practiced');
      if (await ReviewQueue.markReviewedAfterSuccessfulPractice(phoneme)) {
        DemoScenarios.addActivity(phoneme, 'reviewed');
      }
      revision.value++;
      return isNew;
    }

    final prefs = await SharedPreferences.getInstance();
    final completed = (prefs.getStringList(_completedKey) ?? <String>[]).toSet();
    final isNew = completed.add(phoneme);
    // 저장 중 실패하면 화면이 완료되었다고 표시되지 않도록 완료 목록부터 저장한다.
    await prefs.setStringList(_completedKey, completed.toList()..sort());
    await _appendActivity(phoneme, 'practiced'); // 재연습도 매번 날짜·횟수 기록
    // 오늘의 복습은 수동 체크가 아니라, 복습 목록 항목의 연습 성공으로만 완료.
    if (await ReviewQueue.markReviewedAfterSuccessfulPractice(phoneme)) {
      await _appendActivity(phoneme, 'reviewed');
    }
    revision.value++;
    return isNew;
  }

  /// 복습의 '오늘 복습 완료' 표시: 학습 진행률과 무관.
  static Future<void> recordReview(String phoneme) =>
      _appendActivity(phoneme, 'reviewed');

  /// 설정에서 진도만 초기화. 저장된 분석 및 과거 날짜별 활동은 그대로 보존.
  static Future<void> resetProgress() async {
    if (DemoScenarios.isActive) {
      DemoScenarios.completed.clear();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_completedKey);
    }
    revision.value++;
  }
}
