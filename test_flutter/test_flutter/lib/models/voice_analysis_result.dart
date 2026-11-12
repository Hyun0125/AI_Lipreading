
class VoiceAnalysisResult {
  final Map<String, dynamic> raw;

  const VoiceAnalysisResult(this.raw);

  factory VoiceAnalysisResult.fromJson(
      Map<String, dynamic> json,
      ) {
    return VoiceAnalysisResult(
      Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> get audioFeatures {
    final value = raw['audio_features'];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  Map<String, dynamic> getSection(String name) {
    final value = audioFeatures[name];

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  double? getNumber(String section, String key) {
    final value = getSection(section)[key];

    if (value is num) {
      return value.toDouble();
    }

    return null;
  }

  String get recognizedText {
    return raw['recognized_text']?.toString() ?? '';
  }

  // 발화 시간
  double? get totalDuration =>
      getNumber('duration', 'total_sec');

  double? get speechDuration =>
      getNumber('duration', 'speech_sec');

  double? get silenceDuration =>
      getNumber('duration', 'silence_sec');

  // 말하기 속도
  double? get speechRate =>
      getNumber('speech_rate', 'syllables_per_second');

  // 음량
  double? get meanVolume =>
      getNumber('volume', 'mean_db');

  // 음높이
  double? get meanPitch =>
      getNumber('pitch', 'mean_hz');

  // 쉼
  double? get pauseCount =>
      getNumber('pause', 'count');

  // 유성음 비율
  double? get voicedRatio =>
      getNumber('voice', 'voiced_ratio_percent');

  // 저장할 때 원본 JSON 유지
  Map<String, dynamic> toJson() {
    return Map<String, dynamic>.from(raw);
  }
}
