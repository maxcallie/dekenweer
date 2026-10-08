import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui.dart';
import 'horse_painter.dart';

/// Nero – de mascotte van Dekenweer: een vos met een brede bles, een roze
/// snoet met grijze vlekjes en een donkerblauw halster.
///
/// Lokale coördinaten: midden = (0,0), ongeveer -50..50 breed en -100..62
/// hoog.
void paintNeroHead(Canvas canvas, {double blink = 0, double earTilt = 0}) {
  const coat = Color(0xFFBC6431);
  const coatDark = Color(0xFF9C4E24);
  const mane = Color(0xFFA4502A);
  const earIn = Color(0xFF7E3C1C);
  const white = Color(0xFFF6F1EA);
  const pink = Color(0xFFEED6CD);
  const spot = Color(0xFF6F6A6D);
  const nostril = Color(0xFF3A3133);
  const halter = Color(0xFF22325A);
  const eyeColor = Color(0xFF1C1412);

  final p = Paint()..isAntiAlias = true;

  void oval(double x, double y, double rx, double ry, double rot, Color c) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rot);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        p..color = c);
    canvas.restore();
  }

  // Oren
  void ear(double side) {
    canvas.save();
    canvas.translate(side * 22, -66);
    canvas.rotate(side * (0.32 + earTilt));
    canvas.drawPath(
        Path()
          ..moveTo(-9, 6)
          ..quadraticBezierTo(-8, -22, 0, -34)
          ..quadraticBezierTo(8, -22, 9, 6)
          ..close(),
        p..color = coat);
    canvas.drawPath(
        Path()
          ..moveTo(-5, 2)
          ..quadraticBezierTo(-4, -16, 0, -26)
          ..quadraticBezierTo(4, -16, 5, 2)
          ..close(),
        p..color = earIn);
    canvas.restore();
  }

  ear(-1);
  ear(1);

  final head = Path()
    ..moveTo(0, -78)
    ..cubicTo(22, -78, 36, -64, 38, -40)
    ..cubicTo(40, -18, 30, 8, 26, 26)
    ..cubicTo(32, 40, 30, 60, 0, 62)
    ..cubicTo(-30, 60, -32, 40, -26, 26)
    ..cubicTo(-30, 8, -40, -18, -38, -40)
    ..cubicTo(-36, -64, -22, -78, 0, -78)
    ..close();
  canvas.drawPath(head, p..color = coat);

  canvas.save();
  canvas.clipPath(head);
  // zachte schaduw op de wangen
  final cheek = const Color(0xFF783214).withValues(alpha: 0.18);
  oval(-34, -10, 10, 34, 0.1, cheek);
  oval(34, -10, 10, 34, -0.1, cheek);
  // brede bles
  canvas.drawPath(
      Path()
        ..moveTo(-12, -70)
        ..cubicTo(-4, -73, 6, -73, 13, -69)
        ..cubicTo(16, -50, 15, -30, 15, -10)
        ..cubicTo(16, 6, 22, 18, 28, 30)
        ..lineTo(28, 70)
        ..lineTo(-28, 70)
        ..lineTo(-28, 30)
        ..cubicTo(-20, 18, -15, 6, -14, -10)
        ..cubicTo(-14, -30, -16, -50, -12, -70)
        ..close(),
      p..color = white);
  // roze snoet met grijze vlekjes rond de neusgaten
  oval(0, 46, 28, 18, 0, pink);
  oval(-18, 35, 7, 5, 0.6, spot);
  oval(19, 34, 8, 5, -0.6, spot);
  oval(-22, 44, 3.5, 3, 0, spot);
  oval(23, 45, 4, 3, 0, spot);
  oval(0, 57, 17, 5, 0, const Color(0xFF786464).withValues(alpha: 0.45));
  canvas.restore();

  // neusgaten
  oval(-14, 40, 4, 6.5, 0.5, nostril);
  oval(14, 40, 4, 6.5, -0.5, nostril);
  // mond
  canvas.drawPath(
      Path()
        ..moveTo(-10, 57)
        ..quadraticBezierTo(0, 60, 10, 57),
      Paint()
        ..color = const Color(0xFF463232).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round);

  // halster
  canvas.save();
  canvas.clipPath(head);
  canvas.drawPath(
      Path()
        ..moveTo(-40, 10)
        ..quadraticBezierTo(0, 18, 40, 10)
        ..lineTo(40, 17)
        ..quadraticBezierTo(0, 25, -40, 17)
        ..close(),
      p..color = halter);
  canvas.drawRect(const Rect.fromLTWH(-40, -16, 7, 30), p..color = halter);
  canvas.drawRect(const Rect.fromLTWH(33, -16, 7, 30), p..color = halter);
  canvas.restore();
  canvas.drawCircle(const Offset(-34, 14), 3, p..color = const Color(0xFFC9CDD6));
  canvas.drawCircle(const Offset(34, 14), 3, p..color = const Color(0xFFC9CDD6));

  // ogen
  void eye(double side) {
    canvas.save();
    canvas.translate(side * 31, -30);
    canvas.rotate(side * 0.2);
    final h = 9 * (1 - blink) + 1;
    final eyeRect = Rect.fromCenter(center: Offset.zero, width: 13, height: h / 1.5 * 2);
    canvas.drawOval(eyeRect, p..color = eyeColor);
    // Nero is blind aan zijn linkeroog (van voren rechts in beeld)
    final blind = side > 0;
    if (blind) paintEyeHaze(canvas, eyeRect, const Offset(0.5, 0.8), 5.5);
    if (blink < 0.5) {
      canvas.drawCircle(Offset(side * -1.5, -2.5), blind ? 1.5 : 1.8,
          p..color = Colors.white.withValues(alpha: blind ? 0.9 : 1));
    }
    canvas.drawArc(
        Rect.fromCenter(center: const Offset(0, -1), width: 16, height: 15),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        Paint()
          ..color = coatDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.restore();
  }

  eye(-1);
  eye(1);

  // voorlok (kort en piekerig, zoals bij Nero)
  canvas.drawPath(
      Path()
        ..moveTo(-15, -72)
        ..lineTo(-14, -86)
        ..lineTo(-8, -76)
        ..lineTo(-5, -92)
        ..lineTo(0, -78)
        ..lineTo(5, -94)
        ..lineTo(7, -77)
        ..lineTo(13, -88)
        ..lineTo(15, -72)
        ..quadraticBezierTo(8, -62, 2, -60)
        ..quadraticBezierTo(-8, -62, -15, -72)
        ..close(),
      p..color = mane);
}

