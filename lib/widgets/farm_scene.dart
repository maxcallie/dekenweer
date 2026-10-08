import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../logic/blanket_advisor.dart';
import '../logic/blanket_picker.dart';
import '../models/horse.dart';
import '../models/weather.dart';
import '../services/sound.dart';
import 'horse_painter.dart';

/// Welk weer de scène laat zien.
class SceneWeather {
  const SceneWeather({
    required this.kind,
    required this.isNight,
    required this.wind,
    required this.temp,
    this.morning = false,
  });

  final WeatherKind kind;
  final bool isNight;

  /// Ochtendlicht: warme lucht en een lage zon.
  final bool morning;

  /// 0 = windstil, 1 = storm.
  final double wind;
  final double temp;

  bool get frost => temp <= 0 && kind != WeatherKind.snow;

  @override
  bool operator ==(Object other) =>
      other is SceneWeather &&
      other.kind == kind &&
      other.isNight == isNight &&
      other.wind == wind &&
      other.temp == temp &&
      other.morning == morning;

  @override
  int get hashCode => Object.hash(kind, isNight, wind, temp, morning);
}

/// Een paard dat getekend wordt, met het advies dat bij het gekozen moment hoort.
class SceneHorse {
  const SceneHorse(this.horse, this.advice, [this.pick]);
  final Horse horse;
  final BlanketAdvice? advice;
  final BlanketPick? pick;
}

/// Layout-verhoudingen van de scène (als fractie van de hoogte).
class SceneLayout {
  /// [covered] is het deel van de hoogte (0–1) dat onderin door het
  /// adviespaneel wordt bedekt. De paarden blijven in het zichtbare deel.
  SceneLayout(this.size, [double covered = 0.38])
      : pastureBottom = (size.height * (1 - covered) - size.height * 0.05)
            .clamp(size.height * 0.545, size.height * 0.86);
  final Size size;

  double get w => size.width;
  double get h => size.height;
  double get horizon => h * 0.37;
  double get pastureTop => h * 0.445;
  final double pastureBottom;

  /// Schaal van een paard op diepte [d] (0 = achteraan, 1 = vooraan).
  /// Hoe dieper de zichtbare wei, hoe groter de paarden vooraan.
  double horseScale(double d) {
    final base = math.min(w, h * 0.62) / 100;
    final spread =
        ((pastureBottom - pastureTop) / (h * 0.155)).clamp(0.8, 1.7);
    return base * ui.lerpDouble(0.19, 0.19 + 0.11 * spread, d)!;
  }

  Offset horsePos(double x, double d) => Offset(
        ui.lerpDouble(w * 0.06, w * 0.94, x)!,
        ui.lerpDouble(pastureTop, pastureBottom, d)!,
      );
}

enum _Activity { graze, walk, stand, roll, play, groom }

double _ease(double t) => Curves.easeInOut.transform(t.clamp(0.0, 1.0));

/// Simulatie van één paard in de wei.
class _HorseAgent {
  _HorseAgent(this.id, math.Random r)
      : x = 0.1 + r.nextDouble() * 0.8,
        d = r.nextDouble(),
        facingRight = r.nextBool(),
        tailPhase = r.nextDouble() * 6,
        timer = 1 + r.nextDouble() * 4,
        graze = 1;

  final String id;
  double x, d;
  double tx = 0.5, td = 0.5;
  bool facingRight;
  _Activity activity = _Activity.graze;
  double timer;
  double graze;
  double walk = 0;
  double walkPhase = 0;
  double tailPhase;
  double earFlick = 0;

  // Tempo van lopen: rustig stappen of (bij spelen) draven.
  double speed = 0.045;
  double gait = 6.5;

  // Rollen
  static const rollDuration = 6.2;
  double rollT = 0;
  double down = 0, fold = 0, flip = 1, shake = 0;

  // Hinniken (seconden sinds het begon; < 0 = niet aan het hinniken)
  static const neighDuration = 1.7;
  double neighT = -1;

  /// Hinnikte het paard (true) of snoof het (false)?
  bool whinnied = false;

  // Samen spelen of elkaar poetsen
  _HorseAgent? partner;
  bool leader = false;
  bool groomReady = false;
  double nibblePhase = 0;

  bool get idle =>
      (activity == _Activity.graze || activity == _Activity.stand) && neighT < 0;
  bool get rolling => activity == _Activity.roll;
  bool get grooming => activity == _Activity.groom && groomReady;
  bool get dusty => rolling && rollT > 1.3 && rollT < 4.1 || shake > 0;

  /// Hoofd omhoog (0–1) tijdens het hinniken, met een trilling erin.
  double get neigh {
    if (neighT < 0) return 0;
    final t = neighT;
    final base = t < 0.25
        ? _ease(t / 0.25)
        : t < 1.3
            ? 1.0
            : 1 - _ease((t - 1.3) / 0.4);
    return base * (0.94 + 0.06 * math.sin(t * 70));
  }

  /// Kopje omhoog en even blijven staan.
  void startNeigh() {
    if (rolling) return;
    endSocial();
    neighT = 0;
    activity = _Activity.stand;
    timer = neighDuration + 0.5;
  }

  void startRoll() {
    activity = _Activity.roll;
    rollT = 0;
  }

  void endSocial() {
    final p = partner;
    partner = null;
    groomReady = false;
    if (p != null && p.partner == this) {
      p.partner = null;
      p.groomReady = false;
      p._toGraze();
    }
  }

  void _toGraze() {
    activity = _Activity.graze;
    speed = 0.045;
    gait = 6.5;
    timer = 4 + math.Random().nextDouble() * 8;
  }

