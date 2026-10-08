import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../logic/blanket_advisor.dart';
import '../models/horse.dart';
import '../models/weather.dart';
import '../state/app_state.dart';
import '../ui.dart';
import '../widgets/advice_widgets.dart';
import '../widgets/farm_scene.dart';
import '../widgets/horse_painter.dart';
import '../widgets/horseshoe_icon.dart';
import '../widgets/nero.dart';
import '../widgets/stable_scene.dart';
import 'horse_form_screen.dart';
import 'stable_screen.dart';
import 'location_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  /// Handmatige keuze wei/stal als een deel van de paarden binnen staat
  /// (geldt voor één dag + fase; daarna weer automatisch).
  bool? _stableOverride;
  String _overrideKey = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s != AppLifecycleState.resumed) return;
    final app = AppScope.read(context);
    final last = app.updatedAt;
    if (last == null || DateTime.now().difference(last).inMinutes >= 30) {
      app.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final period = app.currentPeriod;

    final scene = _sceneWeather(app);
    // Zolang er nog geen eigen paarden zijn, staat mascotte Nero in de wei.
    final all = app.horses.isEmpty ? [neroHorse] : app.horses;
    SceneHorse sceneHorse(Horse h) {
      final a = app.adviceFor(h);
      return SceneHorse(h, a, app.pickFor(h, a));
    }

    final inside = [
      for (final h in all)
        if (app.insideAt(h, app.selectedDay, app.selectedPhase)) sceneHorse(h),
    ];
    final outside = [
      for (final h in all)
        if (!app.insideAt(h, app.selectedDay, app.selectedPhase)) sceneHorse(h),
    ];
    final key = '${app.selectedDay}|${app.selectedPhase.name}';
    if (key != _overrideKey) {
      _overrideKey = key;
      _stableOverride = null;
    }
    final mixed = inside.isNotEmpty && outside.isNotEmpty;
    final showStable =
        inside.isNotEmpty && (outside.isEmpty || (_stableOverride ?? false));

    void onHorseTap(Horse h) {
      if (h.id == neroHorse.id) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const HorseFormScreen()));
        return;
      }
      final a = app.adviceFor(h);
      if (a != null && period != null) {
        showHorseAdvice(context, h, a, period,
            pick: app.pickFor(h, a), hasBlankets: app.hasBlanketsFor(h));
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF8CC26B),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              child: showStable
                  ? StableScene(
                      key: const ValueKey('stal'),
                      weather: scene,
                      horses: inside,
                      onHorseTap: onHorseTap,
                    )
                  : FarmScene(
                      key: const ValueKey('wei'),
                      weather: scene,
                      horses: outside,
                      onHorseTap: onHorseTap,
                    ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(app: app),
                  const SizedBox(height: 12),
                  if (app.stripDays.isNotEmpty) _DateStrip(app: app),
                  const SizedBox(height: 10),
                  if (period != null)
                    _BigTemperature(
                        period: period,
                        phase: app.selectedPhase,
                        night: scene.isNight || showStable),
                  const SizedBox(height: 10),
                  if (app.forecast != null) _PhaseBar(app: app),
                  if (mixed) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => setState(() => _stableOverride = !showStable),
                        child: _Glass(
                          radius: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(showStable ? Icons.grass : Icons.house_siding,
                                size: 18, color: AppColors.green),
                            const SizedBox(width: 6),
                            Text(
                              showStable
                                  ? 'Naar de wei (${outside.length})'
                                  : 'Naar de stal (${inside.length})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.36,
            maxChildSize: 0.93,
            snap: true,
            snapSizes: const [0.38],
            builder: (context, controller) => _Sheet(controller: controller),
          ),
        ],
      ),
    );
  }

  SceneWeather _sceneWeather(AppState app) {
    final w = app.currentPeriod;
    if (w == null) {
      final h = DateTime.now().hour;
      return SceneWeather(
          kind: WeatherKind.partlyCloudy,
          isNight: h >= 18 || h < 6,
          wind: 0.2,
          temp: 10,
          morning: h >= 6 && h < 12);
    }
    final phase = app.selectedPhase;
    return SceneWeather(
      kind: w.kind,
      isNight: phase.isNight,
      wind: (w.maxWind / 45).clamp(0.0, 1.0),
      temp: phase.isNight ? w.minTemp : w.avgTemp,
      morning: phase == DayPhase.morning,
    );
  }
}

// ---------------------------------------------------------------------------

