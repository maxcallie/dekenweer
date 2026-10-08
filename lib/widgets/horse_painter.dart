import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../logic/blanket_advisor.dart';
import '../logic/blanket_picker.dart';
import '../models/horse.dart';

/// Hoe het paard eruitziet (vacht + deken).
class HorseLook {
  const HorseLook({
    required this.coat,
    this.blanketColor,
    this.level = BlanketLevel.none,
    this.neckCover = false,
    this.blaze = Blaze.none,
    this.legs = _noLegMarks,
  });

  static const _noLegMarks = [LegMark.none, LegMark.none, LegMark.none, LegMark.none];

  final CoatColor coat;
  final Color? blanketColor;
  final BlanketLevel level;
  final bool neckCover;
  final Blaze blaze;

  /// Linksvoor, rechtsvoor, linksachter, rechtsachter.
  final List<LegMark> legs;

  /// Als er een deken uit de dekenkast gekozen is ([pick]), dan draagt het
  /// paard die deken (kleur en halsstuk); anders de standaardkleur.
  factory HorseLook.of(Horse h, [BlanketAdvice? a, BlanketPick? pick]) =>
      HorseLook(
        coat: h.coat,
        blanketColor: pick?.color ?? h.blanketColor,
        level: a?.level ?? BlanketLevel.none,
        neckCover: pick?.neck ?? a?.neckCover ?? false,
        blaze: h.blaze,
        legs: h.legs,
      );
}

/// Houding van het paard op dit moment van de animatie.
class HorsePose {
  const HorsePose({
    this.graze = 0,
    this.walk = 0,
    this.walkPhase = 0,
    this.tailPhase = 0,
    this.earFlick = 0,
    this.leftSide = false,
    this.down = 0,
    this.fold,
    this.flip = 1,
    this.neigh = 0,
  });

  /// 0 = staan, 1 = liggen (romp op de grond).
  final double down;

  /// Hoe ver de benen gevouwen zijn (standaard gelijk aan [down]).
  final double? fold;

  /// Rollen: 1 = normaal, -1 = op de rug met de benen omhoog.
  final double flip;

  /// 0 = gewoon, 1 = hoofd omhoog om te hinniken.
  final double neigh;

  /// Zien we de linkerkant van het paard? Kijkt het paard op het scherm naar
  /// rechts, dan zie je zijn rechterkant; kijkt het naar links, dan zijn
  /// linkerkant. Bepaalt welke witte benen vooraan staan.
  final bool leftSide;

  /// 0 = hoofd omhoog, 1 = hoofd in het gras.
  final double graze;

  /// 0 = stilstaan, 1 = volledig lopen (amplitude beenbeweging).
  final double walk;
  final double walkPhase;
  final double tailPhase;
  final double earFlick;
}

Offset _lerpO(Offset a, Offset b, double t) => Offset.lerp(a, b, t)!;

/// Vaste posities voor de spikkels van een spanjaard (romp en hals).
final List<Offset> _roanSpeckles = () {
  final r = math.Random(5);
  return List.generate(
      140, (_) => Offset(-46 + r.nextDouble() * 86, -100 + r.nextDouble() * 68));
}();

/// Maakt een kleur lichter (positief) of donkerder (negatief).
Color shadeColor(Color c, double amount) => _shade(c, amount);

Color _shade(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor();
}