  void update(double dt, math.Random r) {
    timer -= dt;
    if (neighT >= 0) {
      neighT += dt;
      if (neighT > neighDuration) neighT = -1;
    }
    var targetGraze = 0.0;
    var moving = false;
    switch (activity) {
      case _Activity.graze:
      case _Activity.stand:
        targetGraze = activity == _Activity.graze ? 1.0 : 0.0;
        if (timer <= 0 && neighT < 0) {
          final roll = r.nextDouble();
          if (activity == _Activity.graze && roll < 0.06) {
            startRoll();
          } else if (activity == _Activity.graze && roll < 0.30) {
            activity = _Activity.stand;
            timer = 2 + r.nextDouble() * 3;
          } else {
            activity = _Activity.walk;
            tx = (x + (r.nextDouble() - 0.5) * 0.6).clamp(0.05, 0.95);
            td = (d + (r.nextDouble() - 0.5) * 0.7).clamp(0.0, 1.0);
            timer = 12;
          }
        }
      case _Activity.walk:
        moving = true;
        if (_arrived() || timer <= 0) _toGraze();
      case _Activity.roll:
        _updateRoll(dt);
      case _Activity.play:
        moving = true;
        final p = partner;
        if (p == null || timer <= 0) {
          endSocial();
          _toGraze();
        } else if (leader) {
          if (_arrived()) _pickPlayTarget(r);
        } else {
          // achter de ander aan
          tx = (p.x - (p.facingRight ? 0.09 : -0.09)).clamp(0.03, 0.97);
          td = p.d;
        }
      case _Activity.groom:
        final p = partner;
        if (p == null || timer <= 0) {
          endSocial();
          _toGraze();
        } else if (!groomReady) {
          if (leader) {
            // wacht tot de ander er is, met het hoofd omhoog
            groomReady = p.groomReady;
          } else if (_arrived()) {
            groomReady = true;
            facingRight = p.x > x;
            p.facingRight = !facingRight;
          } else {
            moving = true;
          }
        } else {
          nibblePhase += dt * 5;
          targetGraze = 0.42 + 0.07 * math.sin(nibblePhase);
        }
        if (!groomReady && leader) targetGraze = 0;
    }

    if (moving) {
      final dx = tx - x, dd = (td - d) * 0.35;
      final dist = math.sqrt(dx * dx + dd * dd);
      if (dist > 0.004 && graze < 0.25) {
        final step = math.min(dist, speed * dt);
        x += dx / dist * step;
        d += (td - d) / dist * step;
        if (dx.abs() > 0.004) facingRight = dx > 0;
      }
    }

    if (!rolling) {
      graze += (targetGraze - graze) * math.min(1.0, dt * 2.2);
    }
    final targetWalk = (moving && graze < 0.25) || (rolling && flip < 0) ? 1.0 : 0.0;
    walk += (targetWalk - walk) * math.min(1.0, dt * 5);
    walkPhase += dt * (rolling ? 9 : gait) * walk;
    tailPhase += dt * (1.4 + r.nextDouble() * 0.4);
    earFlick = math.max(0.0, earFlick - dt * 3);
    if (r.nextDouble() < dt * 0.15) earFlick = 1;
  }

  bool _arrived() {
    final dx = tx - x, dd = (td - d) * 0.35;
    return math.sqrt(dx * dx + dd * dd) < 0.01;
  }

  void _pickPlayTarget(math.Random r) {
    // een flink stuk verderop, liefst de andere kant op
    final dir = x < 0.5 ? 1 : -1;
    tx = (x + dir * (0.3 + r.nextDouble() * 0.4)).clamp(0.06, 0.94);
    td = r.nextDouble();
  }

  /// Gaan liggen, op de rug rollen, opstaan en uitschudden.
  void _updateRoll(double dt) {
    rollT += dt;
    final t = rollT;
    shake = 0;
    if (t < 1.0) {
      down = _ease(t);
      fold = down;
      flip = 1;
      graze = 0.3 * down;
    } else if (t < 1.3) {
      down = fold = 1;
    } else if (t < 1.9) {
      final u = _ease((t - 1.3) / 0.6);
      flip = math.cos(math.pi * u);
      fold = 1 - 0.85 * u;
      graze = 0.3 + 0.7 * u;
    } else if (t < 3.5) {
      flip = -1 + 0.08 * (1 - math.cos((t - 1.9) * 7)) / 2;
      fold = 0.15;
    } else if (t < 4.1) {
      final u = _ease((t - 3.5) / 0.6);
      flip = -math.cos(math.pi * u);
      fold = 0.15 + 0.85 * u;
      graze = 1 - 0.8 * u;
    } else if (t < 5.0) {
      flip = 1;
      final u = _ease((t - 4.1) / 0.9);
      down = 1 - u;
      fold = down;
      graze = 0.2 * (1 - u);
    } else if (t < rollDuration) {
      down = fold = 0;
      graze = 0;
      shake = 1;
    } else {
      down = fold = shake = 0;
      flip = 1;
      _toGraze();
    }
  }
}

/// Geanimeerde boerderij met weer en grazende paarden.
class FarmScene extends StatefulWidget {
  const FarmScene({
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
  State<FarmScene> createState() => _FarmSceneState();
}

class _FarmSceneState extends State<FarmScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);
  final _rand = math.Random();
  final Map<String, _HorseAgent> _agents = {};
  Duration _last = Duration.zero;
  Size _size = Size.zero;

  /// Tijd tot twee paarden iets samen gaan doen.
  double _socialTimer = 8;