class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.padding = EdgeInsets.zero, this.radius = 30});
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({this.icon, required this.onTap, this.tooltip, this.child});
  final IconData? icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: _Glass(
          radius: 24,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(child: child ?? Icon(icon, color: AppColors.ink, size: 22)),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Flexible(
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LocationScreen())),
          child: _Glass(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.place, size: 18, color: AppColors.green),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  app.location.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.expand_more, size: 18),
            ]),
          ),
        ),
      ),
      const Spacer(),
      _RoundButton(
        icon: Icons.refresh,
        tooltip: 'Vernieuwen',
        onTap: app.loading ? () {} : app.refresh,
        child: app.loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2))
            : null,
      ),
      const SizedBox(width: 8),
      _RoundButton(
        tooltip: 'Mijn stal',
        child: const HorseshoeIcon(size: 24, color: AppColors.ink),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const StableScreen())),
      ),
    ]);
  }
}

class _BigTemperature extends StatelessWidget {
  const _BigTemperature({required this.period, required this.phase, required this.night});
  final PeriodWeather period;
  final DayPhase phase;
  final bool night;

  @override
  Widget build(BuildContext context) {
    // 's nachts telt de laagste, overdag de hoogste temperatuur
    final temp = phase.isNight ? period.minTemp : period.maxTemp;
    final sub = '${phase.label} · ${describeCode(period.code)}';
    final color = night ? Colors.white : AppColors.ink;
    final shadow = [
      Shadow(
          color: (night ? Colors.black : Colors.white).withValues(alpha: 0.35),
          blurRadius: 12),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${temp.round()}',
            style: TextStyle(
                fontSize: 56,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
                color: color,
                shadows: shadow)),
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 2),
          child: Text('°C',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600, color: color, shadows: shadow)),
        ),
      ]),
      const SizedBox(height: 2),
      Text(sub,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: color, shadows: shadow)),
    ]);
  }
}

/// Zeven dagen om uit te kiezen.
class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final days = app.stripDays;
    return _Glass(
      radius: 22,
      padding: const EdgeInsets.all(5),
      child: Row(children: [
        for (final d in days)
          Expanded(
            child: _DayChip(
              day: d,
              selected: dateOnly(d.date) == app.selectedDay,
              onTap: () => app.selectDay(d.date),
            ),
          ),
      ]),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.selected, required this.onTap});
  final DayWeather day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(weekdayShort[day.date.weekday - 1],
              style: TextStyle(
                  fontSize: 12, color: fg.withValues(alpha: 0.8), fontWeight: FontWeight.w500)),
          Text('${day.date.day}',
              style: TextStyle(fontSize: 17, color: fg, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Icon(iconForKind(kindForCode(day.code)), size: 16, color: fg),
        ]),
      ),
    );
  }
}