/// Tekent een paard in een lokaal assenstelsel: kijkt naar rechts, de
/// oorsprong ligt op de grond onder het midden van de romp. Het paard is
/// ongeveer 100 eenheden breed en 105 hoog.
void paintHorse(Canvas canvas, HorseLook look, HorsePose pose) {
  final coat = look.coat;
  final body = coat.body;
  final dark = _shade(body, -0.10);
  final fill = Paint()..isAntiAlias = true;

  // Schaduw
  canvas.drawOval(
    Rect.fromCenter(center: const Offset(0, 1), width: 92, height: 10),
    Paint()..color = Colors.black.withValues(alpha: 0.18),
  );

  // Liggen en rollen: de romp zakt naar de grond en kan (bij het rollen)
  // verticaal omklappen, zodat de benen omhoog wijzen.
  final down = pose.down.clamp(0.0, 1.0);
  final foldAmount = (pose.fold ?? down).clamp(0.0, 1.0);
  final nb = pose.neigh.clamp(0.0, 1.0);
  canvas.save();
  if (pose.flip < 1) {
    // niets onder de grond tekenen
    canvas.clipRect(const Rect.fromLTRB(-200, -300, 200, 4));
    canvas.translate(0, -17);
    canvas.scale(1, pose.flip);
    canvas.translate(0, 17);
  }
  canvas.translate(0, down * 30);

  final g = Curves.easeInOut.transform(pose.graze.clamp(0.0, 1.0));

  // ---- Benen -----------------------------------------------------------
  void leg(Offset top, double length, double phaseOffset, bool far, LegMark mark) {
    // gevouwen voorbenen gaan naar achteren, achterbenen naar voren
    final fold = foldAmount * (top.dx > 0 ? 1.35 : -1.25);
    final swing = math.sin(pose.walkPhase + phaseOffset) * 0.38 * pose.walk + fold;
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(swing);
    final path = Path()
      ..moveTo(-4.5, 0)
      ..lineTo(4.5, 0)
      ..lineTo(3.4, length - 5)
      ..lineTo(-3.0, length - 5)
      ..close();
    final upperBase = coat.head ?? body;
    final upper = far ? _shade(upperBase, -0.08) : upperBase;
    final lower = far ? _shade(coat.legs, -0.06) : coat.legs;
    canvas.drawPath(path, fill..color = upper);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-10, length * 0.5, 10, length));
    canvas.drawPath(path, fill..color = lower);
    canvas.restore();
    // Witte sok of kous
    if (mark != LegMark.none) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(
          -10, length * (mark == LegMark.sock ? 0.70 : 0.40), 10, length));
      canvas.drawPath(
          path, fill..color = far ? const Color(0xFFE4DED4) : const Color(0xFFF6F1EA));
      canvas.restore();
    }
    // Hoef (lichte, gestreepte hoef onder een wit been)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTRB(-3.6, length - 5.5, 4.4, length), const Radius.circular(1.5)),
      fill..color = mark != LegMark.none ? const Color(0xFFB89A78) : const Color(0xFF2B2420),
    );
    canvas.restore();
  }

  // Lift de benen iets bij het lopen zodat ze niet door de grond gaan.
  final lift = pose.walk * 1.5;
  final m = look.legs;
  final l = pose.leftSide;
  // Verre benen (achter de romp)
  leg(Offset(24, -42 - lift), 42, math.pi, true, l ? m[1] : m[0]);
  leg(Offset(-30, -44 - lift), 44, 0, true, l ? m[3] : m[2]);
  // Nabije benen
  leg(Offset(17, -42 - lift), 42, 0, false, l ? m[0] : m[1]);
  leg(Offset(-23, -44 - lift), 44, math.pi, false, l ? m[2] : m[3]);

  // ---- Staart ----------------------------------------------------------
  final swish = math.sin(pose.tailPhase) * 5;
  final tail = Path()
    ..moveTo(-42, -56)
    ..cubicTo(-52, -55, -52 + swish * 0.5, -42, -49 + swish, -20);
  canvas.drawPath(
    tail,
    Paint()
      ..color = coat.mane
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawPath(
    tail,
    Paint()
      ..color = _shade(coat.mane, 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round,
  );

  // ---- Romp ------------------------------------------------------------
  final bodyPath = Path()
    ..moveTo(-36, -60)
    ..cubicTo(-20, -66, 6, -62, 20, -64)
    ..cubicTo(32, -66, 40, -56, 36, -46)
    ..cubicTo(34, -38, 26, -35, 18, -36)
    ..cubicTo(4, -33, -14, -33, -26, -37)
    ..cubicTo(-38, -38, -46, -46, -44, -54)
    ..cubicTo(-43, -59, -40, -61, -36, -60)
    ..close();

  // ---- Hals + hoofd geometrie -------------------------------------------
  const withers = Offset(12, -62);
  const chest = Offset(38, -43);
  final poll = _lerpO(
      _lerpO(const Offset(52, -94), const Offset(60, -34), g), const Offset(48, -104), nb);
  final headAngle = ui.lerpDouble(0.75, 1.5, g)! - 0.55 * nb;
  final cosA = math.cos(headAngle), sinA = math.sin(headAngle);
  Offset head(double x, double y) =>
      Offset(poll.dx + x * cosA - y * sinA, poll.dy + x * sinA + y * cosA);

  final pollTop = head(-2, -6);
  final throat = head(2, 9);
  final ctrlTop = _lerpO(
      _lerpO(const Offset(30, -90), const Offset(46, -68), g), const Offset(28, -98), nb);
  final ctrlBottom = _lerpO(const Offset(50, -62), const Offset(50, -40), g);
  final neckPath = Path()
    ..moveTo(withers.dx, withers.dy)
    ..quadraticBezierTo(ctrlTop.dx, ctrlTop.dy, pollTop.dx, pollTop.dy)
    ..lineTo(throat.dx, throat.dy)
    ..quadraticBezierTo(ctrlBottom.dx, ctrlBottom.dy, chest.dx, chest.dy)
    ..lineTo(18, -48)
    ..close();

  canvas.drawPath(neckPath, fill..color = body);
  canvas.drawPath(bodyPath, fill..color = body);

  // Vachttekening
  canvas.save();
  canvas.clipPath(Path.combine(PathOperation.union, bodyPath, neckPath));
  // subtiele schaduw onderaan de romp
  canvas.drawRect(const Rect.fromLTRB(-50, -42, 50, -30),
      fill..color = dark.withValues(alpha: 0.35));
  switch (coat) {
    case CoatColor.pinto:
      fill.color = const Color(0xFFF6F2EA);
      canvas.drawOval(const Rect.fromLTWH(-30, -64, 26, 22), fill);
      canvas.drawOval(const Rect.fromLTWH(4, -54, 20, 18), fill);
      canvas.drawOval(Rect.fromCenter(center: head(-6, 10), width: 18, height: 26), fill);
    case CoatColor.grey:
      fill.color = Colors.white.withValues(alpha: 0.55);
      for (final o in const [
        Offset(-30, -52), Offset(-20, -46), Offset(-8, -55), Offset(4, -48),
        Offset(-34, -44), Offset(14, -56), Offset(-14, -58),
      ]) {
        canvas.drawCircle(o, 3.2, fill);
      }
    case CoatColor.appaloosa:
      fill.color = coat.mane.withValues(alpha: 0.85);
      for (final o in const [
        Offset(-34, -52), Offset(-26, -46), Offset(-20, -56), Offset(-12, -44),
        Offset(-6, -52), Offset(4, -58), Offset(10, -46), Offset(22, -54),
        Offset(-38, -46), Offset(-28, -58),
      ]) {
        canvas.drawCircle(o, 2.2, fill);
      }
    case CoatColor.dun:
      // aalstreep over de rug
      canvas.drawLine(const Offset(-36, -61), const Offset(16, -63),
          Paint()
            ..color = coat.mane.withValues(alpha: 0.6)
            ..strokeWidth = 2.2);
    default:
      break;
  }
  if (coat.flecks != null) {
    // Vliegenschimmel: fijne donkere spikkeltjes over romp en hals.
    final fleck = Paint()..color = coat.flecks!.withValues(alpha: 0.5);
    for (final o in _roanSpeckles) {
      canvas.drawCircle(o, 0.6, fleck);
    }
    for (final o in _roanSpeckles) {
      canvas.drawCircle(o + const Offset(3.1, 1.7), 0.45, fleck);
    }
  }
  if (coat.isRoan) {
    // Gespikkelde vacht: witte en donkere haartjes door elkaar.
    final light = Paint()..color = Colors.white.withValues(alpha: 0.45);
    final darkHair = Paint()..color = coat.head!.withValues(alpha: 0.55);
    for (var i = 0; i < _roanSpeckles.length; i++) {
      canvas.drawCircle(_roanSpeckles[i], 0.9, i.isEven ? light : darkHair);
    }
    // Hals loopt naar boven toe over in de donkere hoofdkleur.
    canvas.drawPath(
      neckPath,
      Paint()
        ..shader = ui.Gradient.linear(
          withers,
          pollTop,
          [coat.head!.withValues(alpha: 0), coat.head!.withValues(alpha: 0.85)],
        ),
    );
  }
  canvas.restore();

  // ---- Deken -----------------------------------------------------------
  final blanket = look.blanketColor;
  if (look.level.wearsBlanket && blanket != null) {
    final isSheet = look.level == BlanketLevel.rainSheet;
    final bColor = isSheet ? _shade(blanket, 0.12) : blanket;
    final trim = _shade(bColor, 0.22);
    // dikkere dekens hangen iets lager
    final bottom = -40.0 + look.level.index * 0.6;

    canvas.save();
    canvas.clipPath(bodyPath);
    canvas.drawRect(Rect.fromLTRB(-50, -80, 33, bottom), fill..color = bColor);
    // volume: lichte rand bovenop, donkere onderkant
    canvas.drawRect(Rect.fromLTRB(-50, bottom - 6, 33, bottom),
        fill..color = _shade(bColor, -0.08));
    canvas.drawLine(Offset(-50, bottom), Offset(33, bottom),
        Paint()
          ..color = trim
          ..strokeWidth = 2.4);
    // stiksels voor gevoerde dekens
    if (look.level.index >= BlanketLevel.medium.index) {
      final stitch = Paint()
        ..color = _shade(bColor, 0.10).withValues(alpha: 0.7)
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke;
      for (var x = -40.0; x < 30; x += 9) {
        canvas.drawLine(Offset(x, -66), Offset(x + 6, bottom - 2), stitch);
      }
    }
    // buiksingels
    final strap = Paint()
      ..color = _shade(bColor, -0.18)
      ..strokeWidth = 2.2;
    canvas.drawLine(Offset(-2, bottom - 1), const Offset(4, -32), strap);
    canvas.drawLine(Offset(6, bottom - 1), const Offset(12, -32), strap);
    // voorkant van de deken
    canvas.drawLine(const Offset(33, -70), Offset(33, bottom),
        Paint()
          ..color = trim
          ..strokeWidth = 2.4);
    canvas.restore();

    if (look.neckCover) {
      canvas.save();
      canvas.clipPath(neckPath);
      // het halsstuk stopt een stukje voor het hoofd
      final stop = _lerpO(withers, pollTop, 0.82);
      canvas.drawCircle(withers, (stop - withers).distance, fill..color = bColor);
      canvas.restore();
    }
  }

  // ---- Manen -----------------------------------------------------------
  final maneStart = look.level.wearsBlanket && look.neckCover
      ? _lerpO(withers, pollTop, 0.8)
      : withers;
  final mane = Path()..moveTo(maneStart.dx, maneStart.dy - 1);
  if (maneStart == withers) {
    mane.quadraticBezierTo(ctrlTop.dx - 2, ctrlTop.dy - 3, pollTop.dx, pollTop.dy - 1);
  } else {
    mane.lineTo(pollTop.dx, pollTop.dy - 1);
  }
  canvas.drawPath(
    mane,
    Paint()
      ..color = coat.mane
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round,
  );

  // ---- Hoofd -----------------------------------------------------------
  canvas.save();
  canvas.translate(poll.dx, poll.dy);
  canvas.rotate(headAngle);
  // oor
  final ear = Path()
    ..moveTo(-1, -5)
    ..lineTo(-8 - pose.earFlick * 3, -14)
    ..lineTo(4, -6)
    ..close();
  final headColor = coat.head ?? body;
  canvas.drawPath(ear, fill..color = _shade(headColor, -0.04));
  final headPath = Path()
    ..moveTo(-3, -7)
    ..quadraticBezierTo(14, -9, 27, -5)
    ..quadraticBezierTo(33, -3, 32, 3)
    ..quadraticBezierTo(31, 8, 25, 8)
    ..quadraticBezierTo(12, 9, 4, 10)
    ..quadraticBezierTo(-5, 10, -5, 2)
    ..close();
  canvas.drawPath(headPath, fill..color = headColor);
  // bles / kol
  const white = Color(0xFFF6F1EA);
  switch (look.blaze) {
    case Blaze.none:
      break;
    case Blaze.star:
      canvas.drawPath(
          Path()
            ..moveTo(5, -8)
            ..lineTo(8, -5.5)
            ..lineTo(5, -3)
            ..lineTo(2, -5.5)
            ..close(),
          fill..color = white);
    case Blaze.stripe:
      canvas.drawPath(
          Path()
            ..moveTo(9, -7)
            ..quadraticBezierTo(20, -7, 29, -3)
            ..lineTo(28, 0)
            ..quadraticBezierTo(20, -3, 10, -4)
            ..close(),
          fill..color = white);
    case Blaze.wide:
      canvas.drawPath(
          Path()
            ..moveTo(4, -8)
            ..quadraticBezierTo(18, -10, 28, -5.5)
            ..quadraticBezierTo(33, -3, 33, 2)
            ..lineTo(30, 3)
            ..quadraticBezierTo(19, -1, 5, -2.5)
            ..close(),
          fill..color = white);
  }
  // spikkels op het hoofd (vliegenschimmel)
  if (coat.flecks != null) {
    final fleck = Paint()..color = coat.flecks!.withValues(alpha: 0.5);
    for (final o in const [
      Offset(3, -3), Offset(6, 4), Offset(12, -5), Offset(14, 3), Offset(18, -2),
      Offset(21, 5), Offset(10, 7), Offset(1, 6), Offset(16, -6), Offset(24, -3),
      Offset(5, -6), Offset(8, 1), Offset(11, 0), Offset(19, 2), Offset(23, 1),
      Offset(-2, 2), Offset(14, 7), Offset(7, -4), Offset(20, -5), Offset(17, 6),
    ]) {
      canvas.drawCircle(o, 0.55, fleck);
    }
  }
  // snoet (schimmels hebben een donkere huid rond de neus; een brede bles
  // loopt door over de neus: roze huid met grijze vlekjes)
  canvas.drawOval(
      const Rect.fromLTRB(24, -4, 33, 8),
      fill
        ..color = look.blaze == Blaze.wide
            ? const Color(0xFFEBD3CA)
            : coat.isGrey
                ? const Color(0xFF8C8681)
                : _shade(headColor, -0.12));
  if (look.blaze == Blaze.wide) {
    canvas.drawOval(const Rect.fromLTRB(26.5, -1.5, 31, 2.8),
        fill..color = const Color(0xFF7A7476));
  }
  // neusgat & oog
  canvas.drawCircle(const Offset(28.5, 0.5), 1.1,
      fill..color = const Color(0xFF1A1412));
  canvas.drawCircle(const Offset(8, -2), 1.8, fill..color = const Color(0xFF1A1412));
  canvas.drawCircle(const Offset(8.6, -2.6), 0.6, fill..color = Colors.white);
  // voorlok
  canvas.drawPath(
    Path()
      ..moveTo(-2, -6)
      ..quadraticBezierTo(4, -9, 7, -5),
    Paint()
      ..color = coat.mane
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round,
  );
  canvas.restore();
  canvas.restore(); // liggen/rollen
}

/// Statische weergave van één paard, bijv. als avatar in een lijst.
class HorseAvatar extends StatelessWidget {
  const HorseAvatar({
    super.key,
    required this.look,
    this.size = 64,
    this.graze = 0,
    this.leftSide = false,
  });

  final HorseLook look;
  final double size;
  final double graze;

  /// Toon de linkerkant (paard kijkt naar links).
  final bool leftSide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AvatarPainter(look, graze, leftSide)),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.look, this.graze, this.leftSide);
  final HorseLook look;
  final double graze;
  final bool leftSide;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 112;
    canvas.save();
    if (leftSide) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.translate(size.width / 2 - 10 * s, size.height * 0.5 + 52 * s);
    canvas.scale(s);
    paintHorse(canvas, look, HorsePose(graze: graze, leftSide: leftSide));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AvatarPainter old) =>
      old.look.coat != look.coat ||
      old.look.blaze != look.blaze ||
      !listEquals(old.look.legs, look.legs) ||
      old.look.level != look.level ||
      old.look.blanketColor != look.blanketColor ||
      old.look.neckCover != look.neckCover ||
      old.graze != graze ||
      old.leftSide != leftSide;
}
