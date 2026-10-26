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