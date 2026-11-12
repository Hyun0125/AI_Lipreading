import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../config/app_config.dart';
import '../models/feedback_result.dart';
import 'demo_scenarios.dart';

// 피드백 API 통신 클래스
// 영상 분석 요청, 피드백 저장 요청, 복습 기록 조회 요청을 담당한다.
class FeedbackApi {
  // Per-phoneme count cache. The short TTL prevents stale counts while making
  // back-and-forth selection instant during the same learning session.
  static const Duration _savedPracticeCountCacheTtl = Duration(seconds: 30);
  static final Map<String, _SavedPracticeCountCacheEntry>
      _savedPracticeCountCache = <String, _SavedPracticeCountCacheEntry>{};
  static final Map<String, Future<int>> _savedPracticeCountRequests =
      <String, Future<int>>{};

  static String _savedPracticeCountKey({
    required String category,
    required String targetItem,
    int? userId,
  }) => '$category|$targetItem|${userId ?? 'all'}';

  /// Returns the last known count immediately, even when its cache is stale.
  /// The caller can display it while getSavedPracticeCount refreshes it.
  static int? cachedSavedPracticeCount({
    required String category,
    required String targetItem,
    int? userId,
  }) {
    if (DemoScenarios.isActive) {
      return DemoScenarios.feedbackResults.where((result) =>
        result.category == category &&
        result.targetItem == targetItem &&
        (userId == null || result.userId == userId)
      ).length;
    }
    return _savedPracticeCountCache[
      _savedPracticeCountKey(
        category: category,
        targetItem: targetItem,
        userId: userId,
      )
    ]?.count;
  }

  /// Counts only saved DB rows; analysis responses that were not saved do not
  /// contribute. Demo mode uses its existing in-memory demo result list.
  static Future<int> getSavedPracticeCount({
    required String category,
    required String targetItem,
    int? userId,
    bool forceRefresh = false,
  }) async {
    if (DemoScenarios.isActive) {
      return DemoScenarios.feedbackResults.where((result) =>
        result.category == category &&
        result.targetItem == targetItem &&
        (userId == null || result.userId == userId)
      ).length;
    }

    final key = _savedPracticeCountKey(
      category: category,
      targetItem: targetItem,
      userId: userId,
    );
    final cached = _savedPracticeCountCache[key];
    final now = DateTime.now();
    if (!forceRefresh && cached != null &&
        now.difference(cached.cachedAt) < _savedPracticeCountCacheTtl) {
      return cached.count;
    }

    // If this exact count is already being fetched, share that request.
    final pending = _savedPracticeCountRequests[key];
    if (pending != null) return pending;

    final request = _fetchSavedPracticeCount(
      category: category,
      targetItem: targetItem,
      userId: userId,
      cacheKey: key,
    );
    _savedPracticeCountRequests[key] = request;
    try {
      return await request;
    } finally {
      if (identical(_savedPracticeCountRequests[key], request)) {
        _savedPracticeCountRequests.remove(key);
      }
    }
  }