  @override
  void initState() {
    super.initState();
    _syncAgents();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(FarmScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAgents();
  }

  void _syncAgents() {
    final ids = widget.horses.map((h) => h.horse.id).toSet();
    _agents.removeWhere((id, a) {
      if (ids.contains(id)) return false;
      a.endSocial();
      return true;
    });
    for (final id in ids) {
      _agents.putIfAbsent(id, () => _HorseAgent(id, _rand));
    }
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    for (final a in _agents.values) {
      a.update(dt, _rand);
    }
    _socialTimer -= dt;
    if (_socialTimer <= 0) {
      _socialTimer = 14 + _rand.nextDouble() * 22;
      _startSocial();
    }
    _clock.value = elapsed.inMicroseconds / 1e6;
  }

  /// Twee vrije paarden gaan samen spelen of elkaar poetsen.
  void _startSocial() {
    final free = _agents.values.where((a) => a.idle && a.partner == null).toList()
      ..shuffle(_rand);
    if (free.length < 2 || _size.isEmpty) return;
    final a = free[0], b = free[1];
    a.partner = b;
    b.partner = a;
    a.leader = true;
    b.leader = false;
    if (_rand.nextBool()) {
      // spelen: de een draaft weg, de ander erachteraan
      for (final h in [a, b]) {
        h.activity = _Activity.play;
        h.timer = 6 + _rand.nextDouble() * 3;
        h.speed = 0.13;
        h.gait = 12;
      }
      b.speed = 0.14;
      a._pickPlayTarget(_rand);
    } else {
      // poetsen: b komt naast a staan, andersom, hoofd bij de schoft
      final l = SceneLayout(_size, widget.covered?.value ?? 0.38);
      final side = a.x < 0.5 ? 1.0 : -1.0;
      final off = 83 * l.horseScale(a.d) / (l.w * 0.88);
      for (final h in [a, b]) {
        h.activity = _Activity.groom;
        h.timer = 14;
        h.groomReady = false;
        h.speed = 0.045;
        h.gait = 6.5;
      }
      a.facingRight = side > 0;
      b.tx = (a.x + side * off).clamp(0.03, 0.97);
      b.td = (a.d + 0.06).clamp(0.0, 1.0);
      // past b er niet naast (rand van de wei)? dan niet
      if ((b.tx - (a.x + side * off)).abs() > 0.01) {
        a.endSocial();
        a.activity = _Activity.graze;
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  _HorseAgent? _hit(Offset pos, Size size, [void Function(Horse)? found]) {
    final layout = SceneLayout(size, widget.covered?.value ?? 0.38);
    // vooraan staande paarden eerst (die liggen bovenop)
    final sorted = widget.horses.toList()
      ..sort((a, b) =>
          (_agents[b.horse.id]?.d ?? 0).compareTo(_agents[a.horse.id]?.d ?? 0));
    for (final sh in sorted) {
      final a = _agents[sh.horse.id];
      if (a == null) continue;
      final p = layout.horsePos(a.x, a.d);
      final s = layout.horseScale(a.d);
      final rect = Rect.fromLTRB(p.dx - 55 * s, p.dy - 110 * s, p.dx + 55 * s, p.dy + 4 * s);
      if (rect.inflate(8).contains(pos)) {
        found?.call(sh.horse);
        return a;
      }
    }
    return null;
  }

  void _handleTap(TapUpDetails details, Size size) {
    _hit(details.localPosition, size, (horse) {
      // hinniken: hoofd omhoog en geluid (de tik zelf mag het geluid starten)
      final whinny = HorseSounds.greet(horse);
      final agent = _agents[horse.id];
      if (agent != null) {
        agent.startNeigh();
        agent.whinnied = whinny;
      }
      widget.onHorseTap?.call(horse);
    });
  }

  void _handleLongPress(LongPressStartDetails details, Size size) {
    final cb = widget.onHorseLongPress;
    if (cb == null) return;
    _hit(details.localPosition, size, cb);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      _size = size;
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (d) => _handleTap(d, size),
        onLongPressStart: (d) => _handleLongPress(d, size),
        child: CustomPaint(
          size: size,
          painter: _FarmPainter(
            clock: _clock,
            weather: widget.weather,
            horses: widget.horses,
            agents: _agents,
            covered: widget.covered,
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Tekenen
// ---------------------------------------------------------------------------

class _FarmPainter extends CustomPainter {
  _FarmPainter({
    required this.clock,
    required this.weather,
    required this.horses,
    required this.agents,
    required this.textScaler,
    this.covered,
  }) : super(repaint: clock);

  final ValueNotifier<double> clock;
  final SceneWeather weather;
  final List<SceneHorse> horses;
  final Map<String, _HorseAgent> agents;
  final ValueListenable<double>? covered;
  final TextScaler textScaler;

  static final _labelCache = <String, TextPainter>{};

  // Vaste "willekeurige" posities zodat de scène niet flikkert.
  static final List<Offset> _tufts = () {
    final r = math.Random(7);
    return List.generate(46, (_) => Offset(r.nextDouble(), r.nextDouble()));
  }();
  static final List<List<double>> _particles = () {
    final r = math.Random(11);
    return List.generate(
        220, (_) => [r.nextDouble(), r.nextDouble(), r.nextDouble()]);
  }();
  static final List<Offset> _stars = () {
    final r = math.Random(3);
    return List.generate(90, (_) => Offset(r.nextDouble(), r.nextDouble()));
  }();

  bool get _night => weather.isNight;
  WeatherKind get _kind => weather.kind;
  bool get _wet => _kind == WeatherKind.rain ||
      _kind == WeatherKind.drizzle ||
      _kind == WeatherKind.storm;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = clock.value;
    final l = SceneLayout(size, covered?.value ?? 0.38);
    canvas.clipRect(Offset.zero & size);

    _sky(canvas, l, t);
    _sunOrMoon(canvas, l, t);
    _clouds(canvas, l, t);
    _hills(canvas, l);
    _trees(canvas, l, t);
    _stable(canvas, l);
    _pasture(canvas, l, t);
    _fence(canvas, l);
    _props(canvas, l);
    _horses(canvas, l, t);
    if (!_night && weather.morning) {
      // zacht ochtendlicht over het landschap
      canvas.drawRect(Rect.fromLTRB(0, l.horizon - l.h * 0.12, l.w, l.h),
          Paint()..color = const Color(0x1AFFC88C));
    }
    if (_night) {
      canvas.drawRect(
        Rect.fromLTRB(0, l.horizon - l.h * 0.12, l.w, l.h),
        Paint()..color = const Color(0xFF0A1430).withValues(alpha: 0.38),
      );
      _stableGlow(canvas, l);
    }
    _weatherFx(canvas, l, t);
    _labels(canvas, l);
  }

  // ---- Lucht -------------------------------------------------------------
  void _sky(Canvas canvas, SceneLayout l, double t) {
    final List<Color> c;
    if (_night) {
      c = switch (_kind) {
        WeatherKind.clear || WeatherKind.partlyCloudy => const [
            Color(0xFF0B1630), Color(0xFF243A66)],
        WeatherKind.snow => const [Color(0xFF1E2838), Color(0xFF4A5A70)],
        _ => const [Color(0xFF151C28), Color(0xFF364252)],
      };
    } else {
      c = switch (_kind) {
        WeatherKind.clear => const [Color(0xFF5FAEE6), Color(0xFFCDEBF7)],
        WeatherKind.partlyCloudy => const [Color(0xFF7DB8E0), Color(0xFFDCEEF5)],
        WeatherKind.cloudy => const [Color(0xFF98AABA), Color(0xFFD9E0E4)],
        WeatherKind.fog => const [Color(0xFFB4BEC6), Color(0xFFE6E9EB)],
        WeatherKind.drizzle => const [Color(0xFF8396A6), Color(0xFFC6D0D7)],
        WeatherKind.rain => const [Color(0xFF6A7F90), Color(0xFFB5C2CC)],
        WeatherKind.storm => const [Color(0xFF3A4757), Color(0xFF7A8896)],
        WeatherKind.snow => const [Color(0xFFAFC0CF), Color(0xFFEAEFF3)],
      };
    }
    // ochtend: warmere lucht (bij helder of half bewolkt weer het sterkst)
    final List<Color> sky = !_night && weather.morning
        ? [
            Color.lerp(c[0], const Color(0xFF8DB9E2), 0.6)!,
            Color.lerp(c[1], const Color(0xFFF9D8B2),
                _kind == WeatherKind.clear || _kind == WeatherKind.partlyCloudy ? 0.9 : 0.45)!,
          ]
        : c;
    final rect = Rect.fromLTWH(0, 0, l.w, l.horizon + 4);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
            rect.topCenter, rect.bottomCenter, sky, const [0.0, 1.0]),
    );

    // sterren: heldere nacht vol, half bewolkt een deel, anders geen
    final starCount = !_night
        ? 0
        : _kind == WeatherKind.clear
            ? _stars.length
            : _kind == WeatherKind.partlyCloudy
                ? 35
                : 0;
    if (starCount > 0) {
      final p = Paint();
      for (var i = 0; i < starCount; i++) {
        final s = _stars[i];
        final tw = 0.5 + 0.5 * math.sin(t * 1.5 + i * 1.7);
        p.color = Colors.white.withValues(alpha: 0.35 + 0.55 * tw);
        canvas.drawCircle(
            Offset(s.dx * l.w, s.dy * l.horizon * 0.8), 0.8 + (i % 3) * 0.5, p);
      }
    }
  }

  void _sunOrMoon(Canvas canvas, SceneLayout l, double t) {
    // Zon/maan staan rechts naast de temperatuur, onder de datumstrip;
    // 's ochtends staat de zon lager.
    final c = weather.morning && !_night
        ? Offset(l.w * 0.86, l.h * 0.265)
        : Offset(l.w * 0.80, l.h * 0.24);
    final r = math.max(22.0, l.w * 0.055);
    final open = _kind == WeatherKind.clear || _kind == WeatherKind.partlyCloudy;
    if (!open) return; // achter een dicht wolkendek zie je geen zon of maan
    if (_night) {
      canvas.drawCircle(c, r * 2.2,
          Paint()
            ..shader = ui.Gradient.radial(c, r * 2.2, [
              const Color(0x33FFF6D8),
              const Color(0x00FFF6D8),
            ]));
      canvas.drawCircle(c, r * 0.8, Paint()..color = const Color(0xFFF4EED8));
      // maansikkel: hap eruit met de luchtkleur
      canvas.drawCircle(c + Offset(r * 0.38, -r * 0.18), r * 0.68,
          Paint()..color = const Color(0xFF1B2D55));
      return;
    }
    const visible = 1.0;
    // stralenkrans
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * 0.08);
    final ray = Paint()
      ..color = const Color(0xFFFFF3B0).withValues(alpha: 0.35 * visible);
    for (var i = 0; i < 12; i++) {
      canvas.rotate(math.pi / 6);
      final path = Path()
        ..moveTo(-r * 0.12, r * 1.25)
        ..lineTo(r * 0.12, r * 1.25)
        ..lineTo(0, r * (1.75 + 0.15 * math.sin(t * 2 + i)))
        ..close();
      canvas.drawPath(path, ray);
    }
    canvas.restore();
    canvas.drawCircle(c, r * 3,
        Paint()
          ..shader = ui.Gradient.radial(c, r * 3, [
            const Color(0xFFFFF4C2).withValues(alpha: 0.55 * visible),
            const Color(0x00FFF4C2),
          ]));
    canvas.drawCircle(
        c, r, Paint()..color = (weather.morning ? const Color(0xFFFFB84D) : const Color(0xFFFFD34D)).withValues(alpha: visible));
    canvas.drawCircle(c, r * 0.8,
        Paint()..color = (weather.morning ? const Color(0xFFFFCB73) : const Color(0xFFFFE27A)).withValues(alpha: visible));
  }

  void _clouds(Canvas canvas, SceneLayout l, double t) {
    switch (_kind) {
      case WeatherKind.clear:
        return; // strakblauw (of een heldere sterrenhemel)
      case WeatherKind.partlyCloudy:
        // een paar losse wolken, boven de zon zodat die vrij blijft
        final color = _night ? const Color(0xFF3B4866) : Colors.white;
        final speed = 5 + weather.wind * 30;
        final span = l.w + 240;
        for (var i = 0; i < 3; i++) {
          final p = _particles[i];
          final scale = (0.8 + p[2] * 0.5) * math.max(1.0, l.w / 420);
          final x = (p[0] * span + i * span / 3 + t * speed * (0.6 + p[2] * 0.6)) % span - 120;
          final y = l.h * (0.035 + p[1] * 0.11);
          _cloud(canvas, Offset(x, y), scale,
              Color.lerp(color, Colors.black, (i % 2) * 0.05)!);
        }
      default:
        _overcast(canvas, l, t);
    }
  }

  /// Dicht wolkendek: de lucht zit vol, alleen bij de horizon wat licht.
  void _overcast(Canvas canvas, SceneLayout l, double t) {
    final (List<Color> day, List<Color> night) = switch (_kind) {
      WeatherKind.fog => (
          const [Color(0xFFCBD1D6), Color(0xFFDDE1E4), Color(0xFFECEFF1)],
          const [Color(0xFF3A424E), Color(0xFF485160), Color(0xFF59626F)]
        ),
      WeatherKind.drizzle => (
          const [Color(0xFF9AA4AE), Color(0xFFB3BCC4), Color(0xFFC6CDD3)],
          const [Color(0xFF222831), Color(0xFF2E3540), Color(0xFF3B4350)]
        ),
      WeatherKind.rain => (
          const [Color(0xFF7E8994), Color(0xFF98A2AC), Color(0xFFADB5BD)],
          const [Color(0xFF1C2129), Color(0xFF262C36), Color(0xFF323A46)]
        ),
      WeatherKind.storm => (
          const [Color(0xFF4E5662), Color(0xFF636C78), Color(0xFF747D89)],
          const [Color(0xFF15191F), Color(0xFF1E232B), Color(0xFF2A303A)]
        ),
      WeatherKind.snow => (
          const [Color(0xFFC3CBD3), Color(0xFFD6DCE1), Color(0xFFE6EAEE)],
          const [Color(0xFF2E3644), Color(0xFF3C4554), Color(0xFF4C5565)]
        ),
      _ => (
          const [Color(0xFFAEB7BF), Color(0xFFC7CED4), Color(0xFFDCE1E5)],
          const [Color(0xFF262C37), Color(0xFF353D4A), Color(0xFF424B59)]
        ),
    };
    var c = _night ? night : day;
    if (!_night && weather.morning) {
      c = [for (final x in c) Color.lerp(x, const Color(0xFFF0CDB0), 0.15)!];
    }
    final k = math.max(1.0, l.w / 420);
    final bottom = l.horizon * 0.78;
    final drift = t * (4 + weather.wind * 30);

    // het wolkendek zelf
    final deck = Rect.fromLTRB(0, 0, l.w, bottom);
    canvas.drawRect(
        deck,
        Paint()
          ..shader = ui.Gradient.linear(deck.topCenter, deck.bottomCenter, [c[0], c[1]]));
    // lichtere plukken voor wat structuur
    final soft = Paint()..color = c[2].withValues(alpha: 0.45);
    for (var j = 0; j < 5; j++) {
      final span = l.w * 1.6;
      final x = (j * span / 5 + drift * (0.5 + j * 0.1)) % span - l.w * 0.3;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, bottom * (0.2 + 0.15 * j)),
              width: l.w * 0.55,
              height: 34 * k),
          soft);
    }
    // drie rijen bolle wolken over het hele dek (met schaduwkant)
    final shadow = Paint()
      ..color = Color.lerp(c[0], Colors.black, 0.06)!.withValues(alpha: 0.55);
    final puff = Paint()..color = c[2].withValues(alpha: 0.55);
    for (var row = 0; row < 3; row++) {
      final st = (58 - row * 8) * k;
      final of = (drift * (0.4 + row * 0.15) + row * 23 * k) % st;
      final yy = bottom * (0.22 + row * 0.24);
      for (var i = -2; i * st < l.w + st * 2; i++) {
        final rr = (26 + (i * 41 + row * 17).abs() % 14 - row * 3) * k;
        final x = i * st + of;
        canvas.drawCircle(Offset(x + 3 * k, yy + 5 * k), rr, shadow);
        canvas.drawCircle(Offset(x, yy), rr, puff);
      }
    }
    // golvende, iets donkerdere onderkant van de wolken
    final step = 34 * k;
    final off = drift % step;
    final under = Paint()..color = Color.lerp(c[1], Colors.black, 0.10)!;
    for (var i = -2; i * step < l.w + step * 2; i++) {
      final r = (22 + (i * 37).abs() % 13) * k;
      final y = bottom - 4 * k + ((i * 53).abs() % 7) * k;
      canvas.drawCircle(Offset(i * step + off, y), r, under);
    }
    // tweede, lichtere rij iets lager voor diepte
    final step2 = 46 * k;
    final off2 = (drift * 0.7) % step2;
    final front = Paint()..color = c[2];
    for (var i = -2; i * step2 < l.w + step2 * 2; i++) {
      final r = (14 + (i * 29).abs() % 9) * k;
      canvas.drawCircle(Offset(i * step2 + step2 / 2 + off2, bottom + 8 * k), r, front);
    }
    // bij mist schemert de zon er nog doorheen
    if (_kind == WeatherKind.fog && !_night) {
      canvas.drawCircle(Offset(l.w * 0.78, l.h * 0.17), math.max(18.0, l.w * 0.045),
          Paint()..color = Colors.white.withValues(alpha: 0.55));
    }
  }

  void _cloud(Canvas canvas, Offset o, double s, Color c) {
    final p = Paint()..color = c;
    final path = Path()
      ..addOval(Rect.fromCircle(center: o + Offset(-34 * s, 6 * s), radius: 18 * s))
      ..addOval(Rect.fromCircle(center: o + Offset(-10 * s, -6 * s), radius: 26 * s))
      ..addOval(Rect.fromCircle(center: o + Offset(20 * s, -2 * s), radius: 22 * s))
      ..addOval(Rect.fromCircle(center: o + Offset(42 * s, 8 * s), radius: 15 * s))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTRB(o.dx - 46 * s, o.dy + 2 * s, o.dx + 54 * s, o.dy + 22 * s),
          Radius.circular(10 * s)));
    canvas.drawPath(path, p);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(o.dx - 44 * s, o.dy + 14 * s, o.dx + 52 * s, o.dy + 22 * s),
            Radius.circular(8 * s)),
        Paint()..color = Color.lerp(c, Colors.black, 0.07)!);
  }

  // ---- Landschap ---------------------------------------------------------
  Color _groundTint(Color c) {
    if (_kind == WeatherKind.snow) return Color.lerp(c, const Color(0xFFF4F7FA), 0.78)!;
    if (weather.frost) return Color.lerp(c, const Color(0xFFE8F0F2), 0.42)!;
    return c;
  }

  void _hills(Canvas canvas, SceneLayout l) {
    final hz = l.horizon;
    final far = Path()
      ..moveTo(0, hz - l.h * 0.045)
      ..quadraticBezierTo(l.w * 0.3, hz - l.h * 0.10, l.w * 0.6, hz - l.h * 0.05)
      ..quadraticBezierTo(l.w * 0.82, hz - l.h * 0.02, l.w, hz - l.h * 0.06)
      ..lineTo(l.w, hz + 2)
      ..lineTo(0, hz + 2)
      ..close();
    final fogged = _kind == WeatherKind.fog ? 0.5 : 0.0;
    canvas.drawPath(
        far,
        Paint()
          ..color = Color.lerp(_groundTint(const Color(0xFF8DB879)),
              const Color(0xFFDDE3E6), fogged)!);
    final near = Path()
      ..moveTo(0, hz - l.h * 0.01)
      ..quadraticBezierTo(l.w * 0.25, hz - l.h * 0.04, l.w * 0.55, hz - l.h * 0.012)
      ..quadraticBezierTo(l.w * 0.8, hz + l.h * 0.004, l.w, hz - l.h * 0.025)
      ..lineTo(l.w, hz + 4)
      ..lineTo(0, hz + 4)
      ..close();
    canvas.drawPath(near, Paint()..color = _groundTint(const Color(0xFF79AA62)));
  }

  void _trees(Canvas canvas, SceneLayout l, double t) {
    final sway = math.sin(t * 1.6) * 0.03 * (0.3 + weather.wind * 1.6);
    final k = math.min(l.w, l.h * 0.62) / 400;
    void round(double x, double scale) {
      final base = Offset(x, l.horizon + 2);
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(sway);
      canvas.scale(scale * k);
      canvas.drawRect(const Rect.fromLTRB(-4, -40, 4, 0),
          Paint()..color = const Color(0xFF6B4A31));
      final leaf = _groundTint(const Color(0xFF4E8F3F));
      final leafHi = _groundTint(const Color(0xFF66A651));
      canvas.drawCircle(const Offset(-14, -50), 20, Paint()..color = leaf);
      canvas.drawCircle(const Offset(14, -52), 20, Paint()..color = leaf);
      canvas.drawCircle(const Offset(0, -68), 24, Paint()..color = leaf);
      canvas.drawCircle(const Offset(-6, -72), 12, Paint()..color = leafHi);
      canvas.restore();
    }

    void pine(double x, double scale) {
      canvas.save();
      canvas.translate(x, l.horizon + 2);
      canvas.rotate(sway * 0.6);
      canvas.scale(scale * k);
      canvas.drawRect(const Rect.fromLTRB(-3, -14, 3, 0),
          Paint()..color = const Color(0xFF5E4330));
      final c = _groundTint(const Color(0xFF2F6E46));
      for (var i = 0; i < 3; i++) {
        final y = -14.0 - i * 18;
        final w = 24.0 - i * 6;
        canvas.drawPath(
            Path()
              ..moveTo(-w, y)
              ..lineTo(w, y)
              ..lineTo(0, y - 30)
              ..close(),
            Paint()..color = c);
      }
      canvas.restore();
    }

    round(l.w * 0.07, 1.0);
    round(l.w * 0.19, 0.8);
    pine(l.w * 0.52, 0.9);
    pine(l.w * 0.585, 0.7);
  }

  Rect _stableRect(SceneLayout l) {
    final k = math.min(l.w, l.h * 0.62) / 400;
    final width = 150 * k;
    final height = 74 * k;
    final right = l.w * 0.96;
    return Rect.fromLTRB(right - width, l.horizon + 6 * k - height,
        right, l.horizon + 6 * k);
  }

  void _stable(Canvas canvas, SceneLayout l) {
    final r = _stableRect(l);
    final k = r.width / 150;
    final wallTop = r.top + 30 * k;
    final wood = const Color(0xFF8A5A3B);
    final woodDark = const Color(0xFF6A4128);

    // muren
    final wall = Rect.fromLTRB(r.left, wallTop, r.right, r.bottom);
    canvas.drawRect(wall, Paint()..color = wood);
    final plank = Paint()
      ..color = woodDark.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var x = wall.left + 6 * k; x < wall.right; x += 7 * k) {
      canvas.drawLine(Offset(x, wall.top), Offset(x, wall.bottom), plank);
    }
    // dak (zadeldak met overstek)
    final roof = Path()
      ..moveTo(r.left - 8 * k, wallTop + 2 * k)
      ..lineTo(r.left + 22 * k, r.top)
      ..lineTo(r.right - 22 * k, r.top)
      ..lineTo(r.right + 8 * k, wallTop + 2 * k)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF3E4148));
    final roofLine = Paint()
      ..color = const Color(0xFF2E3036)
      ..strokeWidth = 1.2;
    for (var i = 1; i < 4; i++) {
      final y = r.top + (wallTop - r.top) * i / 4;
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), roofLine);
    }
    if (_kind == WeatherKind.snow || weather.frost) {
      final snow = Path()
        ..moveTo(r.left + 22 * k, r.top)
        ..lineTo(r.right - 22 * k, r.top)
        ..lineTo(r.right - 14 * k, r.top + 9 * k)
        ..lineTo(r.left + 14 * k, r.top + 9 * k)
        ..close();
      canvas.drawPath(
          snow,
          Paint()
            ..color = Colors.white
                .withValues(alpha: _kind == WeatherKind.snow ? 0.95 : 0.55));
    }

    // staldeuren (onderdeur dicht, bovendeur open)
    final doorW = 22 * k, doorH = 34 * k;
    for (var i = 0; i < 3; i++) {
      final left = r.left + 18 * k + i * 40 * k;
      final door = Rect.fromLTWH(left, r.bottom - doorH, doorW, doorH);
      canvas.drawRect(door.inflate(2 * k), Paint()..color = const Color(0xFFF1E8D8));
      canvas.drawRect(Rect.fromLTRB(door.left, door.top, door.right, door.center.dy),
          Paint()..color = _night ? const Color(0xFFFFC765) : const Color(0xFF2A1E16));
      canvas.drawRect(Rect.fromLTRB(door.left, door.center.dy, door.right, door.bottom),
          Paint()..color = const Color(0xFFA0683F));
      final cross = Paint()
        ..color = const Color(0xFFF1E8D8)
        ..strokeWidth = 1.6 * k;
      canvas.drawLine(Offset(door.left, door.center.dy),
          Offset(door.right, door.bottom), cross);
      canvas.drawLine(Offset(door.right, door.center.dy),
          Offset(door.left, door.bottom), cross);
    }
    // windvaan met paardje
    final vane = Offset(r.center.dx, r.top);
    canvas.drawLine(vane, vane - Offset(0, 14 * k),
        Paint()
          ..color = const Color(0xFF2E3036)
          ..strokeWidth = 1.4 * k);
  }

  void _stableGlow(Canvas canvas, SceneLayout l) {
    final r = _stableRect(l);
    final k = r.width / 150;
    for (var i = 0; i < 3; i++) {
      final c = Offset(r.left + 18 * k + i * 40 * k + 11 * k, r.bottom - 26 * k);
      canvas.drawCircle(c, 26 * k,
          Paint()
            ..shader = ui.Gradient.radial(c, 26 * k, [
              const Color(0x66FFC765),
              const Color(0x00FFC765),
            ]));
      canvas.drawRect(Rect.fromLTWH(c.dx - 11 * k, c.dy - 8 * k, 22 * k, 17 * k),
          Paint()..color = const Color(0xCCFFC765));
    }
  }

  void _pasture(Canvas canvas, SceneLayout l, double t) {
    final rect = Rect.fromLTRB(0, l.horizon, l.w, l.h);
    final top = _groundTint(const Color(0xFF8CC26B));
    final bottom = _groundTint(const Color(0xFF5E9E4B));
    canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, l.horizon),
              Offset(0, l.pastureBottom + l.h * 0.1), [top, bottom]));
    // maaibanen
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.05);
    for (var i = 0; i < 6; i++) {
      final y = l.horizon + (l.h - l.horizon) * i / 6;
      canvas.drawRect(Rect.fromLTWH(0, y, l.w, (l.h - l.horizon) / 12), stripe);
    }
    // plassen bij regen
    if (_wet) {
      final puddle = Paint()
        ..color = const Color(0xFFA8C4D6).withValues(alpha: _night ? 0.35 : 0.6);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(l.w * 0.3, l.pastureBottom + l.h * 0.01),
              width: l.w * 0.16,
              height: l.h * 0.012),
          puddle);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(l.w * 0.72, l.pastureTop + l.h * 0.03),
              width: l.w * 0.1,
              height: l.h * 0.008),
          puddle);
    }
    // grasplukjes die meewaaien
    final grass = Paint()
      ..color = _groundTint(const Color(0xFF4C8A3B))
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final sway = 0.15 + weather.wind * 0.9;
    for (var i = 0; i < _tufts.length; i++) {
      final p = _tufts[i];
      final y = ui.lerpDouble(l.horizon + l.h * 0.03, l.h * 0.66, p.dy)!;
      final x = p.dx * l.w;
      final s = 0.6 + (y - l.horizon) / (l.h * 0.3);
      final bend = math.sin(t * 2.2 + i) * 3 * sway * s;
      for (var b = -1; b <= 1; b++) {
        canvas.drawLine(Offset(x + b * 2.5 * s, y),
            Offset(x + b * 4 * s + bend, y - 7 * s), grass);
      }
    }
  }

  void _fence(Canvas canvas, SceneLayout l) {
    final y = l.horizon + l.h * 0.03;
    final k = math.min(l.w, l.h * 0.62) / 400;
    final postH = 26 * k;
    final wood = Paint()..color = const Color(0xFFF3EDE2);
    final shadow = Paint()..color = const Color(0xFFCFC5B4);
    for (final ry in [y - postH * 0.75, y - postH * 0.35]) {
      canvas.drawRect(Rect.fromLTWH(0, ry, l.w, 3.2 * k), wood);
      canvas.drawRect(Rect.fromLTWH(0, ry + 3.2 * k, l.w, 1 * k), shadow);
    }
    for (var x = 8.0; x < l.w; x += 48 * k) {
      canvas.drawRect(Rect.fromLTWH(x, y - postH, 4.5 * k, postH), wood);
      canvas.drawRect(Rect.fromLTWH(x + 3.5 * k, y - postH, 1 * k, postH), shadow);
    }
  }

  void _props(Canvas canvas, SceneLayout l) {
    final k = math.min(l.w, l.h * 0.62) / 400;
    // hooiruif met hooi
    final hay = Offset(l.w * 0.16, l.horizon + l.h * 0.052);
    canvas.drawOval(Rect.fromCenter(center: hay + Offset(0, 2 * k), width: 46 * k, height: 7 * k),
        Paint()..color = Colors.black.withValues(alpha: 0.15));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: hay - Offset(0, 10 * k), width: 38 * k, height: 22 * k),
            Radius.circular(7 * k)),
        Paint()..color = const Color(0xFFE2BE5A));
    final straw = Paint()
      ..color = const Color(0xFFC79E3A)
      ..strokeWidth = 1.1 * k;
    for (var i = -3; i <= 3; i++) {
      canvas.drawLine(hay + Offset(i * 5 * k, -20 * k),
          hay + Offset(i * 5 * k + 2 * k, -1 * k), straw);
    }
    // waterbak
    final trough = Offset(l.w * 0.70, l.horizon + l.h * 0.055);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: trough - Offset(0, 6 * k), width: 40 * k, height: 13 * k),
            Radius.circular(3 * k)),
        Paint()..color = const Color(0xFF8A949C));
    canvas.drawRect(
        Rect.fromCenter(center: trough - Offset(0, 11 * k), width: 34 * k, height: 3 * k),
        Paint()
          ..color = weather.temp <= 0
              ? const Color(0xFFDDEFF7)
              : const Color(0xFF6FB1D8));
  }

  // ---- Paarden ---------------------------------------------------------
  void _horses(Canvas canvas, SceneLayout l, double t) {
    final list = horses.where((h) => agents.containsKey(h.horse.id)).toList()
      ..sort((a, b) => agents[a.horse.id]!.d.compareTo(agents[b.horse.id]!.d));
    for (final sh in list) {
      final a = agents[sh.horse.id]!;
      final p = l.horsePos(a.x, a.d);
      final s = l.horseScale(a.d);
      if (a.dusty) _dust(canvas, p, s, t, a);
      canvas.save();
      // uitschudden na het rollen: snel heen en weer
      final jitter = a.shake * math.sin(t * 55) * 1.6 * s;
      canvas.translate(p.dx + jitter, p.dy);
      canvas.scale(a.facingRight ? s : -s, s);
      paintHorse(
        canvas,
        HorseLook.of(sh.horse, sh.advice, sh.pick),
        HorsePose(
          graze: a.graze,
          walk: a.walk,
          walkPhase: a.walkPhase,
          tailPhase: a.tailPhase,
          earFlick: a.earFlick,
          leftSide: !a.facingRight,
          down: a.down,
          fold: a.fold,
          flip: a.flip,
          neigh: a.neigh,
        ),
      );
      canvas.restore();
    }
  }

  /// Stofwolkjes bij het rollen en uitschudden.
  void _dust(Canvas canvas, Offset p, double s, double t, _HorseAgent a) {
    final base = _night ? const Color(0xFF8A8478) : const Color(0xFFD8C9A8);
    final paint = Paint();
    for (var i = 0; i < 9; i++) {
      final q = _particles[i + 40];
      final life = (t * 0.9 + q[0]) % 1.0;
      final x = p.dx + (q[1] - 0.5) * 80 * s + (q[1] - 0.5) * life * 40 * s;
      final y = p.dy - 4 * s - life * (18 + q[2] * 16) * s;
      paint.color = base.withValues(alpha: 0.45 * (1 - life));
      canvas.drawCircle(Offset(x, y), (5 + life * 9) * s * (0.7 + q[2] * 0.6), paint);
    }
  }

  void _labels(Canvas canvas, SceneLayout l) {
    for (final sh in horses) {
      final a = agents[sh.horse.id];
      if (a == null) continue;
      final p = l.horsePos(a.x, a.d);
      final s = l.horseScale(a.d);
      final tp = _labelCache.putIfAbsent(
        '${sh.horse.name}|${textScaler.scale(12)}',
        () => TextPainter(
          text: TextSpan(
            text: sh.horse.name,
            style: const TextStyle(
                color: Color(0xFF1F2A22),
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout(),
      );
      // label hangt boven de rug en schuift mee met hoofd omhoog/omlaag
      // (en zakt mee als het paard ligt)
      final top = p.dy - (82 - a.graze * 14 - a.down * 26) * s - tp.height - 12;
      final dot = 8.0;
      final w = tp.width + dot + 18;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(p.dx, top + tp.height / 2 + 3),
            width: w,
            height: tp.height + 8),
        const Radius.circular(20),
      );
      canvas.drawRRect(rect.shift(const Offset(0, 1.5)),
          Paint()..color = Colors.black.withValues(alpha: 0.10));
      canvas.drawRRect(rect, Paint()..color = Colors.white.withValues(alpha: 0.92));
      final level = sh.advice?.level ?? BlanketLevel.none;
      canvas.drawCircle(Offset(rect.left + 9 + dot / 2, rect.center.dy), dot / 2,
          Paint()..color = level.color);
      tp.paint(canvas, Offset(rect.left + 13 + dot, rect.top + 4));
      if (a.neighT > 0.12 && a.neighT < _HorseAgent.neighDuration - 0.15) {
        _neighBubble(canvas, l, p, s, a);
      }
    }
  }

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

  /// Tekstballonnetje bij het hoofd tijdens het hinniken.
  void _neighBubble(Canvas canvas, SceneLayout l, Offset p, double s, _HorseAgent a) {
    final dir = a.facingRight ? 1.0 : -1.0;
    final grow = math.min(1.0, (a.neighT - 0.12) / 0.15);
    final mouth = Offset(p.dx + dir * 76 * s, p.dy - 100 * s);
    final tp = a.whinnied ? _whinnyText : _snortText;
    final w = tp.width + 18, h = tp.height + 10;
    var left = dir > 0 ? mouth.dx + 6 : mouth.dx - 6 - w;
    left = left.clamp(4.0, math.max(4.0, l.w - w - 4));
    final rect = Rect.fromLTWH(left, mouth.dy - h - 10, w, h);
    canvas.save();
    canvas.translate(mouth.dx, mouth.dy);
    canvas.scale(grow);
    canvas.translate(-mouth.dx, -mouth.dy);
    final bubble = Paint()..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect.shift(const Offset(0, 1.5)), const Radius.circular(14)),
        Paint()..color = Colors.black.withValues(alpha: 0.10));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(14)), bubble);
    final tailX = dir > 0 ? rect.left + 12 : rect.right - 12;
    canvas.drawPath(
        Path()
          ..moveTo(tailX - 5, rect.bottom - 1)
          ..lineTo(tailX + 5, rect.bottom - 1)
          ..lineTo(mouth.dx, mouth.dy - 2)
          ..close(),
        bubble);
    tp.paint(canvas, Offset(rect.left + 9, rect.top + 5));
    canvas.restore();
  }

  // ---- Weer-effecten -----------------------------------------------------
  void _weatherFx(Canvas canvas, SceneLayout l, double t) {
    final wind = weather.wind;
    switch (_kind) {
      case WeatherKind.drizzle:
      case WeatherKind.rain:
      case WeatherKind.storm:
        final n = switch (_kind) {
          WeatherKind.drizzle => 70,
          WeatherKind.rain => 150,
          _ => 210,
        };
        final len = _kind == WeatherKind.drizzle ? 7.0 : 13.0;
        final slant = 0.15 + wind * 0.6;
        final p = Paint()
          ..color = Colors.white.withValues(alpha: _night ? 0.35 : 0.55)
          ..strokeWidth = _kind == WeatherKind.drizzle ? 1 : 1.4
          ..strokeCap = StrokeCap.round;
        final fallH = l.h * 0.72;
        for (var i = 0; i < n; i++) {
          final q = _particles[i];
          final speed = fallH * (0.9 + q[2] * 0.6);
          final y = (q[1] * fallH + t * speed) % fallH;
          final x = (q[0] * (l.w + 80) - y * slant) % (l.w + 80) - 40;
          canvas.drawLine(Offset(x, y), Offset(x - len * slant, y + len), p);
        }
        if (_kind == WeatherKind.storm) _lightning(canvas, l, t);
      case WeatherKind.snow:
        final p = Paint()..color = Colors.white.withValues(alpha: 0.9);
        final fallH = l.h * 0.72;
        for (var i = 0; i < 140; i++) {
          final q = _particles[i];
          final speed = 22 + q[2] * 30;
          final y = (q[1] * fallH + t * speed) % fallH;
          final x = (q[0] * l.w + math.sin(t * 0.9 + i) * 10 + t * wind * 30) %
              l.w;
          canvas.drawCircle(Offset(x, y), 1.2 + q[2] * 2, p);
        }
      case WeatherKind.fog:
        // waas over het hele landschap + drijvende mistbanken
        final haze = _night ? const Color(0xFFB8C2D6) : Colors.white;
        canvas.drawRect(
            Rect.fromLTRB(0, l.horizon - l.h * 0.12, l.w, l.h),
            Paint()..color = haze.withValues(alpha: _night ? 0.16 : 0.24));
        final band = _night ? const Color(0xFFC8D0E0) : Colors.white;
        for (var i = 0; i < 6; i++) {
          final y = l.horizon - l.h * 0.06 + i * l.h * 0.045;
          final dx = math.sin(t * 0.15 + i) * l.w * 0.08;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(-l.w * 0.2 + dx, y, l.w * 1.4, l.h * 0.05),
                Radius.circular(l.h * 0.03)),
            Paint()
              ..color = band.withValues(alpha: _night ? 0.30 : 0.42)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
          );
        }
      default:
        break;
    }

    // windvlagen
    if (wind >= 0.4) {
      final p = Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 4; i++) {
        final q = _particles[200 + i];
        final span = l.w + 200;
        final x = (q[0] * span + t * (140 + 160 * wind)) % span - 100;
        final y = l.h * (0.16 + q[1] * 0.3);
        final path = Path()
          ..moveTo(x, y)
          ..cubicTo(x + 30, y - 6, x + 50, y + 6, x + 80, y)
          ..relativeQuadraticBezierTo(14, -4, 6, -12);
        canvas.drawPath(path, p);
      }
    }
  }

  void _lightning(Canvas canvas, SceneLayout l, double t) {
    const period = 5.0;
    final cycle = t % period;
    if (cycle > 0.4) return;
    final flash = cycle < 0.1 || (cycle > 0.2 && cycle < 0.28);
    if (!flash) return;
    canvas.drawRect(Offset.zero & l.size,
        Paint()..color = const Color(0xFFE8EEFF).withValues(alpha: _night ? 0.32 : 0.38));
    final r = math.Random((t / period).floor());
    var p = Offset(l.w * (0.15 + r.nextDouble() * 0.7), l.horizon * 0.76);
    final path = Path()..moveTo(p.dx, p.dy);
    final branches = <Path>[];
    while (p.dy < l.horizon - 6) {
      p += Offset((r.nextDouble() - 0.5) * 26, 8 + r.nextDouble() * 10);
      path.lineTo(p.dx, p.dy);
      if (r.nextDouble() < 0.25) {
        branches.add(Path()
          ..moveTo(p.dx, p.dy)
          ..relativeLineTo((r.nextDouble() - 0.5) * 30, 10 + r.nextDouble() * 12));
      }
    }
    final glow = Paint()
      ..color = const Color(0x88FFF3A0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final core = Paint()
      ..color = const Color(0xFFFFFBE6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glow);
    canvas.drawPath(path, core);
    for (final b in branches) {
      canvas.drawPath(b, core..strokeWidth = 1.6);
    }
  }

  @override
  bool shouldRepaint(_FarmPainter old) => true;
}
