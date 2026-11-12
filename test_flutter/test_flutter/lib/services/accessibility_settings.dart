import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted text scaling preference for accessibility.
class AccessibilitySettings {
  static const _key = 'app_text_scale_v1';
  static final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getDouble(_key) ?? 1.0;
    textScale.value = stored.clamp(1.0, 1.35).toDouble();
  }

  static Future<void> setTextScale(double scale) async {
    textScale.value = scale.clamp(1.0, 1.35).toDouble();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, textScale.value);
  }
}
