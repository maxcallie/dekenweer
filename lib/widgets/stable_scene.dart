import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../logic/blanket_advisor.dart';
import '../models/horse.dart';
import '../models/weather.dart';
import 'farm_scene.dart';
import 'horse_front.dart';
import '../services/sound.dart';
import 'horse_painter.dart';

/// De stal van binnen: elk paard in een eigen box, met het hoofd over de
/// onderdeur. Door de ramen zie je het weer buiten.
class StableScene extends StatefulWidget {
  const StableScene({
    super.key,
    required this.weather,
    required this.horses,
    this.onHorseTap,
    this.onHorseLongPress,
    this.covered,
  });

  final SceneWeather weather;
  final List<SceneHorse> horses;
  /// Tik op een paard (het paard hinnikt al vanzelf).
  final ValueChanged<Horse>? onHorseTap;

  /// Lang drukken op een paard.
  final ValueChanged<Horse>? onHorseLongPress;

  /// Deel van de hoogte dat onderin door het paneel bedekt is.
  final ValueListenable<double>? covered;

  @override
  State<StableScene> createState() => _StableSceneState();
}

class _StableSceneState extends State<StableScene> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);

  /// Wanneer (kloktijd) elk paard begon te hinniken.
  final Map<String, double> _neighAt = {};

  /// Welke paarden hinnikten (de rest snoof).
  final Set<String> _whinnied = {};

  int? _boxAt(Offset pos, Size size) {
    if (widget.horses.isEmpty) return null;
    final n = math.max(widget.horses.length, 2);
    final i = (pos.dx / (size.width / n)).floor();
    final front = _StablePainter.frontTopFor(size, widget.covered?.value ?? 0.38);
    if (i >= 0 && i < widget.horses.length && pos.dy > front - size.height * 0.03) {
      return i;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) => _clock.value = e.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (d) {
          final i = _boxAt(d.localPosition, size);
          if (i == null) return;
          final horse = widget.horses[i].horse;
          _neighAt[horse.id] = _clock.value;
          if (HorseSounds.greet(horse)) {
            _whinnied.add(horse.id);
          } else {
            _whinnied.remove(horse.id);
          }
          widget.onHorseTap?.call(horse);
        },
        onLongPressStart: (d) {
          final i = _boxAt(d.localPosition, size);
          if (i != null) widget.onHorseLongPress?.call(widget.horses[i].horse);
        },
        child: CustomPaint(
          size: size,
          painter: _StablePainter(
            clock: _clock,
            weather: widget.weather,
            horses: widget.horses,
            neighAt: _neighAt,
            whinnied: _whinnied,
            covered: widget.covered,
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      );
    });
  }
}

class _StablePainter extends CustomPainter {
  _StablePainter({
    required this.clock,
    required this.weather,
    required this.horses,
    required this.textScaler,
    this.neighAt = const {},
    this.whinnied = const {},
    this.covered,
  }) : super(repaint: clock);

  final Map<String, double> neighAt;
  final Set<String> whinnied;

  /// Hoofd omhoog (0–1) voor een paard dat hinnikt.
  double _neigh(String id, double t) {
    final start = neighAt[id];
    if (start == null) return 0;
    final e = t - start;
    if (e < 0 || e > 1.7) return 0;
    final base = e < 0.25 ? e / 0.25 : e < 1.3 ? 1.0 : 1 - (e - 1.3) / 0.4;
    return base * (0.92 + 0.08 * math.sin(e * 70));
  }

  /// De onderdeur zakt mee met het paneel, zodat de naambordjes en hoofden
  /// in beeld blijven; de voorkant van de boxen schuift mee.
  /// Alles moet tussen de dagdelenbalk (± 36% van boven) en het paneel
  /// passen: hoofden boven de deur, daaronder naambord en deken.
  static double doorTopFor(Size size, double covered) =>
      (size.height * (1 - covered) - size.height * 0.125)
          .clamp(size.height * 0.50, size.height * 0.66);
  static double frontTopFor(Size size, double covered) =>
      doorTopFor(size, covered) - size.height * 0.10;

  final ValueListenable<double>? covered;

  final ValueNotifier<double> clock;
  final SceneWeather weather;
  final List<SceneHorse> horses;
  final TextScaler textScaler;