/// Geanimeerde Nero (knippert af en toe en draait een oor).
class NeroMascot extends StatefulWidget {
  const NeroMascot({super.key, this.size = 96});
  final double size;

  @override
  State<NeroMascot> createState() => _NeroMascotState();
}

class _NeroMascotState extends State<NeroMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(painter: _NeroPainter(_c)),
    );
  }
}

class _NeroPainter extends CustomPainter {
  _NeroPainter(this.anim) : super(repaint: anim);
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    // knipperen rond 0.92–0.97 van de cyclus
    final blink = t > 0.92 && t < 0.97 ? math.sin((t - 0.92) / 0.05 * math.pi) : 0.0;
    // oor draait even rond 0.4–0.5
    final ear = t > 0.4 && t < 0.5 ? math.sin((t - 0.4) / 0.1 * math.pi) * -0.25 : 0.0;
    final s = size.shortestSide / 170;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + 19 * s);
    canvas.scale(s);
    paintNeroHead(canvas, blink: blink, earTilt: ear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NeroPainter old) => false;
}

/// Tekstballon met een tip van Nero.
class NeroTip extends StatelessWidget {
  const NeroTip(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const NeroMascot(size: 46),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.line),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
              topLeft: Radius.circular(4),
            ),
          ),
          child: Text.rich(TextSpan(children: [
            const TextSpan(
                text: 'Tip van Nero  ',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.green)),
            TextSpan(text: text),
          ]), style: const TextStyle(fontSize: 14, height: 1.35)),
        ),
      ),
    ]);
  }
}
