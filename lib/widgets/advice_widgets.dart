import 'package:flutter/material.dart';

import '../logic/blanket_advisor.dart';
import '../logic/blanket_picker.dart';
import '../models/horse.dart';
import '../models/weather.dart';
import '../screens/horse_form_screen.dart';
import '../screens/stable_screen.dart';
import '../ui.dart';
import 'horse_painter.dart';
import 'nero.dart';

String shortGrams(BlanketLevel l) => switch (l) {
      BlanketLevel.none => 'geen',
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
      subtitle = '${level.label} · ${p.grams} g'
          '${p.matches ? '' : p.offset < 0 ? ' · iets lichter dan advies' : ' · iets zwaarder dan advies'}';
    } else if (level.wearsBlanket && hasBlankets) {
      title = advice.title;
      subtitle = '${level.grams} · geen passende deken in je dekenkast';
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
          _InfoRow(
            icon: Icons.thermostat,
            text: 'Uitgangspunt ${advice.baseTemp.round()}°C → voor ${horse.name} '
                'voelt het als ${advice.effectiveTemp.round()}°C',
          ),
          const SizedBox(height: 12),
          if (advice.reasons.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in advice.reasons)
                  Chip(
                    label: Text(r),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.card,
                  ),
              ],
            ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: AppColors.green),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35))),
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
                : p.matches
                ? 'Past binnen het advies (${level.grams}).'
                : 'Dit is de best passende deken die je hebt; het advies is ${level.grams}.',
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        ] else ...[
          Text(
            hasBlankets
                ? 'Geen van je dekens past bij dit advies'
                    '${advice.waterproof ? ' (buiten is een waterdichte deken nodig)' : ''}.'
                : 'Leg je eigen dekens vast, dan zie je hier precies welke deken erop moet.',
            style: const TextStyle(fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(MaterialPageRoute(
                  builder: (_) => const StableScreen(initialTab: 1)));
            },
            icon: const Icon(Icons.checkroom),
            label: const Text('Naar mijn dekens'),
          ),
        ],
      ]),
    );
  }
}
