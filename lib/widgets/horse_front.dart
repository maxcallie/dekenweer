import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/blanket_advisor.dart';
import '../models/horse.dart';
import 'horse_painter.dart';

/// Welk deel van het paard van voren getekend wordt.
enum FrontPart { all, body, head }

/// Paard van voren (voor de stal-scène). Lokale coördinaten: het hoofd rond
/// (0,0), van -100 (oorpunten) tot 62 (snoet); hals en borst lopen door tot 170.
void paintHorseFront(Canvas canvas, HorseLook look,
    {FrontPart part = FrontPart.all, double blink = 0, double earTilt = 0}) {
  final coat = look.coat;
  final body = coat.body;
  final head = coat.head ?? body;
  final p = Paint()..isAntiAlias = true;
  final blanket = look.blanketColor;
  final lvl = look.level;

  void oval(double x, double y, double rx, double ry, double rot, Color c) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rot);
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), p..color = c);
    canvas.restore();
  }

  // ---- hals, borst en deken ----------------------------------------------
  if (part != FrontPart.head) {
    final neck = Path()
      ..moveTo(-30, 0)
      ..lineTo(30, 0)
      ..cubicTo(36, 40, 44, 70, 70, 100)
      ..lineTo(82, 170)
      ..lineTo(-82, 170)
      ..lineTo(-70, 100)
      ..cubicTo(-44, 70, -36, 40, -30, 0)
      ..close();
    canvas.drawPath(neck, p..color = body);
    canvas.save();
    canvas.clipPath(neck);
    oval(0, 40, 34, 26, 0, shadeColor(body, -0.12).withValues(alpha: 0.6));
    if (coat.flecks != null) {
      final f = coat.flecks!.withValues(alpha: 0.5);
      for (var i = 0; i < 60; i++) {
        canvas.drawCircle(
            Offset(((i * 53) % 140) - 70.0, ((i * 37) % 160) + 5.0), 0.9, p..color = f);
      }
    }
    canvas.restore();

    if (lvl.wearsBlanket && blanket != null) {
      final b = lvl == BlanketLevel.rainSheet ? shadeColor(blanket, 0.12) : blanket;
      final trim = shadeColor(b, 0.22);
      final top = Path();
      if (look.neckCover) {
        top
          ..moveTo(-31, 22)
          ..quadraticBezierTo(0, 30, 31, 22);
      } else {
        top
          ..moveTo(-58, 80)
          ..quadraticBezierTo(0, 48, 58, 80);
      }
      final rug = Path.from(top)
        ..lineTo(90, 175)
        ..lineTo(-90, 175)
        ..close();
      canvas.save();
      canvas.clipPath(neck);
      canvas.drawPath(rug, p..color = b);
      if (lvl.index >= BlanketLevel.medium.index) {
        final stitch = Paint()
          ..color = shadeColor(b, 0.1).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        for (var y = look.neckCover ? 40.0 : 90.0; y < 170; y += 12) {
          canvas.drawPath(
              Path()
                ..moveTo(-80, y + 10)
                ..quadraticBezierTo(0, y - 8, 80, y + 10),
              stitch);
        }
      }
      canvas.restore();
      canvas.drawPath(
          top,
          Paint()
            ..color = trim
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      final strap = Paint()
        ..color = shadeColor(b, -0.2)
        ..strokeWidth = 4;
      for (final y in const [104.0, 122.0]) {
        canvas.drawLine(Offset(-12, y), Offset(12, y), strap);
        canvas.drawCircle(Offset(0, y), 3, p..color = const Color(0xFFC9CDD6));
      }
    }
  }
  if (part == FrontPart.body) return;

  // ---- oren ----------------------------------------------------------------
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
        p..color = head);
    canvas.drawPath(
        Path()
          ..moveTo(-5, 2)
          ..quadraticBezierTo(-4, -16, 0, -26)
          ..quadraticBezierTo(4, -16, 5, 2)
          ..close(),
        p..color = shadeColor(head, -0.15));
    canvas.restore();
  }

  ear(-1);
  ear(1);

  // ---- hoofd ---------------------------------------------------------------
  final hp = Path()
    ..moveTo(0, -78)
    ..cubicTo(22, -78, 36, -64, 38, -40)
    ..cubicTo(40, -18, 30, 8, 26, 26)
    ..cubicTo(32, 40, 30, 60, 0, 62)
    ..cubicTo(-30, 60, -32, 40, -26, 26)
    ..cubicTo(-30, 8, -40, -18, -38, -40)
    ..cubicTo(-36, -64, -22, -78, 0, -78)
    ..close();
  canvas.drawPath(hp, p..color = head);
  canvas.save();
  canvas.clipPath(hp);
  final cheek = shadeColor(head, -0.1).withValues(alpha: 0.45);
  oval(-34, -10, 10, 34, 0.1, cheek);
  oval(34, -10, 10, 34, -0.1, cheek);
  const white = Color(0xFFF6F1EA);
  switch (look.blaze) {
    case Blaze.none:
      break;
    case Blaze.star:
      canvas.drawPath(
          Path()
            ..moveTo(0, -60)
            ..lineTo(7, -50)
            ..lineTo(0, -40)
            ..lineTo(-7, -50)
            ..close(),
          p..color = white);
    case Blaze.stripe:
      canvas.drawPath(
          Path()
            ..moveTo(-6, -66)
            ..quadraticBezierTo(0, -70, 6, -66)
            ..lineTo(4, 22)
            ..quadraticBezierTo(0, 26, -4, 22)
            ..close(),
          p..color = white);
    case Blaze.wide:
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
  }
  if (coat.flecks != null) {
    final f = coat.flecks!.withValues(alpha: 0.5);
    for (var i = 0; i < 70; i++) {
      canvas.drawCircle(
          Offset(((i * 47) % 70) - 35.0, ((i * 31) % 130) - 72.0), 0.8, p..color = f);
    }
  }
  if (look.blaze == Blaze.wide) {
    oval(0, 46, 28, 18, 0, const Color(0xFFEED6CD));
    oval(-18, 35, 7, 5, 0.6, const Color(0xFF6F6A6D));
    oval(19, 34, 8, 5, -0.6, const Color(0xFF6F6A6D));
    oval(0, 57, 17, 5, 0, const Color(0xFF786464).withValues(alpha: 0.45));
  } else {
    oval(0, 46, 28, 18, 0,
        coat.isGrey ? const Color(0xFF8C8681) : shadeColor(head, -0.13));
  }
  canvas.restore();
  oval(-14, 40, 4, 6.5, 0.5, const Color(0xFF2E2628));
  oval(14, 40, 4, 6.5, -0.5, const Color(0xFF2E2628));
  canvas.drawPath(
      Path()
        ..moveTo(-10, 57)
        ..quadraticBezierTo(0, 60, 10, 57),
      Paint()
        ..color = const Color(0x80281E1E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round);

  // halster in de kleur van de deken
  final halter = blanket != null ? shadeColor(blanket, -0.05) : const Color(0xFF22325A);
  canvas.save();
  canvas.clipPath(hp);
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
  for (final side in const [-1.0, 1.0]) {
    canvas.save();
    canvas.translate(side * 31, -30);
    canvas.rotate(side * 0.2);
    final h = 9 * (1 - blink) + 1;
    final eyeRect = Rect.fromCenter(center: Offset.zero, width: 13, height: h / 1.5 * 2);
    canvas.drawOval(eyeRect, p..color = const Color(0xFF1C1412));
    // van voren zit het linkeroog van het paard rechts in beeld
    final blind = look.blindLeftEye && side > 0;
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
          ..color = shadeColor(head, -0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    canvas.restore();
  }

  // voorlok
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
      p..color = coat.mane);
}
