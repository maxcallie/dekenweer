import 'package:flutter/material.dart';

import '../logic/blanket_advisor.dart';
import '../logic/blanket_picker.dart';
import '../models/horse.dart';
import '../models/weather.dart';
import '../screens/horse_form_screen.dart';
import '../screens/root_shell.dart';
import '../ui.dart';
import 'horse_painter.dart';
import 'nero.dart';

String shortGrams(BlanketLevel l) => switch (l) {
      BlanketLevel.none => 'geen',
      BlanketLevel.flyRain => 'vlieg',
      BlanketLevel.rainSheet => '0 g',
      BlanketLevel.light => '100 g',
      BlanketLevel.medium => '200 g',
      BlanketLevel.heavy => '300 g',
      BlanketLevel.extraHeavy => '350+',
    };

/// Klein gekleurd label met het dekengewicht.
class BlanketBadge extends StatelessWidget {
  const BlanketBadge(this.level, {super.key, this.icon});
  final BlanketLevel level;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: _darker(level.color)),
          const SizedBox(width: 3),
        ],
        Text(
          shortGrams(level),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _darker(level.color),
          ),
        ),
      ]),
    );
  }
}

Color _darker(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0)).toColor();
}

/// Kaart met het advies voor één paard.
class AdviceCard extends StatelessWidget {
  const AdviceCard({
    super.key,
    required this.horse,
    required this.advice,
    this.pick,
    this.hasBlankets = false,
    this.onTap,
  });
  final Horse horse;
  final BlanketAdvice advice;

  /// De deken uit de eigen dekenkast (als die er is).
  final BlanketPick? pick;
  final bool hasBlankets;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final level = advice.level;
    final p = pick;
    final String title;
    String subtitle;
    if (advice.userChoice) {
      title = p?.label ?? 'Geen deken';
      final adv = advice.advisedLevel;
      subtitle = 'Jouw keuze voor op stal'
          '${adv != null && adv != level ? ' · advies: ${adv.label.toLowerCase()}' : ''}';
    } else if (p != null) {
      title = p.label;
      subtitle = [
        level.label,
        if (level != BlanketLevel.flyRain) '${p.grams} g',
        if (p.fitNote != null) p.fitNote!,
        if (p.warning != null) 'niet waterdicht',
      ].join(' · ');
    } else if (level.wearsBlanket && hasBlankets) {
      title = advice.title;
      subtitle = level == BlanketLevel.flyRain
          ? 'Geen vliegendeken in je dekenkast'
          : '${level.grams} · geen passende deken in je dekenkast';
    } else {
      title = advice.title;
      subtitle = advice.subtitle;
    }
    if (advice.inside && !advice.userChoice) subtitle = 'Op stal · $subtitle';
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(children: [
            Container(
              width: 74,
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F0DC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(children: [
                HorseAvatar(
                  look: HorseLook.of(horse, advice, pick),
                  size: 66,
                ),
                if (advice.inside)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: AppColors.green, shape: BoxShape.circle),
                      child: const Icon(Icons.house_siding, size: 12, color: Colors.white),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(horse.name,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, height: 1.15)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),
            Container(
              width: 10,
              height: 46,
              decoration: BoxDecoration(
                color: level.color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Uitgebreide uitleg van het advies, als bottom sheet.
Future<void> showHorseAdvice(BuildContext context, Horse horse,
    BlanketAdvice advice, PeriodWeather period,
    {BlanketPick? pick, bool hasBlankets = false}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Center(
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFDCEEF5), Color(0xFFBFDDA8)],
                  stops: [0.55, 0.56],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: HorseAvatar(look: HorseLook.of(horse, advice, pick), size: 150),
            ),
          ),
          const SizedBox(height: 16),
          Text('${horse.name} · ${period.label.toLowerCase()}',
              style: const TextStyle(color: AppColors.muted, fontSize: 14)),
          const SizedBox(height: 4),
          Text(advice.title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(advice.subtitle,
              style: const TextStyle(fontSize: 15, color: AppColors.muted)),
          if (advice.level.wearsBlanket) ...[
            const SizedBox(height: 16),
            _ClosetCard(
              advice: advice,
              pick: pick,
              hasBlankets: hasBlankets,
            ),
          ],
          const SizedBox(height: 16),
          _Explanation(horse: horse, advice: advice, pick: pick),
          const SizedBox(height: 12),
          for (final n in advice.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NeroTip(n),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute(
                  builder: (_) => HorseFormScreen(horse: horse)));
            },
            icon: const Icon(Icons.edit_outlined),
            label: Text('${horse.name} aanpassen'),
          ),
        ],
      ),
    ),
  );
}

