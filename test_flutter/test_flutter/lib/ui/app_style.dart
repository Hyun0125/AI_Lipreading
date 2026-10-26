import 'package:flutter/material.dart';

/// Color tokens based on the twelve-screen coral Figma storyboard.
/// The interface uses warm, calm surfaces; important actions are color + text.
abstract final class AppStyle {
  static const background = Color(0xFFF6F7F9);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF222731);
  static const muted = Color(0xFF79838F);
  static const coral = Color(0xFFE76056);
  static const paleCoral = Color(0xFFFFF0ED);
  static const softBorder = Color(0xFFE7E9EC);
  static const mint = Color(0xFFF0F5F4);
  static const orange = Color(0xFFFFF4EA);
  static const blue = Color(0xFFEDF4F7);
  static const cream = Color(0xFFFFF8F4);
  // Legacy components use sage for their selected state; match the Figma coral.
  static const sage = coral;
  static const softInk = Color(0xFFF4F5F7);

  static BoxDecoration card({Color color = paper, double radius = 18}) =>
      BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: softBorder),
      );

  static TextStyle heading({double size = 24}) => TextStyle(
        color: ink,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.24,
        letterSpacing: -0.65,
      );
}