/// Ochtend / Middag / Avond & nacht.
class _PhaseBar extends StatelessWidget {
  const _PhaseBar({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 24,
      padding: const EdgeInsets.all(5),
      child: Row(children: [
        for (final p in DayPhase.values)
          Expanded(
            flex: p == DayPhase.evening ? 5 : 4,
            child: GestureDetector(
              onTap: () => app.selectPhase(p),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                decoration: BoxDecoration(
                  color: p == app.selectedPhase ? AppColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(p.icon,
                      size: 18,
                      color: p == app.selectedPhase ? Colors.white : AppColors.ink),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                                color: p == app.selectedPhase ? Colors.white : AppColors.ink)),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(p.range,
                              style: TextStyle(
                                  fontSize: 10,
                                  height: 1.1,
                                  color: (p == app.selectedPhase ? Colors.white : AppColors.ink)
                                      .withValues(alpha: 0.75))),
                          if (app.anyInside(app.selectedDay, p)) ...[
                            const SizedBox(width: 3),
                            Icon(Icons.house_siding,
                                size: 11,
                                color: (p == app.selectedPhase ? Colors.white : AppColors.ink)
                                    .withValues(alpha: 0.75)),
                          ],
                        ]),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Onderste paneel
// ---------------------------------------------------------------------------

class _Sheet extends StatelessWidget {
  const _Sheet({required this.controller});
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final period = app.currentPeriod;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
            20, 10, 20, 28 + MediaQuery.of(context).padding.bottom),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Expanded(
              child: Text('Dekenadvies',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            if (period != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(app.selectedPhase.label,
                    style: const TextStyle(
                        color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
          ]),
          if (period != null) ...[
            const SizedBox(height: 4),
            Text(_periodText(app.selectedDay, app.selectedPhase),
                style: const TextStyle(color: AppColors.muted, fontSize: 14)),
          ],
          const SizedBox(height: 14),
          if (app.error != null) ...[
            _Banner(icon: Icons.cloud_off, text: app.error!),
            const SizedBox(height: 12),
          ],
          if (!app.hasChosenLocation) ...[
            _Banner(
              icon: Icons.place_outlined,
              text: 'Je ziet nu het weer voor ${app.location.name}. '
                  'Tik hier om de plaats van je stal in te stellen.',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LocationScreen())),
            ),
            const SizedBox(height: 12),
          ],
          if (app.horses.isNotEmpty && app.blankets.isEmpty) ...[
            _Banner(
              icon: Icons.checkroom,
              text: 'Leg je eigen dekens vast, dan zie je per paard precies '
                  'welke deken erop moet.',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const StableScreen(initialTab: 1))),
            ),
            const SizedBox(height: 12),
          ],
          if (app.horses.isEmpty)
            const _EmptyHorses()
          else if (period != null)
            for (final h in app.horses)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Builder(builder: (context) {
                  final a = app.adviceFor(h)!;
                  final pick = app.pickFor(h, a);
                  final has = app.hasBlanketsFor(h);
                  return AdviceCard(
                    horse: h,
                    advice: a,
                    pick: pick,
                    hasBlankets: has,
                    onTap: () => showHorseAdvice(context, h, a, period,
                        pick: pick, hasBlankets: has),
                  );
                }),
              )
          else if (app.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (period != null && app.horses.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle('Dag in het kort'),
            const SizedBox(height: 10),
            _DayOverview(app: app),
          ],
          if (period != null) ...[
            const SizedBox(height: 22),
            const _SectionTitle('Het weer'),
            const SizedBox(height: 10),
            _ConditionsGrid(w: period),
          ],
          if (app.forecast != null) ...[
            const SizedBox(height: 22),
            const _SectionTitle('Komende dagen'),
            const SizedBox(height: 10),
            _WeekList(app: app),
          ],
          const SizedBox(height: 22),
          const _Legend(),
          const SizedBox(height: 18),
          const Text(
            'Het advies is een richtlijn. Ieder paard is anders: voel regelmatig '
            'onder de deken bij de schoft of je paard het niet te warm of te koud heeft.\n'
            'Weerdata: Open-Meteo.com (CC BY 4.0)',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  static String _periodText(DateTime day, DayPhase phase) {
    String hm(int h) => '${(h % 24).toString().padLeft(2, '0')}:00';
    return '${weekdayLong[day.weekday - 1]} ${day.day} ${monthShort[day.month - 1]} · '
        '${hm(phase.startHour)} – ${hm(phase.endHour)}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800));
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3D6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF9A6B12)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ]),
      ),
    );
  }
}

class _EmptyHorses extends StatelessWidget {
  const _EmptyHorses();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          NeroMascot(size: 76),
          SizedBox(width: 10),
          Expanded(
            child: Text('Hoi, ik ben Nero!',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Ik houd de wei warm tot jouw paarden er zijn. Voeg je paard toe met '
          'vachtkleur, aftekeningen, of het geschoren is en waar het staat. '
          'Dan zie je het hierboven grazen en krijg je dekenadvies.',
          style: TextStyle(color: AppColors.muted, height: 1.35),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const HorseFormScreen())),
          icon: const Icon(Icons.add),
          label: const Text('Paard toevoegen'),
        ),
      ]),
    );
  }
}

class _ConditionsGrid extends StatelessWidget {
  const _ConditionsGrid({required this.w});
  final PeriodWeather w;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Condition(
        icon: Icons.thermostat,
        tint: const Color(0xFFFFE9B8),
        label: 'Temperatuur',
        value: '${w.minTemp.round()}° / ${w.maxTemp.round()}°',
        sub: 'gevoel tot ${w.minFeels.round()}°',
      ),
      _Condition(
        icon: Icons.air,
        tint: const Color(0xFFDCEBDC),
        label: 'Wind',
        value: '${w.maxWind.round()} km/u',
        sub: _beaufort(w.maxWind),
      ),
      _Condition(
        icon: Icons.umbrella,
        tint: const Color(0xFFD9E9F5),
        label: 'Neerslag',
        value: '${w.totalPrecip.toStringAsFixed(1)} mm',
        sub: '${w.maxPrecipProb}% kans',
      ),
      _Condition(
        icon: Icons.water_drop,
        tint: const Color(0xFFE3E0F3),
        label: 'Luchtvochtigheid',
        value: '${w.avgHumidity}%',
        sub: w.avgHumidity >= 90 ? 'klam en vochtig' : 'gemiddeld',
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 560 ? 4 : 2;
      const gap = 10.0;
      final width = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final card in cards) SizedBox(width: width, child: card)],
      );
    });
  }

  static String _beaufort(double kmh) {
    if (kmh < 12) return 'zwak';
    if (kmh < 20) return 'matig';
    if (kmh < 29) return 'vrij krachtig';
    if (kmh < 39) return 'krachtig';
    if (kmh < 50) return 'hard';
    return 'stormachtig';
  }
}