String _signed(double v) =>
    v >= 0 ? '+${_num(v)}°' : '−${_num(-v)}°';
String _num(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
String _t(double v) => '${v.round()}°C';

/// "Zo is het advies berekend": temperatuur, alle correcties en de grens
/// waar de uitkomst in valt.
class _Explanation extends StatelessWidget {
  const _Explanation({required this.horse, required this.advice, this.pick});
  final Horse horse;
  final BlanketAdvice advice;
  final BlanketPick? pick;

  static String? _noteFor(Correction c, bool flyRain) {
    final parts = [
      if (c.rain && flyRain) 'telt niet mee voor de vliegendeken met regenstuk.',
      if (c.note != null) c.note!,
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// Waarom deze deken uit de dekenkast.
  String? _whyBlanket() {
    final p = pick;
    if (p == null || advice.userChoice || !advice.level.wearsBlanket) return null;
    final eff = _t(advice.effectiveTemp);
    final m = p.main;
    if (advice.level == BlanketLevel.flyRain) {
      return 'Gekozen: ${p.label}, je vliegendeken.';
    }
    if (p.matches) {
      if (m.hasOwnRange && p.under == null) {
        return 'Gekozen: ${p.label}. $eff ligt binnen het ingestelde bereik van '
            'deze deken (${_t(m.minTemp!)} tot ${_t(m.maxTemp!)}).';
      }
      return 'Gekozen: ${p.label}. Deze deken (${p.grams} g) hoort bij de klasse '
          '${advice.level.label.toLowerCase()}, en die past bij $eff.';
    }
    return 'Geen van je dekens past bij $eff; dichtstbijzijnde: ${p.label} '
        '(${p.fitNote}).';
  }

  /// Waarom dit niveau: in welk bereik valt de temperatuur.
  String _why(List<double> t, double nightNone) {
    final a = advice;
    final eff = a.effectiveTemp;
    final level = a.userChoice ? (a.advisedLevel ?? a.level) : a.level;
    if (level == BlanketLevel.flyRain) {
      final r = a.flyRainRange;
      final dry = a.dryTemp ?? eff;
      return 'Het regent, maar het regenstuk houdt de regen tegen. Daarom telt '
          'regen hier niet als kouder: zonder regencorrectie ${_t(dry)}'
          '${r != null ? ', tussen ${_t(r.$1)} en ${_t(r.$2)}' : ''} '
          '→ vliegendeken met regenstuk.';
    }
    final (String range, bool inRange) = switch (level) {
      BlanketLevel.none => ('vanaf ${_t(t[0])}', eff >= t[0]),
      BlanketLevel.rainSheet => ('${_t(t[1])} tot ${_t(t[0])}', eff >= t[1] && eff < t[0]),
      BlanketLevel.light => ('${_t(t[2])} tot ${_t(t[1])}', eff >= t[2] && eff < t[1]),
      BlanketLevel.medium => ('${_t(t[3])} tot ${_t(t[2])}', eff >= t[3] && eff < t[2]),
      BlanketLevel.heavy => ('${_t(t[4])} tot ${_t(t[3])}', eff >= t[4] && eff < t[3]),
      BlanketLevel.extraHeavy => ('onder ${_t(t[4])}', eff < t[4]),
      BlanketLevel.flyRain => ('', true),
    };
    final clip = horse.clip.label.toLowerCase();
    if (a.night && level == BlanketLevel.none && eff < t[0] && eff >= nightNone) {
      return "'s Nachts geen deken vanaf ${_t(nightNone)} ($clip); de berekende "
          'temperatuur is ${_t(eff)} → geen deken.';
    }
    if (inRange) {
      return '${_t(eff)} valt bij ${level.label.toLowerCase()} ($range, $clip).';
    }
    if (level == BlanketLevel.none && eff >= t[1]) {
      return '${_t(eff)} valt bij regendeken (${_t(t[1])} tot ${_t(t[0])}), maar die '
          'is ingesteld als "alleen bij nat weer" en het is droog → geen deken.';
    }
    if (level == BlanketLevel.rainSheet && eff >= t[0]) {
      return 'Een geschoren paard dat onder 16°C buiten in de regen staat, '
          'krijgt altijd iets waterdichts → regendeken.';
    }
    return '${_t(eff)} → ${level.label.toLowerCase()} ($clip).';
  }

  @override
  Widget build(BuildContext context) {
    final a = advice;
    final settings = AppScope.of(context).settings;
    final t = settings.thresholdsFor(horse.clip);
    const muted = TextStyle(fontSize: 14, color: AppColors.muted);
    const info = TextStyle(fontSize: 13, color: AppColors.muted, fontStyle: FontStyle.italic);
    const bold = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);
    Widget row(String label, String value, {TextStyle style = muted, String? note}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: style),
                if (note != null)
                  Text(note, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
            Text(value, style: style),
          ]),
        );
    final flyRain = a.level == BlanketLevel.flyRain;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.thermostat, size: 20, color: AppColors.green),
          SizedBox(width: 8),
          Text('Zo is het advies berekend',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        row('Luchttemperatuur (${a.baseLabel})', _t(a.baseTemp), style: bold),
        for (final c in a.corrections)
          row(c.label, c.info ? '(${_signed(c.delta)})' : _signed(c.delta),
              style: c.info ? info : muted,
              note: _noteFor(c, flyRain)),
        const Divider(height: 14, color: AppColors.line),
        row('Berekende temperatuur voor ${horse.name}', _t(a.effectiveTemp), style: bold),
        if (flyRain && a.dryTemp != null)
          row('Zonder regencorrectie', _t(a.dryTemp!), style: bold),
        const SizedBox(height: 8),
        Text(_why(t, settings.nightNoneFor(horse.clip)), style: const TextStyle(fontSize: 13, height: 1.35)),
        if (_whyBlanket() != null) ...[
          const SizedBox(height: 6),
          Text(_whyBlanket()!,
              style: const TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}

/// "Uit je dekenkast": welke eigen deken erop moet.
class _ClosetCard extends StatelessWidget {
  const _ClosetCard({required this.advice, required this.pick, required this.hasBlankets});
  final BlanketAdvice advice;
  final BlanketPick? pick;
  final bool hasBlankets;

  @override
  Widget build(BuildContext context) {
    final p = pick;
    final level = advice.level;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Uit je dekenkast',
            style: TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (p != null) ...[
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
              child: const Icon(Icons.checkroom, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text(
                  p.under == null
                      ? p.main.details
                      : '${p.main.grams} g + ${p.under!.grams} g = ${p.grams} g (twee lagen)',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            advice.userChoice
                ? 'Je vaste keuze voor op stal. Het advies is '
                    '${(advice.advisedLevel ?? level).label.toLowerCase()}'
                    '${(advice.advisedLevel ?? level).wearsBlanket ? ' (${(advice.advisedLevel ?? level).grams})' : ''}.'
                : level == BlanketLevel.flyRain
                ? 'Warm en nat: deze vliegendeken met regenstuk houdt de rug droog.'
                : p.matches
                ? p.main.hasOwnRange && p.under == null
                    ? 'Past binnen het eigen bereik van deze deken '
                        '(${p.main.minTemp!.round()} tot ${p.main.maxTemp!.round()}°C, '
                        'berekende temperatuur ${advice.effectiveTemp.round()}°C).'
                    : 'Past binnen het advies (${level.grams}).'
                : 'Geen van je dekens past precies; dit is de dichtstbijzijnde: '
                    '${p.fitNote}. Het advies is ${level.label.toLowerCase()} (${level.grams}).',
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
          if (p.warning != null && !advice.userChoice) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFC8553D)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(p.warning!,
                    style: const TextStyle(
                        fontSize: 13, height: 1.35, fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
          if (advice.sunnyWarm && p.main.sunProtect && !advice.userChoice) ...[
            const SizedBox(height: 6),
            const Text('Zonnig en warm: deze deken is zonwerend.',
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ] else ...[
          Text(
            hasBlankets
                ? advice.level == BlanketLevel.flyRain
                    ? 'Je hebt nog geen vliegendeken in je dekenkast. Voeg er een toe '
                        '(met regenstuk), of zet deze optie uit in de adviesinstellingen.'
                    : 'Geen van je dekens past bij dit advies'
                        '${advice.waterproof ? ' (buiten is een waterdichte deken nodig)' : ''}.'
                : 'Leg je eigen dekens vast, dan zie je hier precies welke deken erop moet.',
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () {
              Navigator.of(context).pop();
              RootShell.go(AppTab.dekens);
            },
            icon: const Icon(Icons.checkroom),
            label: const Text('Naar mijn dekens'),
          ),
        ],
      ]),
    );
  }
}
