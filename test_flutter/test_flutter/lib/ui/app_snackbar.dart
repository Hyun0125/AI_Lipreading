import 'package:flutter/material.dart';

/// 바른발음 전체 화면에서 공통으로 사용하는 플로팅 스낵바.
/// 일반 안내는 흰색 카드, 오류는 연한 코랄 카드로 구분한다.
class AppSnackBar {
  AppSnackBar._();

  static const Color _ink = Color(0xFF272D36);
  static const Color _paper = Color(0xFFFFFFFF);
  static const Color _border = Color(0xFFD4D9E1);
  static const Color _coral = Color(0xFFE76056);
  static const Color _paleCoral = Color(0xFFFFEFED);
  static const Color _errorIconBackground = Color(0xFFFFE1DC);
  static const Color _errorBorder = Color(0xFFF0BDB6);
  static const Color _errorText = Color(0xFF713D38);

  /// 일반 안내 및 성공 메시지: 3초가 기본값이다.
  static SnackBar info(
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    IconData icon = Icons.info_outline_rounded,
    bool persist = false,
  }) {
    return _build(
      message,
      isError: false,
      duration: duration,
      action: action,
      icon: icon,
      persist: persist,
    );
  }

  /// 오류 메시지: 5초가 기본값이다.
  static SnackBar error(
    String message, {
    Duration duration = const Duration(seconds: 5),
    IconData icon = Icons.error_outline_rounded,
  }) {
    return _build(
      message,
      isError: true,
      duration: duration,
      icon: icon,
    );
  }

  static SnackBar _build(
    String message, {
    required bool isError,
    required Duration duration,
    required IconData icon,
    SnackBarAction? action,
    bool persist = false,
  }) {
    final foreground = isError ? _errorText : _ink;
    final iconForeground = isError ? const Color(0xFFD9574F) : _coral;
    final iconBackground = isError ? _errorIconBackground : _paleCoral;

    return SnackBar(
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconForeground,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      duration: duration,
      action: action,
      persist: persist,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      backgroundColor: isError ? _paleCoral : _paper,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isError ? _errorBorder : _border,
          width: 1,
        ),
      ),
    );
  }
}
