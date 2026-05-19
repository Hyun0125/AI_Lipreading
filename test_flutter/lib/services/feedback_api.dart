import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/dummy_review_data.dart';
import '../models/feedback_result.dart';

const String baseUrl = 'http://192.168.181.44:8000';
class FeedbackApi {
  static bool useDummyData = false; // 서버 연결 시 false

  static Future<List<FeedbackResult>> getReviewResults({
    required String category,
    required String targetItem,
  }) async {
    if (useDummyData) {
      final results = dummyReviewData[targetItem] ?? [];

      return results.where((result) {
        return result.category == category && result.targetItem == targetItem;
      }).toList();
    }

    final uri = Uri.parse(
      '$baseUrl/feedback/results?category=$category&target_item=$targetItem',
    );

    final response = await http.get(uri);

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

  static Future<List<FeedbackResult>> getAllReviewResults() async {
    if (useDummyData) {
      return dummyReviewData.values.expand((results) => results).toList();
    }

    final uri = Uri.parse('$baseUrl/feedback/results');

    final response = await http.get(uri);

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