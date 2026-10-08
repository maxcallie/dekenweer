import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../logic/blanket_advisor.dart';
import '../models/horse.dart';
import '../models/weather.dart';
import 'farm_scene.dart';
import 'horse_front.dart';
import 'horse_painter.dart';

/// De stal van binnen: elk paard in een eigen box, met het hoofd over de
/// onderdeur. Door de ramen zie je het weer buiten.
class StableScene extends StatefulWidget {
  const StableScene({
    super.key,
    required this.weather,
    required this.horses,
    this.onHorseTap,
  });

  final SceneWeather weather;
  final List<SceneHorse> horses;
  final ValueChanged<Horse>? onHorseTap;

  @override
  State<StableScene> createState() => _StableSceneState();
}

class _StableSceneState extends State<StableScene> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);

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
          final cb = widget.onHorseTap;
          if (cb == null || widget.horses.isEmpty) return;
          final n = math.max(widget.horses.length, 2);
          final i = (d.localPosition.dx / (size.width / n)).floor();
          final y = d.localPosition.dy;
          if (i >= 0 && i < widget.horses.length && y > size.height * 0.33) {
            cb(widget.horses[i].horse);
          }
        },
        child: CustomPaint(
          size: size,
          painter: _StablePainter(
            clock: _clock,
            weather: widget.weather,
            horses: widget.horses,
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
  }) : super(repaint: clock);

  final ValueNotifier<double> clock;
  final SceneWeather weather;
  final List<SceneHorse> horses;
  final TextScaler textScaler;

  static final List<List<double>> _particles = () {
    final r = math.Random(17);
    return List.generate(40, (_) => [r.nextDouble(), r.nextDouble(), r.nextDouble()]);
  }();
  static final _labelCache = <String, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = clock.value;
    final w = size.width, h = size.height;
    final night = weather.isNight;
    final kind = weather.kind;
    final frontTop = h * 0.36, doorTop = h * 0.53;
    final n = math.max(horses.length, 2);
    final bw = w / n;
    final p = Paint()..isAntiAlias = true;
    canvas.clipRect(Offset.zero & size);

    // ---- achterwand en dak ---------------------------------------------------
    final wall = Offset.zero & size;
    canvas.drawRect(
        wall,
        Paint()
          ..shader = ui.Gradient.linear(wall.topCenter, wall.bottomCenter, [
            night ? const Color(0xFF2A1F18) : const Color(0xFF6B4B33),
            night ? const Color(0xFF1C1510) : const Color(0xFF4E3524),
          ]));
    final plank = Paint()
      ..color = (night ? Colors.black : const Color(0xFF28190F)).withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var y = 0.0; y < h; y += 14) {
      canvas.drawLine(Offset(0, y), Offset(w, y), plank);
    }
    final beam = night ? const Color(0xFF1A120C) : const Color(0xFF3A2819);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.035, w, 10), p..color = beam);
    for (var i = 0; i <= 3; i++) {
      canvas.drawRect(Rect.fromLTWH(i * w / 3 - 6, 0, 12, h * 0.3), p..color = beam);
    }

    // ---- ramen met het weer van buiten -------------------------------------
    final sky = switch (kind) {
      WeatherKind.clear || WeatherKind.partlyCloudy => night
          ? const [Color(0xFF0B1630), Color(0xFF243A66)]
          : kind == WeatherKind.clear
              ? const [Color(0xFF5FAEE6), Color(0xFFCDEBF7)]
              : const [Color(0xFF7DB8E0), Color(0xFFDCEEF5)],
      WeatherKind.cloudy => night
          ? const [Color(0xFF262C37), Color(0xFF353D4A)]
          : const [Color(0xFFAEB7BF), Color(0xFFC7CED4)],
      WeatherKind.fog => night
          ? const [Color(0xFF3A424E), Color(0xFF485160)]
          : const [Color(0xFFCBD1D6), Color(0xFFDDE1E4)],
      WeatherKind.drizzle => night
          ? const [Color(0xFF222831), Color(0xFF2E3540)]
          : const [Color(0xFF9AA4AE), Color(0xFFB3BCC4)],
      WeatherKind.rain => night
          ? const [Color(0xFF1C2129), Color(0xFF262C36)]
          : const [Color(0xFF7E8994), Color(0xFF98A2AC)],
      WeatherKind.storm => night
          ? const [Color(0xFF15191F), Color(0xFF1E232B)]
          : const [Color(0xFF4E5662), Color(0xFF636C78)],
      WeatherKind.snow => night
          ? const [Color(0xFF2E3644), Color(0xFF3C4554)]
          : const [Color(0xFFC3CBD3), Color(0xFFD6DCE1)],
    };
    final frame = night ? const Color(0xFF120C08) : const Color(0xFF2E1F14);
    final wet = kind == WeatherKind.rain ||
        kind == WeatherKind.drizzle ||
        kind == WeatherKind.storm;
    final windows = [
      for (var i = 0; i < 3; i++) Rect.fromLTWH(w * (0.08 + i * 0.32), h * 0.075, w * 0.2, h * 0.13),
    ];
    for (final r in windows) {
      canvas.drawRect(r.inflate(4), p..color = frame);
      canvas.drawRect(
          r, Paint()..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, sky));
      canvas.save();
      canvas.clipRect(r);
      if (wet) {
        final drop = Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..strokeWidth = 1;
        for (var k = 0; k < 18; k++) {
          final q = _particles[k];
          final y = r.top + (q[1] * r.height + t * 120 * (0.8 + q[2])) % r.height;
          final x = r.left + q[0] * r.width;
          canvas.drawLine(Offset(x, y), Offset(x - 2, y + 7), drop);
        }
      }
      if (kind == WeatherKind.snow) {
        for (var k = 0; k < 14; k++) {
          final q = _particles[k];
          final y = r.top + (q[1] * r.height + t * 18) % r.height;
          canvas.drawCircle(Offset(r.left + q[0] * r.width, y), 1.4,
              p..color = Colors.white.withValues(alpha: 0.9));
        }
      }
      if (night && (kind == WeatherKind.clear || kind == WeatherKind.partlyCloudy)) {
        for (var k = 0; k < 6; k++) {
          final q = _particles[k + 20];
          canvas.drawCircle(Offset(r.left + q[0] * r.width, r.top + q[1] * r.height), 0.9,
              p..color = Colors.white.withValues(alpha: 0.8));
        }
      }
      canvas.restore();
      final bar = Paint()
        ..color = frame
        ..strokeWidth = 3;
      canvas.drawLine(r.topCenter, r.bottomCenter, bar);
      canvas.drawLine(r.centerLeft, r.centerRight, bar);
    }
    // lichtbundels bij zon
    if (!night && (kind == WeatherKind.clear || kind == WeatherKind.partlyCloudy)) {
      for (final r in windows) {
        final beamPath = Path()
          ..moveTo(r.left, r.bottom)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.right + w * 0.12, h * 0.6)
          ..lineTo(r.left + w * 0.12, h * 0.6)
          ..close();
        canvas.drawPath(
            beamPath,
            Paint()
              ..shader = ui.Gradient.linear(Offset(0, r.bottom), Offset(0, h * 0.6), [
                const Color(0x38FFF5D7),
                const Color(0x00FFF5D7),
              ]));
      }
    }

    // ---- boxen ---------------------------------------------------------------
    for (var i = 0; i < n; i++) {
      final x0 = i * bw, cx = x0 + bw / 2;
      final sh = i < horses.length ? horses[i] : null;
      final look = sh == null ? null : HorseLook.of(sh.horse, sh.advice, sh.pick);

      // binnenkant van de box
      canvas.drawRect(Rect.fromLTWH(x0, frontTop, bw, h - frontTop),
          p..color = (night ? Colors.black : const Color(0xFF1E120A)).withValues(alpha: night ? 0.35 : 0.28));
      // hooinet
      final hay = Offset(x0 + bw * 0.16, frontTop + h * 0.075);
      canvas.drawOval(
          Rect.fromCenter(center: hay, width: bw * 0.16, height: h * 0.064),
          p..color = const Color(0xFFC9A24A));
      final net = Paint()
        ..color = const Color(0x993C2814)
        ..strokeWidth = 1;
      for (var k = -3; k <= 3; k++) {
        canvas.drawLine(hay + Offset(k * bw * 0.022, -h * 0.032),
            hay + Offset(k * bw * 0.015, h * 0.032), net);
      }
      // lamp 's nachts
      if (night) {
        final lamp = Offset(cx, frontTop - h * 0.06);
        canvas.drawCircle(
            lamp,
            bw * 0.7,
            Paint()
              ..shader = ui.Gradient.radial(lamp, bw * 0.7, [
                const Color(0x73FFC86E),
                const Color(0x00FFC86E),
              ]));
        canvas.drawLine(Offset(lamp.dx, 0), lamp - const Offset(0, 6),
            Paint()
              ..color = const Color(0xFF111111)
              ..strokeWidth = 1.5);
        canvas.drawPath(
            Path()
              ..moveTo(lamp.dx - 10, lamp.dy - 2)
              ..lineTo(lamp.dx + 10, lamp.dy - 2)
              ..lineTo(lamp.dx + 5, lamp.dy - 9)
              ..lineTo(lamp.dx - 5, lamp.dy - 9)
              ..close(),
            p..color = const Color(0xFF2B2B2B));
        canvas.drawCircle(lamp, 5, p..color = const Color(0xFFFFE2A8));
      }

      // paard: romp achter de spijlen, hoofd over de deur
      var hs = 0.0, hy = 0.0, blink = 0.0, ear = 0.0;
      if (look != null) {
        hs = math.min(bw * 0.46 / 80, (doorTop - frontTop) * 1.25 / 162);
        final bob = math.sin(t * 1.3 + i * 2) * 2;
        hy = doorTop + h * 0.012 - 62 * hs + bob;
        final cyc = (t + i * 1.7) % 5;
        blink = cyc > 4.75 ? math.sin((cyc - 4.75) / 0.25 * math.pi) : 0.0;
        ear = math.sin(t * 0.7 + i) * 0.08;
        canvas.save();
        canvas.translate(cx, hy - 72 * hs);
        canvas.scale(hs * 1.15);
        paintHorseFront(canvas, look, part: FrontPart.body);
        canvas.restore();
      }

      // spijlen met V-opening
      final vTop = bw * 0.30, vBot = bw * 0.09;
      final barPaint = Paint()..color = const Color(0xFFAEB4BA);
      final spacing = math.max(9.0, bw / 12);
      for (var x = x0 + spacing / 2; x < x0 + bw; x += spacing) {
        final dx = (x - cx).abs();
        if (dx < vBot) continue;
        if (dx < vTop) {
          final f = (dx - vBot) / (vTop - vBot);
          final yStop = doorTop - f * (doorTop - frontTop);
          canvas.drawRect(Rect.fromLTRB(x - 1.6, yStop, x + 1.6, doorTop), barPaint);
          continue;
        }
        canvas.drawRect(Rect.fromLTRB(x - 1.6, frontTop, x + 1.6, doorTop), barPaint);
      }
      final vPaint = Paint()
        ..color = const Color(0xFF9EA4AA)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - vBot, doorTop), Offset(cx - vTop, frontTop), vPaint);
      canvas.drawLine(Offset(cx + vBot, doorTop), Offset(cx + vTop, frontTop), vPaint);
      canvas.drawRect(Rect.fromLTWH(x0, frontTop - 4, bw, 7), p..color = const Color(0xFF9EA4AA));

      // onderdeur
      canvas.drawRect(Rect.fromLTWH(x0, doorTop, bw, h - doorTop),
          p..color = night ? const Color(0xFF1E1F23) : const Color(0xFF2C2D31));
      final seam = Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..strokeWidth = 1;
      for (var x = x0 + bw / 6; x < x0 + bw; x += bw / 6) {
        canvas.drawLine(Offset(x, doorTop), Offset(x, h), seam);
      }
      canvas.drawRect(Rect.fromLTWH(x0, doorTop - 3, bw, 8), p..color = const Color(0xFFA9AFB5));

      // hoofd steekt over de deur
      if (look != null) {
        canvas.save();
        canvas.translate(cx, hy);
        canvas.scale(hs);
        paintHorseFront(canvas, look, part: FrontPart.head, blink: blink, earTilt: ear);
        canvas.restore();
      }

      // naambordje
      if (sh != null) {
        final tp = _labelCache.putIfAbsent(
          '${sh.horse.name}|${textScaler.scale(13)}',
          () => TextPainter(
            text: TextSpan(
              text: sh.horse.name,
              style: const TextStyle(
                  color: Color(0xFF1F2A22), fontSize: 13, fontWeight: FontWeight.w700),
            ),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
          )..layout(),
        );
        final pw = tp.width + 26, ph = tp.height + 8;
        final plate = RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - pw / 2, doorTop + h * 0.03, pw, ph), const Radius.circular(6));
        canvas.drawRRect(plate, p..color = const Color(0xFFF6F1EA));
        final level = sh.advice?.level ?? BlanketLevel.none;
        canvas.drawCircle(Offset(plate.left + 10, plate.center.dy), 4, p..color = level.color);
        tp.paint(canvas, Offset(plate.left + 18, plate.top + 4));
      }

      // staander
      canvas.drawRect(Rect.fromLTWH(x0 - 4, frontTop - 6, 8, h), p..color = const Color(0xFF8E949A));
    }
    canvas.drawRect(Rect.fromLTWH(w - 4, frontTop - 6, 8, h), p..color = const Color(0xFF8E949A));
    if (night) {
      canvas.drawRect(Offset.zero & size, p..color = const Color(0x2E0A0F23));
    }
  }

  @override
  bool shouldRepaint(_StablePainter old) => true;
}
