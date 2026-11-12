import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'demo_scenarios.dart';

/// The real review queue lives in backend3/feedback.db, not SharedPreferences.
/// Demo mode continues using its original in-memory scenario data.
class ReviewQueue {
  // Old device-only keys are read ONCE to preserve existing review selections.
  static const _oldQueueKey = 'manual_review_phonemes_v1';
  static const _oldDailyKey = 'automatic_daily_review_checks_v2';
  static const _migrationKey = 'review_queue_sqlite_migrated_v1';
  static Future<void>? _migrationInProgress;

  /// Allows the existing home/review screens to refresh without UI redesign.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static Uri _url([String? phoneme, String? action]) {
    final root = AppConfig.baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final suffix = phoneme == null ? '' : '/${Uri.encodeComponent(phoneme)}';
    return Uri.parse('$root/review/queue$suffix${action == null ? '' : '/$action'}');
  }

  static Future<http.Response> _send(Future<http.Response> request) async {
    http.Response response;
    try {
      response = await request.timeout(const Duration(seconds: 15));
    } catch (error) {
      throw StateError('복습 DB 서버에 연결하지 못했어요. backend3 실행 상태를 확인해 주세요. ($error)');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = utf8.decode(response.bodyBytes);
      final preview = body.length > 250 ? body.substring(0, 250) : body;
      throw StateError(
        '복습 DB 요청 실패 (HTTP ${response.statusCode}): $preview',
      );
    }
    return response;
  }

  static Future<Map<String, dynamic>> _getJson(Future<http.Response> request) async {
    final response = await _send(request);
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('복습 DB 응답 형식이 올바르지 않아요.');
    }
    return decoded;
  }

  static Future<void> _putIncluded(String phoneme, bool included) async {
    await _send(http.put(
      _url(phoneme),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'included': included}),
    ));
  }

  static Future<void> _putReviewed(String phoneme, bool reviewed) async {
    await _send(http.put(
      _url(phoneme, 'reviewed'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'reviewed': reviewed}),
    ));
  }

  static Future<void> _ensureMigrated() async {
    if (DemoScenarios.isActive) return;
    if (_migrationInProgress != null) {
      await _migrationInProgress;
      return;
    }
    final task = _migrateOldLocalQueue();
    _migrationInProgress = task;
    try {
      await task;
    } finally {
      if (identical(_migrationInProgress, task)) {
        _migrationInProgress = null;
      }
    }
  }

  static Future<void> _migrateOldLocalQueue() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationKey) == true) return;
    final oldItems = (prefs.getStringList(_oldQueueKey) ?? const <String>[])
        .where((value) => RegExp(r'^[ㄱ-ㅎㅏ-ㅣ]$').hasMatch(value)).toSet();
    final oldDone = (prefs.getStringList(_oldDailyKey) ?? const <String>[]).toSet();
    for (final phoneme in oldItems) {
      // Endpoint is idempotent. If migration fails, it can safely retry.
      await _putIncluded(phoneme, true);
      if (oldDone.contains('${_today()}|$phoneme')) {
        await _putReviewed(phoneme, true);
      }
    }
    // Do not clear old preferences: they form an additional backup.
    await prefs.setBool(_migrationKey, true);
  }

  static Future<_ReviewSnapshot> _fetch() async {
    await _ensureMigrated();
    final data = await _getJson(http.get(_url()));
    final values = data['items'];
    if (values is! List) {
      throw const FormatException('복습 DB 목록 형식이 올바르지 않아요.');
    }
    final items = <String>{};
    final done = <String>{};
    for (final value in values) {
      if (value is! Map) continue;
      final phoneme = value['phoneme'];
      if (phoneme is! String || phoneme.isEmpty) continue;
      items.add(phoneme);
      if (value['reviewed_today'] == true) done.add(phoneme);
    }
    return _ReviewSnapshot(items, done);
  }

  static Future<Set<String>> read() async {
    if (DemoScenarios.isActive) return DemoScenarios.reviewQueue.toSet();
    return (await _fetch()).items;
  }

  static Future<void> setIncluded(String phoneme, bool included) async {
    if (DemoScenarios.isActive) {
      if (included) {
        DemoScenarios.reviewQueue.add(phoneme);
      } else {
        DemoScenarios.reviewQueue.remove(phoneme);
      }
    } else {
      await _ensureMigrated();
      await _putIncluded(phoneme, included);
    }
    revision.value++;
  }

  static Future<Set<String>> reviewedToday() async {
    if (DemoScenarios.isActive) return DemoScenarios.reviewedToday.toSet();
    return (await _fetch()).done;
  }

  static Future<void> setReviewedToday(String phoneme, bool reviewed) async {
    if (DemoScenarios.isActive) {
      if (reviewed) {
        DemoScenarios.reviewedToday.add(phoneme);
      } else {
        DemoScenarios.reviewedToday.remove(phoneme);
      }
    } else {
      await _ensureMigrated();
      await _putReviewed(phoneme, reviewed);
    }
    revision.value++;
  }

  /// Called only after a successful recording + analysis + feedback display.
  /// Server atomically marks a queued item once per Korean calendar day.
  static Future<bool> markReviewedAfterSuccessfulPractice(String phoneme) async {
    if (DemoScenarios.isActive) {
      if (!DemoScenarios.reviewQueue.contains(phoneme) ||
          DemoScenarios.reviewedToday.contains(phoneme)) {
        return false;
      }
      DemoScenarios.reviewedToday.add(phoneme);
      revision.value++;
      return true;
    }
    await _ensureMigrated();
    final response = await _getJson(http.post(_url(phoneme, 'complete')));
    final marked = response['marked'] == true;
    if (marked) revision.value++;
    return marked;
  }
}

class _ReviewSnapshot {
  final Set<String> items;
  final Set<String> done;
  const _ReviewSnapshot(this.items, this.done);
}
