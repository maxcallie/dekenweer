import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../ui.dart';
import '../widgets/nero.dart';
import 'advice_settings_screen.dart';
import 'care_screen.dart';
import 'location_screen.dart';
import 'season_screen.dart';
import 'stable_screen.dart';

/// Tab "Instellingen": locatie, dekenadvies, seizoenen en zorg.
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final season = app.seasons.seasonOf(DateTime.now());
    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return LargeTitlePage(
      title: 'Instellingen',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          sliver: SliverList.list(children: [
            _Group(children: [
              _Row(
                icon: Icons.place,
                title: 'Locatie van de stal',
                subtitle: app.hasChosenLocation
                    ? app.location.name
                    : '${app.location.name} (nog niet gekozen)',
                onTap: () => open(const LocationScreen()),
              ),
            ]),
            const SizedBox(height: 16),
            _Group(children: [
              _Row(
                icon: Icons.thermostat,
                title: 'Dekenadvies',
                subtitle: 'Grenzen per scheersel, wind, regen en stal',
                onTap: () => open(const AdviceSettingsScreen()),
              ),
              _Row(
                icon: Icons.calendar_month,
                title: 'Seizoenen en stalschema',
                subtitle: 'Nu: ${season.label.toLowerCase()}seizoen',
                onTap: () => open(const SeasonScreen()),
              ),
              _Row(
                icon: Icons.vaccines,
                title: 'Zorg',
                subtitle: 'Vaccins, ontwormgrens en herinneringen',
                onTap: () => open(const CareSettingsScreen()),
              ),
            ]),
            const SizedBox(height: 28),
            const Center(child: NeroMascot(size: 72)),
            const SizedBox(height: 8),
            const Text(
              'Dekenweer · met Nero als mascotte\nWeerdata: Open-Meteo.com (CC BY 4.0)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.45),
            ),
          ]),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 60, color: AppColors.line),
            children[i],
          ],
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ]),
          ),
        ),
      );
}
