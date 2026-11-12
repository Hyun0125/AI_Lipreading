import 'package:flutter/material.dart';

// 얼굴 가이드라인을 그리는 CustomPainter
class FaceGuidePainter extends CustomPainter {
  const FaceGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Rect fullRect = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    );

    final Rect faceRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.65,
      height: size.height * 0.75,
    );

    // saveLayer를 사용해야 BlendMode.clear가 타원 안쪽만 투명하게 제거된다.
    canvas.saveLayer(fullRect, Paint());

    // 전체 미리보기 영역을 먼저 반투명 회색으로 덮는다.
    final Paint outsidePaint = Paint()
      ..color = Colors.grey.shade600.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;

    canvas.drawRect(fullRect, outsidePaint);

    // 얼굴 타원 영역만 투명하게 뚫는다.
    final Paint clearPaint = Paint()
      ..blendMode = BlendMode.clear;

    canvas.drawOval(faceRect, clearPaint);

    canvas.restore();

    // 얼굴 영역 테두리
    final Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawOval(faceRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
