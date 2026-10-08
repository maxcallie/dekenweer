import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../ui.dart';

/// Zomer- en winterseizoen instellen, en per fase of de paarden binnen of
/// buiten staan.
class SeasonScreen extends StatelessWidget {
  const SeasonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.seasons;
    final now = s.seasonOf(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seizoenen & stalschema',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              Icon(now == Season.summer ? Icons.wb_sunny : Icons.ac_unit,
                  color: AppColors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Nu is het ${now.label.toLowerCase()}seizoen '
                  '(sinds ${s.startLabel(now)}).',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          for (final season in Season.values) ...[
            const SizedBox(height: 18),
            _SeasonCard(season: season, app: app),
          ],
          const SizedBox(height: 16),
          const Text(
            'Staan je paarden binnen, dan rekent het advies met de stal: '
            'warmer, geen wind en geen regen, en een staldeken is genoeg. '
            'Per paard kies je welke deken het op stal krijgt (Mijn stal → paard). '
            'Paarden die op "Altijd buiten" staan, volgen dit schema niet.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({required this.season, required this.app});
  final Season season;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final s = app.seasons;
    final month = season == Season.summer ? s.summerMonth : s.winterMonth;
    final day = season == Season.summer ? s.summerDay : s.winterDay;
    final inside = s.insideIn(season);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 6),
          child: Row(children: [
            Icon(season == Season.summer ? Icons.wb_sunny : Icons.ac_unit,
                color: season == Season.summer
                    ? const Color(0xFFE0A21E)
                    : const Color(0xFF5B9BC8)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(season.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            const Text('vanaf ', style: TextStyle(color: AppColors.muted)),
            DropdownButton<int>(
              value: day,
              underline: const SizedBox.shrink(),
              items: [
                for (var d = 1; d <= 31; d++)
                  DropdownMenuItem(value: d, child: Text('$d')),
              ],
              onChanged: (d) {
                if (d != null) app.saveSeasons(s.withStart(season, month, d));
              },
            ),
            const SizedBox(width: 4),
            DropdownButton<int>(
              value: month,
              underline: const SizedBox.shrink(),
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text(monthNames[m - 1])),
              ],
              onChanged: (m) {
                if (m != null) app.saveSeasons(s.withStart(season, m, day));
              },
            ),
          ]),
        ),
        for (final p in DayPhase.values) ...[
          const Divider(height: 1, color: AppColors.line),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              Icon(p.icon, size: 20, color: AppColors.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.label,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(p.range,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.grass, size: 16), label: Text('Buiten')),
                  ButtonSegment(
                      value: true, icon: Icon(Icons.house_siding, size: 16), label: Text('Binnen')),
                ],
                selected: {inside.contains(p)},
                onSelectionChanged: (sel) =>
                    app.saveSeasons(s.withInside(season, p, sel.first)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
