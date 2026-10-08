import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hoefijzer-icoon (in plaats van de hondenpoot uit de standaard-iconen).
class HorseshoeIcon extends StatelessWidget {
  const HorseshoeIcon({super.key, this.size = 24, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.black;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _HorseshoePainter(c)),
    );
  }
}

class _HorseshoePainter extends CustomPainter {
  _HorseshoePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 24;
    canvas.save();
    canvas.scale(s);
    final p = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(5.0, 21.6)
      ..cubicTo(2.4, 18, 2.2, 13, 2.6, 10.6)
      ..cubicTo(3.2, 5, 7.2, 2.2, 12, 2.2)
      ..cubicTo(16.8, 2.2, 20.8, 5, 21.4, 10.6)
      ..cubicTo(21.8, 13, 21.6, 18, 19.0, 21.6)
      ..lineTo(15.9, 21.0)
      ..cubicTo(17.6, 17.5, 17.6, 13.5, 17.2, 11.2)
      ..cubicTo(16.8, 8, 14.6, 6.3, 12, 6.3)
      ..cubicTo(9.4, 6.3, 7.2, 8, 6.8, 11.2)
      ..cubicTo(6.4, 13.5, 6.4, 17.5, 8.1, 21.0)
      ..close();
    // spijkergaten
    for (final h in const [
      Offset(4.6, 17.4), Offset(4.3, 13.4), Offset(5.4, 9.0),
      Offset(19.4, 17.4), Offset(19.7, 13.4), Offset(18.6, 9.0),
    ]) {
      p.addOval(Rect.fromCircle(center: h, radius: 0.8));
    }
    canvas.drawPath(p, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HorseshoePainter old) => old.color != color;
}
