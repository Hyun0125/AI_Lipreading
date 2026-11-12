import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/sentence_analysis_result.dart';

/// Calls the existing FastAPI route with category='문장', selecting voice_analysis.
/// Kept separate from FeedbackApi to avoid changing phoneme workflows.
class SentenceAnalysisApi {
  static Future<SentenceAnalysisResult> analyzeVideo({
    required String sentence,
    required XFile video,
    void Function(String stage)? onStatus,
  }) async {
    final request = http.MultipartRequest(
      'POST', Uri.parse('${AppConfig.baseUrl}/feedback/analyze'),
    );
    request.fields['category'] = '문장';
    request.fields['target_item'] = sentence;
    onStatus?.call('영상 업로드 준비 중');

    final file = kIsWeb
        ? http.MultipartFile.fromBytes(
            'video', await video.readAsBytes(),
            filename: video.name.isEmpty ? 'recording.webm' : video.name,
          )
        : await http.MultipartFile.fromPath(
            'video', video.path,
            filename: video.name.isEmpty ? 'recording.mp4' : video.name,
          );
    request.files.add(file);
    onStatus?.call('영상 전송 및 서버 음성 분석 중');

    // Whisper on CPU may need several minutes; phoneme API timeout is unchanged.
    final streamed = await request.send().timeout(const Duration(minutes: 6));
    final response = await http.Response.fromStream(streamed);
    onStatus?.call('서버 분석 결과 확인 중');
    if (response.statusCode != 200) {
      throw Exception('문장 분석 API 오류 (${response.statusCode})');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) {
      throw const FormatException('문장 분석 응답은 JSON 객체여야 합니다.');
    }
    final result = SentenceAnalysisResult.fromJson(
      Map<String, dynamic>.from(decoded),
    );
    if (result.referenceText != sentence) {
      throw const FormatException('문장 분석 결과가 요청한 문장과 다릅니다.');
    }
    return result;
  }
}
