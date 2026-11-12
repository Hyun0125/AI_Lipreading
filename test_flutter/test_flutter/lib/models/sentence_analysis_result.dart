/// A sentence-only response. Keep the raw voice_analysis payload intact.
/// Do not deserialize using FeedbackResult: its legacy numeric scores default
/// from null to zero and its recognized text may be shortened.
class SentenceAnalysisResult {
  final String referenceText;
  final String recognizedText;
  final bool? normalizedMatch;
  final double? characterSimilarityPercent;
  final Map<String, dynamic> voiceAnalysis;

  const SentenceAnalysisResult({
    required this.referenceText,
    required this.recognizedText,
    required this.normalizedMatch,
    required this.characterSimilarityPercent,
    required this.voiceAnalysis,
  });

  factory SentenceAnalysisResult.fromJson(Map<String, dynamic> json) {
    if (json['category'] != '문장') {
      throw const FormatException('문장 분석 응답의 category가 올바르지 않습니다.');
    }
    final payload = json['voice_analysis'];
    if (payload is! Map) {
      throw const FormatException('voice_analysis 응답이 없습니다.');
    }
    final voice = Map<String, dynamic>.from(payload);
    final rawComparison = voice['text_comparison'];
    final comparison = rawComparison is Map
        ? Map<String, dynamic>.from(rawComparison)
        : <String, dynamic>{};
    final rawSimilarity = comparison['character_similarity_percent'];
    final similarity = rawSimilarity is num ? rawSimilarity.toDouble() : null;

    return SentenceAnalysisResult(
      referenceText: json['target_item']?.toString() ?? '',
      recognizedText: voice['recognized_text']?.toString() ?? '',
      normalizedMatch: comparison['normalized_match'] is bool
          ? comparison['normalized_match'] as bool
          : null,
      characterSimilarityPercent: similarity,
      voiceAnalysis: voice,
    );
  }
}
