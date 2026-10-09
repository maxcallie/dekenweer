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
    this.blindLeftEye = false,
  });

  static const _noLegMarks = [LegMark.none, LegMark.none, LegMark.none, LegMark.none];

  final CoatColor coat;
  final Color? blanketColor;
  final BlanketLevel level;
  final bool neckCover;
  final Blaze blaze;

  /// Linksvoor, rechtsvoor, linksachter, rechtsachter.
  final List<LegMark> legs;

  /// Licht melkachtig linkeroog (Nero).
  final bool blindLeftEye;

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
        blindLeftEye: h.blindLeftEye,
      );
}

/// Zachte blauwgrijze waas over een oog (blind, maar vriendelijk): het oog
/// blijft donker met glans, alleen het midden is wat melkachtig.
void paintEyeHaze(Canvas canvas, Rect eye, Offset center, double radius,
    {double strength = 0.55}) {
  canvas.save();
  canvas.clipPath(Path()..addOval(eye));
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = ui.Gradient.radial(center, radius, [
        Color.fromRGBO(200, 214, 226, strength),
        const Color.fromRGBO(200, 214, 226, 0),
      ]),
  );
  canvas.restore();
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
    // dijtje bovenaan, een zacht bultje voor knie of hak, slanke pijp
    final hind = top.dx < 0;
    final k = length * 0.52, b = length - 5;
    final path = Path()
      ..moveTo(-5.2, 0)
      ..lineTo(5.2, 0)
      ..quadraticBezierTo(5.0, k * 0.6, hind ? 3.9 : 3.6, k)
      ..quadraticBezierTo(hind ? 4.6 : 4.3, k + 3, 3.3, k + 6)
      ..lineTo(3.4, b)
      ..lineTo(-2.9, b)
      ..lineTo(-3.0, k + 6)
      ..quadraticBezierTo(-4.0, k + 3, -3.4, k)
      ..quadraticBezierTo(-4.8, k * 0.6, -5.2, 0)
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
    // Hoef: rond naar voren, met een glimrandje (licht onder een wit been)
    canvas.drawPath(
      Path()
        ..moveTo(-3.2, length - 5.5)
        ..lineTo(3.6, length - 5.5)
        ..quadraticBezierTo(5.6, length - 1, 5.2, length)
        ..lineTo(-3.8, length)
        ..quadraticBezierTo(-4.2, length - 3, -3.2, length - 5.5)
        ..close(),
      fill..color = mark != LegMark.none ? const Color(0xFFB89A78) : const Color(0xFF2B2420),
    );
    canvas.drawRect(Rect.fromLTWH(-3, length - 5.5, 6.4, 1.4),
        fill..color = Colors.white.withValues(alpha: 0.18));
    canvas.restore();
  }

  // Lift de benen iets bij het lopen zodat ze niet door de grond gaan.
  final lift = pose.walk * 1.5;
  final m = look.legs;
  final l = pose.leftSide;
  // Verre benen (achter de romp)
  leg(Offset(24, -42 - lift), 42, math.pi, true, l ? m[1] : m[0]);
  leg(Offset(-30, -44 - lift), 44, 0, true, l ? m[3] : m[2]);

  // ---- Staart ----------------------------------------------------------
  final swish = math.sin(pose.tailPhase) * 5;
  const strandWidths = [7.0, 5.0, 4.0, 3.0];
  for (var k = 0; k < 4; k++) {
    canvas.drawPath(
      Path()
        ..moveTo(-42, -57)
        ..cubicTo(-53, -56.0 - k, -53 + swish * 0.5 - k, -42, -48 + swish - k * 1.6, -22 + k * 2.5),
      Paint()
        ..color = k.isOdd ? _shade(coat.mane, 0.10) : coat.mane
        ..style = PaintingStyle.stroke
        ..strokeWidth = strandWidths[k]
        ..strokeCap = StrokeCap.round,
    );
  }
  canvas.save();
  canvas.translate(-48 + swish, -21);
  canvas.rotate(0.3);
  canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 8.4, height: 6), fill..color = coat.mane);
  canvas.restore();

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
  // zacht licht op bil en schouder, wat schaduw bij de borst
  final glow = _shade(body, 0.10);
  for (final (c, r) in const [(Offset(-30, -56), 15.0), (Offset(22, -57), 11.0)]) {
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
              c, r, [glow.withValues(alpha: 0.45), glow.withValues(alpha: 0)]));
  }
  canvas.drawCircle(
      const Offset(42, -44),
      12,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(42, -44), 12,
            [dark.withValues(alpha: 0.3), dark.withValues(alpha: 0)]));
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

  // Nabije benen (voor de romp langs)
  leg(Offset(17, -42 - lift), 42, 0, false, l ? m[0] : m[1]);
  leg(Offset(-23, -44 - lift), 44, math.pi, false, l ? m[2] : m[3]);

  // ---- Deken -----------------------------------------------------------
  final blanket = look.blanketColor;
  if (look.level.wearsBlanket && blanket != null) {
    final isSheet = look.level == BlanketLevel.rainSheet;
    final bColor = isSheet ? _shade(blanket, 0.12) : blanket;
    final trim = _shade(bColor, 0.22);
    // dikkere dekens hangen iets lager
    final bottom = -40.0 + look.level.index * 0.6;

    final edge = _shade(bColor, -0.16);
    final blanketPath = Path()
      ..moveTo(28, -63)
      ..cubicTo(10, -64, -10, -62, -26, -63)
      // staartflap over de bil
      ..cubicTo(-40, -64, -49, -58, -48, -50)
      ..quadraticBezierTo(-48, bottom - 1, -42, bottom + 1)
      ..quadraticBezierTo(-5, bottom + 4, 30, bottom + 1)
      ..quadraticBezierTo(38, bottom - 2, 38, -50)
      ..quadraticBezierTo(37, -60, 28, -63)
      ..close();
    canvas.drawPath(blanketPath, fill..color = bColor);
    canvas.save();
    canvas.clipPath(blanketPath);
    // volume: lichte rand bovenop, donkerder aan de onderkant
    canvas.drawRect(Rect.fromLTRB(-60, -70, 50, -63), fill..color = Colors.white.withValues(alpha: 0.12));
    canvas.drawRect(Rect.fromLTRB(-60, bottom - 5, 50, bottom + 5),
        fill..color = Colors.black.withValues(alpha: 0.14));
    // stiksels voor gevoerde dekens
    if (look.level.index >= BlanketLevel.medium.index) {
      final stitch = Paint()
        ..color = _shade(bColor, 0.10).withValues(alpha: 0.7)
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke;
      for (var x = -48.0; x < 36; x += 8) {
        canvas.drawLine(Offset(x, -68), Offset(x + 6, bottom + 3), stitch);
      }
    }
    canvas.restore();
    // sierrand rondom
    canvas.drawPath(
        blanketPath,
        Paint()
          ..color = trim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // gekruiste buiksingels
    final strap = Paint()
      ..color = edge
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-6, bottom + 2), const Offset(6, -31), strap);
    canvas.drawLine(Offset(6, bottom + 2), const Offset(-4, -31), strap);
    // staartkoord
    canvas.drawPath(
        Path()
          ..moveTo(-47, -52)
          ..quadraticBezierTo(-52, -40, -42, bottom + 1),
        Paint()
          ..color = edge
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1);
    // sluiting op de borst
    canvas.drawCircle(const Offset(33, -50), 1.6, fill..color = trim);

    if (look.neckCover) {
      canvas.save();
      canvas.clipPath(neckPath);
      // het halsstuk stopt een stukje voor het hoofd
      final stop = _lerpO(withers, pollTop, 0.82);
      final reach = (stop - withers).distance;
      canvas.drawCircle(withers, reach, fill..color = bColor);
      canvas.drawCircle(
          withers,
          reach - 1,
          Paint()
            ..color = trim
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.restore();
    }
  }

  // ---- Manen -----------------------------------------------------------
  final maneStart = look.level.wearsBlanket && look.neckCover
      ? _lerpO(withers, pollTop, 0.8)
      : withers;
  final covered = maneStart != withers;
  final mc = covered ? maneStart : Offset(ctrlTop.dx - 2, ctrlTop.dy - 3);
  Offset maneAt(double t) {
    final u = 1 - t;
    return Offset(u * u * maneStart.dx + 2 * u * t * mc.dx + t * t * pollTop.dx,
        u * u * maneStart.dy + 2 * u * t * mc.dy + t * t * pollTop.dy);
  }

  canvas.drawPath(
    Path()
      ..moveTo(maneStart.dx, maneStart.dy - 1)
      ..quadraticBezierTo(mc.dx, mc.dy, pollTop.dx, pollTop.dy - 1),
    Paint()
      ..color = coat.mane
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round,
  );
  // golfjes aan de halskant
  final maneFill = Paint()..color = coat.mane;
  for (var k = 1; k < 9; k++) {
    final p = maneAt(k / 9), q = maneAt(math.min(1.0, k / 9 + 0.02));
    final d = q - p;
    final n = d.distance == 0 ? 1.0 : d.distance;
    canvas.drawCircle(Offset(p.dx + d.dy / n * 2.6, p.dy - d.dx / n * 2.6), 2.4, maneFill);
  }
  final m1 = maneAt(0.1), m2 = maneAt(0.85);
  canvas.drawPath(
      Path()
        ..moveTo(m1.dx, m1.dy)
        ..quadraticBezierTo(mc.dx, mc.dy - 1.5, m2.dx, m2.dy),
      Paint()
        ..color = _shade(coat.mane, 0.14).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1);

  // ---- Hoofd -----------------------------------------------------------
  canvas.save();
  canvas.translate(poll.dx, poll.dy);
  canvas.rotate(headAngle);
  final headColor = coat.head ?? body;
  // verre oor (iets donkerder, erachter)
  canvas.drawPath(
      Path()
        ..moveTo(2, -6)
        ..quadraticBezierTo(-1, -15, 1, -17)
        ..quadraticBezierTo(6, -12, 7, -6)
        ..close(),
      fill..color = _shade(headColor, -0.14));
  // nabije oor met binnenkant
  final flick = pose.earFlick * 3;
  canvas.drawPath(
      Path()
        ..moveTo(-2, -5)
        ..quadraticBezierTo(-7 - flick, -12, -8 - flick, -16)
        ..quadraticBezierTo(-1, -14, 4, -6)
        ..close(),
      fill..color = _shade(headColor, -0.04));
  canvas.drawPath(
      Path()
        ..moveTo(-1.5, -6.5)
        ..quadraticBezierTo(-5 - flick, -11, -6 - flick, -13.5)
        ..quadraticBezierTo(-1.5, -11, 1.5, -7)
        ..close(),
      fill..color = _shade(headColor, -0.18).withValues(alpha: 0.6));
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
  // neusgat en mondje
  final faceLine = Paint()
    ..color = const Color(0xFF1A1412)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  canvas.drawArc(Rect.fromCircle(center: const Offset(28.8, 0.6), radius: 1.5), 0.4,
      -(2 * math.pi - 2.6), false, faceLine..strokeWidth = 1.2);
  canvas.drawPath(
      Path()
        ..moveTo(24.5, 6.2)
        ..quadraticBezierTo(27.5, 7.6, 30.5, 6.4),
      faceLine..strokeWidth = 1);
  // oog
  canvas.drawCircle(const Offset(8, -2), 1.8, fill..color = const Color(0xFF1A1412));
  if (look.blindLeftEye && pose.leftSide) {
    // we zien de linkerkant: het blinde oog
    paintEyeHaze(canvas, Rect.fromCircle(center: const Offset(8, -2), radius: 1.8),
        const Offset(8.1, -1.9), 1.6);
    canvas.drawCircle(const Offset(8.6, -2.6), 0.55,
        fill..color = Colors.white.withValues(alpha: 0.9));
  } else {
    canvas.drawCircle(const Offset(8.6, -2.6), 0.6, fill..color = Colors.white);
  }
  // voorlok
  canvas.drawPath(
    Path()
      ..moveTo(-3, -6)
      ..quadraticBezierTo(4, -11, 9, -5)
      ..quadraticBezierTo(5, -6, 4, -3)
      ..quadraticBezierTo(1, -6, -3, -6)
      ..close(),
    fill..color = coat.mane,
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
      old.look.blindLeftEye != look.blindLeftEye ||
      old.graze != graze ||
      old.leftSide != leftSide;
}