class _Condition extends StatelessWidget {
  const _Condition({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.sub,
  });
  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ]),
    );
  }
}

/// Per paard de deken voor ochtend, middag en avond van de gekozen dag.
class _DayOverview extends StatelessWidget {
  const _DayOverview({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final periods = {
      for (final p in DayPhase.values) p: app.periodFor(app.selectedDay, p),
    };
    Widget cell(DayPhase p, Widget child) => GestureDetector(
          onTap: () => app.selectPhase(p),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: p == app.selectedPhase
                  ? AppColors.green.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: child),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(children: [
        Row(children: [
          const Spacer(),
          for (final p in DayPhase.values)
            cell(
              p,
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(p.icon,
                    size: 18,
                    color: p == app.selectedPhase ? AppColors.green : AppColors.muted),
                if (app.anyInside(app.selectedDay, p))
                  const Icon(Icons.house_siding, size: 13, color: AppColors.muted),
              ]),
            ),
        ]),
        for (final h in app.horses) ...[
          const Divider(height: 10, color: AppColors.line),
          Row(children: [
            Container(
              width: 44,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F0DC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: HorseAvatar(
                  look: HorseLook.of(h, app.adviceFor(h), app.pickFor(h, app.adviceFor(h))),
                  size: 38),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(h.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            for (final p in DayPhase.values)
              cell(
                p,
                periods[p] == null
                    ? const Text('–')
                    : BlanketBadge(app.adviceAt(h, app.selectedDay, p)!.level),
              ),
          ]),
        ],
      ]),
    );
  }
}

class _WeekList extends StatelessWidget {
  const _WeekList({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final horse = app.focusHorse;
    final days = app.stripDays;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (app.horses.length > 1) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final h in app.horses)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(h.name),
                  selected: h.id == horse?.id,
                  onSelected: (_) => app.setFocusHorse(h.id),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(children: [
          if (horse != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(children: [
                const Spacer(),
                for (final p in DayPhase.values)
                  SizedBox(
                      width: 22,
                      child: Icon(p.icon, size: 14, color: AppColors.muted)),
              ]),
            ),
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14, color: AppColors.line),
            _DayRow(day: days[i], horse: horse, app: app, isToday: i == 0),
          ],
        ]),
      ),
    ]);
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.horse,
    required this.app,
    required this.isToday,
  });
  final DayWeather day;
  final Horse? horse;
  final AppState app;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final name = isToday ? 'Vandaag' : weekdayLong[day.date.weekday - 1];
    final selected = dateOnly(day.date) == app.selectedDay;

    return Material(
      color: selected ? AppColors.green.withValues(alpha: 0.08) : Colors.transparent,
      child: InkWell(
      onTap: () => app.selectDay(day.date),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name[0].toUpperCase() + name.substring(1),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${day.precipProb}% · ${day.precipSum.toStringAsFixed(1)} mm',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
          ),
          Icon(iconForKind(kindForCode(day.code)), size: 20, color: const Color(0xFF7C8A7E)),
          SizedBox(
            width: 66,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '${day.tMin.round()}°',
                    style: const TextStyle(color: AppColors.muted)),
                const TextSpan(text: ' / '),
                TextSpan(
                    text: '${day.tMax.round()}°',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          // per fase een gekleurd bolletje met het dekengewicht
          if (horse != null)
            for (final p in DayPhase.values)
              SizedBox(
                width: 22,
                child: Center(
                  child: Builder(builder: (context) {
                    final w = app.periodFor(day.date, p);
                    final level =
                        w == null ? null : app.adviceAt(horse!, day.date, p)!.level;
                    return Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: level?.color ?? AppColors.line,
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ),
        ]),
      ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final l in BlanketLevel.values)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: l.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              l == BlanketLevel.none ? l.label : '${l.label} (${l.grams})',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ]),
      ],
    );
  }
}
