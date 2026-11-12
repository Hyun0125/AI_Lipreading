import 'package:flutter/material.dart';
import '../ui/app_style.dart';

/// Simple decorative illustration, not an anatomically validated phoneme map.
/// Detailed learning diagrams remain separate per sound in the catalog.
class MouthSketch extends StatelessWidget {
  final double height;
  const MouthSketch({super.key, this.height = 205});

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: '입과 혀의 위치를 보여주는 발음 학습 안내 그림',
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _MouthSketchPainter()),
    ),
  );
}

class _MouthSketchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final sx = size.width / 270;
    final sy = size.height / 200;
    canvas.scale(sx, sy);
    final line = Paint()
      ..color = AppStyle.ink
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final tongueFill = Paint()
      ..color = const Color(0xFFF3A5A1)
      ..style = PaintingStyle.fill;
    final tongueOutline = Paint()
      ..color = AppStyle.coral
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // Face/nose and roof of mouth in a clean Figma-like profile.
    final upper = Path()
      ..moveTo(64, 13)
      ..cubicTo(64, 48, 48, 52, 31, 72)
      ..cubicTo(14, 89, 22, 102, 42, 104)
      ..cubicTo(64, 106, 74, 85, 115, 82)
      ..cubicTo(167, 77, 219, 103, 243, 147);
    canvas.drawPath(upper, line);

    final palate = Path()
      ..moveTo(48, 112)
      ..cubicTo(75, 105, 90, 105, 122, 104)
      ..cubicTo(178, 101, 220, 119, 242, 156);
    canvas.drawPath(palate, line);

    final lip = Path()
      ..moveTo(40, 119)
      ..cubicTo(28, 130, 28, 135, 37, 139)
      ..cubicTo(43, 140, 43, 131, 49, 129)
      ..moveTo(39, 145)
      ..cubicTo(28, 155, 29, 166, 49, 167);
    canvas.drawPath(lip, line);

    final lower = Path()
      ..moveTo(48, 168)
      ..cubicTo(94, 169, 131, 166, 161, 168)
      ..cubicTo(191, 170, 204, 187, 212, 196);
    canvas.drawPath(lower, line);

    final tongue = Path()
      ..moveTo(54, 162)
      ..cubicTo(83, 148, 133, 146, 171, 156)
      ..cubicTo(192, 162, 202, 174, 204, 183)
      ..cubicTo(158, 172, 111, 169, 54, 166)
      ..close();
    canvas.drawPath(tongue, tongueFill);
    canvas.drawPath(tongue, tongueOutline);
    canvas.drawCircle(const Offset(54, 158), 4.2, Paint()..color = AppStyle.coral);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MouthSketchPainter oldDelegate) => false;
}
