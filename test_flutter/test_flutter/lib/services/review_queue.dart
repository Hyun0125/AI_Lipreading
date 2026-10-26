import 'package:shared_preferences/shared_preferences.dart';

import 'demo_scenarios.dart';

/// 이용자가 직접 선택한 복습 대상. AI 추천이나 자동 점수 판정이 아니다.
class ReviewQueue {
  static const _queueKey = 'manual_review_phonemes_v1';
  // 이전 버전의 수동 완료 체크를 자동 완료 상태로 잘못 인정하지 않는다.
  static const _dailyKey = 'automatic_daily_review_checks_v2';

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static Future<Set<String>> read() async {
    if (DemoScenarios.isActive) return DemoScenarios.reviewQueue.toSet();
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_queueKey) ?? const <String>[]).toSet();
  }

  static Future<void> setIncluded(String phoneme, bool included) async {
    if (DemoScenarios.isActive) {
      if (included) { DemoScenarios.reviewQueue.add(phoneme); }
      else { DemoScenarios.reviewQueue.remove(phoneme); }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final items = (prefs.getStringList(_queueKey) ?? const <String>[]).toSet();
    if (included) {
      items.add(phoneme);
    } else {
      items.remove(phoneme);
    }
    await prefs.setStringList(_queueKey, items.toList()..sort());
  }

  /// 복습 목록에 있는 발음을 실제 촬영·분석까지 완료했을 때만 오늘 복습으로 인정.
  /// 이미 오늘 완료했으면 다시 기록하지 않으며, 대기열에 없으면 아무 일도 하지 않는다.
  static Future<bool> markReviewedAfterSuccessfulPractice(String phoneme) async {
    final queue = await read();
    if (!queue.contains(phoneme)) return false;
    final done = await reviewedToday();
    if (done.contains(phoneme)) return false;
    await setReviewedToday(phoneme, true);
    return true;
  }

  static Future<Set<String>> reviewedToday() async {
    if (DemoScenarios.isActive) return DemoScenarios.reviewedToday.toSet();
    final prefs = await SharedPreferences.getInstance();
    final prefix = '${_today()}|';
    return (prefs.getStringList(_dailyKey) ?? const <String>[])
        .where((item) => item.startsWith(prefix))
        .map((item) => item.substring(prefix.length))
        .toSet();
  }

  static Future<void> setReviewedToday(String phoneme, bool reviewed) async {
    if (DemoScenarios.isActive) {
      if (reviewed) { DemoScenarios.reviewedToday.add(phoneme); }
      else { DemoScenarios.reviewedToday.remove(phoneme); }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final entries = (prefs.getStringList(_dailyKey) ?? const <String>[]).toSet();
    final marker = '${_today()}|$phoneme';
    if (reviewed) {
      entries.add(marker);
    } else {
      entries.remove(marker);
    }
    await prefs.setStringList(_dailyKey, entries.toList()..sort());
  }
}