  static final List<List<double>> _particles = () {
    final r = math.Random(17);
    return List.generate(40, (_) => [r.nextDouble(), r.nextDouble(), r.nextDouble()]);
  }();
  static final _labelCache = <String, TextPainter>{};
  static TextPainter _bubble(String text) => TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
              color: Color(0xFF1F2A22), fontSize: 13, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
  static final _snortText = _bubble('Brrr!');
  static final _whinnyText = _bubble('Hihihihi!');

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = clock.value;
    final w = size.width, h = size.height;
    final night = weather.isNight;
    final kind = weather.kind;
    final open = kind == WeatherKind.clear || kind == WeatherKind.partlyCloudy;
    final cov = covered?.value ?? 0.38;
    final frontTop = frontTopFor(size, cov), doorTop = doorTopFor(size, cov);
    final n = math.max(horses.length, 2);
    final bw = w / n;
    final p = Paint()..isAntiAlias = true;
    canvas.clipRect(Offset.zero & size);

    // ---- warme houten achterwand -----------------------------------------
    final wall = Offset.zero & size;
    canvas.drawRect(
        wall,
        Paint()
          ..shader = ui.Gradient.linear(wall.topCenter, wall.bottomCenter, night
              ? const [Color(0xFF24170F), Color(0xFF160E09)]
              : const [Color(0xFF3A2618), Color(0xFF24170F)]));
    final plank = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var y = 0.0; y < h; y += 16) {
      canvas.drawLine(Offset(0, y), Offset(w, y), plank);
    }
    canvas.drawRect(Rect.fromLTWH(0, h * 0.035, w, 12), p..color = const Color(0xFF2A1A10));

    // ---- raam met het weer en het licht van buiten ---------------------------
    final winH = math.min(h * 0.13, 92.0);
    final win = Rect.fromCenter(
        center: Offset(w * 0.76, h * 0.245),
        width: math.min(w * 0.36, 140),
        height: math.min(winH, h * 0.085));
    canvas.drawRRect(
        RRect.fromRectAndRadius(win.inflate(6), const Radius.circular(6)),
        p..color = const Color(0xFF1A100A));
    final golden = weather.golden, morning = weather.morning && !night;
    List<Color> sky;
    if (open) {
      sky = night
          ? const [Color(0xFF141B38), Color(0xFF3B3F6A)]
          : golden
              ? const [Color(0xFFE9945C), Color(0xFFFBD9A0)]
              : morning
                  ? const [Color(0xFF9DC3E0), Color(0xFFF2D0A8)]
                  : const [Color(0xFF5FA9DF), Color(0xFFCDE8F4)];
    } else if (night) {
      sky = const [Color(0xFF1C2129), Color(0xFF323A46)];
    } else {
      sky = kind == WeatherKind.snow
          ? const [Color(0xFFC3CBD3), Color(0xFFE6EAEE)]
          : kind == WeatherKind.storm
              ? const [Color(0xFF4E5662), Color(0xFF747D89)]
              : const [Color(0xFF8D99A3), Color(0xFFC3C9CC)];
      if (golden || morning) {
        sky = [for (final c in sky) Color.lerp(c, const Color(0xFFE9A878), golden ? 0.3 : 0.18)!];
      }
    }
    canvas.save();
    canvas.clipRect(win);
    canvas.drawRect(win, Paint()..shader = ui.Gradient.linear(win.topCenter, win.bottomCenter, sky));
    if (open && night) {
      for (var k = 0; k < 10; k++) {
        final q = _particles[k + 20];
        canvas.drawCircle(Offset(win.left + q[0] * win.width, win.top + q[1] * win.height * 0.7), 0.8,
            p..color = Colors.white.withValues(alpha: 0.8));
      }
      canvas.drawCircle(Offset(win.right - win.width * 0.22, win.top + win.height * 0.28), 6,
          p..color = const Color(0xFFF4EFD8));
    } else if (open) {
      final low = golden || morning;
      final sunC = Offset(win.left + win.width * 0.68, win.top + win.height * (low ? 0.72 : 0.3));
      canvas.drawCircle(sunC, 18,
          Paint()
            ..shader = ui.Gradient.radial(sunC, 18, [const Color(0x99FFF4D2), const Color(0x00FFF4D2)]));
      canvas.drawCircle(sunC, 8, p..color = const Color(0xFFFFF0C8));
    }
    // heuvels in de verte
    final hillC = night
        ? const Color(0xFF1E2430)
        : kind == WeatherKind.snow
            ? const Color(0xFFDCE3E9)
            : golden
                ? const Color(0xFF8D6A55)
                : const Color(0xFF7E9A62);
    canvas.drawPath(
        Path()
          ..moveTo(win.left, win.bottom)
          ..lineTo(win.left, win.bottom - win.height * 0.18)
          ..quadraticBezierTo(win.center.dx, win.bottom - win.height * 0.34, win.right,
              win.bottom - win.height * 0.2)
          ..lineTo(win.right, win.bottom)
          ..close(),
        p..color = hillC);
    final wet = kind == WeatherKind.rain || kind == WeatherKind.drizzle || kind == WeatherKind.storm;
    if (wet) {
      final drop = Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      for (var k = 0; k < 22; k++) {
        final q = _particles[k];
        final y = win.top + (q[1] * win.height + t * 120 * (0.8 + q[2])) % win.height;
        final x = win.left + q[0] * win.width;
        canvas.drawLine(Offset(x, y), Offset(x - 2, y + 7), drop);
      }
    }
    if (kind == WeatherKind.snow) {
      for (var k = 0; k < 16; k++) {
        final q = _particles[k];
        final y = win.top + (q[1] * win.height + t * 18) % win.height;
        canvas.drawCircle(Offset(win.left + q[0] * win.width, y), 1.4,
            p..color = Colors.white.withValues(alpha: 0.9));
      }
    }
    canvas.restore();
    final bar = Paint()
      ..color = const Color(0xFF1A100A)
      ..strokeWidth = 4;
    canvas.drawLine(win.topCenter, win.bottomCenter, bar);
    canvas.drawLine(win.centerLeft, win.centerRight, bar);
    // hoefijzer boven het raam (geluk!)
    canvas.drawArc(
        Rect.fromCircle(center: Offset(win.center.dx, win.top - 16), radius: 7),
        math.pi * 0.2,
        -math.pi * 1.4,
        false,
        Paint()
          ..color = const Color(0xFFB8B8B0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    // lichtbundel van het raam
    if (open && !night) {
      canvas.drawPath(
          Path()
            ..moveTo(win.left, win.bottom)
            ..lineTo(win.right, win.bottom)
            ..lineTo(win.right + w * 0.14, doorTop + h * 0.15)
            ..lineTo(win.left - w * 0.06, doorTop + h * 0.15)
            ..close(),
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.linear(Offset(0, win.bottom), Offset(0, doorTop + h * 0.15), [
              (golden ? const Color(0xFFFFBE78) : const Color(0xFFFFF0D2)).withValues(alpha: 0.22),
              const Color(0x00FFBE78),
            ]));
    }

    // ---- boxen ---------------------------------------------------------------
    canvas.drawRect(Rect.fromLTWH(0, frontTop, w, h - frontTop),
        p..color = Colors.black.withValues(alpha: 0.35));
    final hs = math.min(bw * 0.46 / 80, (doorTop - frontTop) * 1.25 / 162);
    for (var i = 0; i < n; i++) {
      final x0 = i * bw, cx = x0 + bw / 2;
      final sh = i < horses.length ? horses[i] : null;
      // hooinet
      final hay = Offset(x0 + bw * 0.16, frontTop + h * 0.045);
      canvas.drawOval(Rect.fromCenter(center: hay, width: bw * 0.15, height: h * 0.05),
          p..color = const Color(0xFFD9B45A));
      final net = Paint()
        ..color = const Color(0x993C2814)
        ..strokeWidth = 1;
      for (var k = -3; k <= 3; k++) {
        canvas.drawLine(hay + Offset(k * bw * 0.02, -h * 0.025),
            hay + Offset(k * bw * 0.014, h * 0.025), net);
      }

      // paard: romp achter de spijlen (zonder deken: die hangt over de deur)
      var hy = 0.0, blink = 0.0, ear = 0.0;
      HorseLook? look;
      if (sh != null) {
        final full = HorseLook.of(sh.horse, sh.advice, sh.pick);
        look = HorseLook(
            coat: full.coat, blaze: full.blaze, legs: full.legs, blindLeftEye: full.blindLeftEye);
        final bob = math.sin(t * 1.3 + i * 2) * 2;
        hy = doorTop + h * 0.012 - 62 * hs + bob - 14 * hs * _neigh(sh.horse.id, t);
        final cyc = (t + i * 1.7) % 5;
        blink = cyc > 4.75 ? math.sin((cyc - 4.75) / 0.25 * math.pi) : 0.0;
        ear = math.sin(t * 0.7 + i) * 0.08;
        canvas.save();
        canvas.translate(cx, hy - 72 * hs);
        canvas.scale(hs * 1.15);
        paintHorseFront(canvas, look, part: FrontPart.body);
        canvas.restore();
      }

      // houten spijlen met V-opening
      final vTop = bw * 0.30, vBot = bw * 0.09;
      final slat = Paint()..color = const Color(0xFF5A3A22);
      final spacing = math.max(11.0, bw / 11);
      for (var x = x0 + spacing / 2; x < x0 + bw; x += spacing) {
        final dx = (x - cx).abs();
        if (dx < vBot) continue;
        if (dx < vTop) {
          final f = (dx - vBot) / (vTop - vBot);
          final yStop = doorTop - f * (doorTop - frontTop);
          canvas.drawRect(Rect.fromLTRB(x - 2, yStop, x + 2, doorTop), slat);
          continue;
        }
        canvas.drawRect(Rect.fromLTRB(x - 2, frontTop, x + 2, doorTop), slat);
      }
      canvas.drawRect(Rect.fromLTWH(x0, frontTop - 8, bw, 10), p..color = const Color(0xFF4A2E1A));

      // onderdeur van hout met schoor en messing grendel
      final door = Rect.fromLTRB(x0, doorTop, x0 + bw, h);
      canvas.drawRect(
          door,
          Paint()
            ..shader = ui.Gradient.linear(door.topCenter, door.bottomCenter,
                const [Color(0xFF7B5233), Color(0xFF4E321E)]));
      final brace = Paint()
        ..color = const Color(0xFF3A2414)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      final inner = Rect.fromLTRB(x0 + 8, doorTop + 10, x0 + bw - 8, h + 4);
      canvas.drawRect(inner, brace);
      canvas.drawLine(inner.topLeft, inner.bottomRight, brace);
      canvas.drawCircle(Offset(x0 + bw - 18, doorTop + h * 0.11), 4, p..color = const Color(0xFFC9A24A));
      canvas.drawRect(Rect.fromLTWH(x0, doorTop - 3, bw, 7), p..color = const Color(0xFF4A2E1A));

      // hoofd steekt over de deur
      if (look != null) {
        canvas.save();
        canvas.translate(cx, hy);
        canvas.scale(hs);
        paintHorseFront(canvas, look, part: FrontPart.head, blink: blink, earTilt: ear);
        canvas.restore();
      }

      if (sh != null) {
        // messing naambord
        final tp = _labelCache.putIfAbsent(
          '${sh.horse.name}|${textScaler.scale(13)}',
          () => TextPainter(
            text: TextSpan(
              text: sh.horse.name,
              style: const TextStyle(
                  color: Color(0xFF3A2414), fontSize: 13, fontWeight: FontWeight.w800),
            ),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          )..layout(),
        );
        final pw = tp.width + 26, ph = tp.height + 8;
        final plate = RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - pw / 2, doorTop + h * 0.03, pw, ph), const Radius.circular(5));
        canvas.drawRRect(plate, p..color = const Color(0xFFC9A24A));
        tp.paint(canvas, Offset(plate.left + 13, plate.top + 4));

        // de deken van het advies hangt over de deur (geen deken: niets)
        final level = sh.advice?.level ?? BlanketLevel.none;
        if (level.wearsBlanket) {
          final pick = sh.pick;
          final color = pick?.color ?? sh.horse.blanketColor;
          final label = pick != null
              ? '${pick.grams} g'
              : level == BlanketLevel.rainSheet
                  ? 'regen'
                  : level.grams;
          _drapedBlanket(canvas, Offset(cx, plate.outerRect.bottom + 12),
              math.min(bw * 0.62, 96), color, label);
        }

        // tekstballonnetje bij het hinniken
        final nv = _neigh(sh.horse.id, t);
        if (nv > 0.3) {
          final bp = whinnied.contains(sh.horse.id) ? _whinnyText : _snortText;
          final bw2 = bp.width + 18, bh = bp.height + 10;
          final top = hy - 112 * hs;
          final rect = Rect.fromLTWH(
              (cx - bw2 / 2).clamp(4.0, math.max(4.0, w - bw2 - 4)), top - bh, bw2, bh);
          final bubble = Paint()..color = Colors.white.withValues(alpha: 0.95);
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)), bubble);
          canvas.drawPath(
              Path()
                ..moveTo(cx - 5, rect.bottom - 1)
                ..lineTo(cx + 5, rect.bottom - 1)
                ..lineTo(cx, rect.bottom + 7)
                ..close(),
              bubble);
          bp.paint(canvas, Offset(rect.left + 9, rect.top + 5));
        }

        // emmer
        final bx = x0 + bw * 0.82, by = h - 4.0;
        if (bx < x0 + bw - 12) {
          canvas.drawPath(
              Path()
                ..moveTo(bx - 9, by - 14)
                ..lineTo(bx + 9, by - 14)
                ..lineTo(bx + 7, by)
                ..lineTo(bx - 7, by)
                ..close(),
              p..color = const Color(0xFF2F5E8A));
        }
      }

      // staander
      canvas.drawRect(Rect.fromLTWH(x0 - 4, frontTop - 10, 8, h), p..color = const Color(0xFF2E1C10));
    }
    canvas.drawRect(Rect.fromLTWH(w - 4, frontTop - 10, 8, h), p..color = const Color(0xFF2E1C10));

    // ---- lantaarns tussen de boxen ---------------------------------------------
    final lampY = frontTop + h * 0.02;
    for (var i = 1; i < n; i++) {
      final c = Offset(bw * i, lampY);
      final r = bw * 0.62;
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(c, r, [
              const Color(0xFFFFBE64).withValues(alpha: night ? 0.6 : 0.42),
              const Color(0x00FFAA50),
            ]));
      canvas.drawLine(Offset(c.dx, frontTop - 10), c - const Offset(0, 10),
          Paint()
            ..color = const Color(0xFF1A1410)
            ..strokeWidth = 1.5);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 14, height: 20), const Radius.circular(3)),
          p..color = const Color(0xFF1A1410));
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 8, height: 12), const Radius.circular(2)),
          p..color = const Color(0xFFFFD58A));
    }

    // hooi op de grond
    final straw = Paint()
      ..color = const Color(0x99DCB45A)
      ..strokeWidth = 1;
    for (var k = 0; k < 40; k++) {
      final q = _particles[k];
      final x = q[0] * w, y = h - q[1] * 24;
      canvas.drawLine(Offset(x, y), Offset(x + (q[2] - 0.5) * 14, y - q[2] * 4), straw);
    }

    // warm licht over alles
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.softLight
          ..color = (night ? const Color(0xFFFF963C) : const Color(0xFFFFAA50))
              .withValues(alpha: night ? 0.35 : 0.42));
  }

  /// Een deken die over de onderdeur hangt, met het gewicht erop.
  void _drapedBlanket(Canvas canvas, Offset top, double width, Color color, String label) {
    final hsl = HSLColor.fromColor(color);
    final dark = hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor();
    final light = hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor();
    final x = top.dx, y = top.dy, wd = width / 2;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(x - wd, y - 5, x + wd, y + 5), const Radius.circular(5)),
        Paint()..color = dark);
    final body = Path()
      ..moveTo(x - wd, y)
      ..lineTo(x + wd, y)
      ..lineTo(x + wd - 3, y + 34)
      ..quadraticBezierTo(x, y + 41, x - wd + 3, y + 34)
      ..close();
    canvas.drawPath(body, Paint()..color = color);
    final seam = Paint()
      ..color = light.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var k = 1; k < 5; k++) {
      final sx = x - wd + k * width / 5;
      canvas.drawLine(Offset(sx, y + 2), Offset(sx + 2, y + 33), seam);
    }
    canvas.drawPath(
        Path()
          ..moveTo(x - wd + 3, y + 34)
          ..quadraticBezierTo(x, y + 41, x + wd - 3, y + 34),
        Paint()
          ..color = light
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final tp = _labelCache.putIfAbsent(
      'deken|$label|${textScaler.scale(10)}',
      () => TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
              color: Color(0xFF3A2414), fontSize: 10, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout(),
    );
    final lw = tp.width + 12, lh = tp.height + 4;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y + 19), width: lw, height: lh),
            Radius.circular(lh / 2)),
        Paint()..color = const Color(0xF2FFFAEB));
    tp.paint(canvas, Offset(x - tp.width / 2, y + 19 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_StablePainter old) => true;
}