  static Future<int> _fetchSavedPracticeCount({
    required String category,
    required String targetItem,
    required int? userId,
    required String cacheKey,
  }) async {
    final uri = _uri('/feedback/count').replace(queryParameters: {
      'category': category,
      'target_item': targetItem,
      if (userId != null) 'user_id': userId.toString(),
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception(
        '저장 횟수 조회 오류: ${response.statusCode}, ${response.body}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('저장 횟수 응답 형식이 올바르지 않습니다.');
    }
    final data = Map<String, dynamic>.from(decoded);
    final rawCount = data['count'];
    if (rawCount is! num || rawCount < 0) {
      throw const FormatException('서버 응답에 올바른 count 값이 없습니다.');
    }

    final count = rawCount.toInt();
    _savedPracticeCountCache[cacheKey] = _SavedPracticeCountCacheEntry(
      count: count,
      cachedAt: DateTime.now(),
    );
    return count;
  }

  /// A successful save is authoritative: update a fresh cache immediately.
  /// Stale cache entries are discarded so the next visit reads the DB again.
  static void _updateSavedPracticeCountAfterSave({
    required String category,
    required String targetItem,
    required int? userId,
  }) {
    if (category != '자음' && category != '모음') return;

    final now = DateTime.now();
    final keys = <String>{
      _savedPracticeCountKey(category: category, targetItem: targetItem),
      if (userId != null)
        _savedPracticeCountKey(
          category: category,
          targetItem: targetItem,
          userId: userId,
        ),
    };

    for (final key in keys) {
      final cached = _savedPracticeCountCache[key];
      if (cached != null &&
          now.difference(cached.cachedAt) < _savedPracticeCountCacheTtl) {
        _savedPracticeCountCache[key] = _SavedPracticeCountCacheEntry(
          count: cached.count + 1,
          cachedAt: now,
        );
      } else {
        _savedPracticeCountCache.remove(key);
      }
    }
  }

  // 서버 요청 주소를 생성하는 함수
  // AppConfig.baseUrl에 API 경로를 붙여 Uri 형태로 변환한다.
  static Uri _uri(String path) {
    return Uri.parse('${AppConfig.baseUrl}$path');
  }

  // 촬영한 영상을 서버로 업로드하고 AI 분석 결과를 받아오는 함수
  // multipart/form-data 형식으로 category, target_item, video 파일을 함께 전송한다.
  static Future<FeedbackResult> analyzeVideo({
    required String category,
    required String targetItem,
    required XFile video,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/feedback/analyze'),
    );

    request.fields['category'] = category;
    request.fields['target_item'] = targetItem;

    // fromPath는 dart:io를 사용하므로 웹에서는 호출할 수 없다.
    // 웹은 카메라의 XFile에서 직접 바이트를 읽는다.
    final file = kIsWeb
        ? http.MultipartFile.fromBytes(
            'video',
            await video.readAsBytes(),
            filename: video.name.isEmpty ? 'recording.webm' : video.name,
          )
        : await http.MultipartFile.fromPath(
            'video', video.path,
            filename: video.name.isEmpty ? 'recording.mp4' : video.name,
          );
    request.files.add(file);

    final streamedResponse = await request.send().timeout(const Duration(seconds: 300));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('서버 오류: ${response.statusCode}, ${response.body}');
    }

    final data = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    return FeedbackResult.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  // 분석된 피드백 결과를 서버에 저장하는 함수
  // FeedbackResult 객체를 저장용 JSON으로 변환하여 /feedback/save로 전송한다.
  static Future<FeedbackResult> saveFeedbackResult({
    required FeedbackResult result,
    required int? userId,
  }) async {
    if (DemoScenarios.isActive) {
      return DemoScenarios.addSessionResult(result);
    }
    final response = await http.post(
      _uri('/feedback/save'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(
        result.toSaveJson(
          userId: userId,
        ),
      ),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('서버 오류: ${response.statusCode}, ${response.body}');
    }

    final data = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    if (data['success'] != true) {
      throw Exception(data['message'] ?? '저장 실패');
    }

    _updateSavedPracticeCountAfterSave(
      category: result.category,
      targetItem: result.targetItem,
      userId: userId,
    );

    return FeedbackResult.fromJson(
      Map<String, dynamic>.from(data),
    );
  }

  // 특정 학습 항목의 복습 기록을 조회하는 함수
  // category, target_item, user_id를 기준으로 저장된 피드백 결과 목록을 가져온다.
  static Future<List<FeedbackResult>> getReviewResults({
    required String category,
    required String targetItem,
    int? userId,
  }) async {
    if (DemoScenarios.isActive) {
      return DemoScenarios.feedbackResults.where((result) =>
        result.category == category && result.targetItem == targetItem).toList();
    }
    final queryParameters = {
      'category': category,
      'target_item': targetItem,
      if (userId != null) 'user_id': userId.toString(),
    };

    final uri = Uri.parse('${AppConfig.baseUrl}/feedback/results').replace(
      queryParameters: queryParameters,
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('서버 오류: ${response.statusCode}');
    }

    final List<dynamic> jsonList = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    return jsonList
        .map((json) => FeedbackResult.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  // 사용자의 전체 복습 기록을 조회하는 함수
  // 복습모드에서 저장된 피드백이 있는 항목을 활성화할 때 사용한다.
  static Future<List<FeedbackResult>> getAllReviewResults({
    int? userId,
  }) async {
    if (DemoScenarios.isActive) {
      return List<FeedbackResult>.of(DemoScenarios.feedbackResults);
    }
    final uri = userId == null
        ? _uri('/feedback/results')
        : Uri.parse('${AppConfig.baseUrl}/feedback/results').replace(
      queryParameters: {
        'user_id': userId.toString(),
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw Exception('서버 오류: ${response.statusCode}');
    }

    final List<dynamic> jsonList = jsonDecode(
      utf8.decode(response.bodyBytes),
    );

    return jsonList
        .map((json) => FeedbackResult.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
}

class _SavedPracticeCountCacheEntry {
  final int count;
  final DateTime cachedAt;

  const _SavedPracticeCountCacheEntry({
    required this.count,
    required this.cachedAt,
  });
}
