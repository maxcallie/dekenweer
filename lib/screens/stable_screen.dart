import 'package:flutter/material.dart';

import '../models/blanket.dart';
import '../models/horse.dart';
import '../ui.dart';
import '../widgets/advice_widgets.dart';
import '../widgets/horse_painter.dart';
import '../widgets/horseshoe_icon.dart';
import '../widgets/nero.dart';
import 'advice_settings_screen.dart';
import 'blanket_form_screen.dart';
import 'horse_form_screen.dart';
import 'season_screen.dart';

/// "Mijn stal": je paarden en je dekenkast.
class StableScreen extends StatefulWidget {
  const StableScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<StableScreen> createState() => _StableScreenState();
}

class _StableScreenState extends State<StableScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this, initialIndex: widget.initialTab)
        ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onHorses = _tabs.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn stal', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Seizoenen & stalschema',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SeasonScreen())),
          ),
          IconButton(
            tooltip: 'Adviesinstellingen',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdviceSettingsScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          tabs: const [
            Tab(icon: HorseshoeIcon(size: 24), text: 'Paarden'),
            Tab(icon: Icon(Icons.checkroom), text: 'Dekens'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                onHorses ? const HorseFormScreen() : const BlanketFormScreen())),
        icon: const Icon(Icons.add),
        label: Text(onHorses ? 'Paard toevoegen' : 'Deken toevoegen'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_HorsesList(), _BlanketsList()],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const NeroMascot(size: 110),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 15, height: 1.4)),
          ]),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.leading, required this.title, required this.subtitle,
      this.trailing, required this.onTap});
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35)),
              ]),
            ),
            if (trailing != null) trailing!,
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

class _HorsesList extends StatelessWidget {
  const _HorsesList();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.horses.isEmpty) {
      return const _Empty('Je hebt nog geen paarden toegevoegd.\n'
          'Tik op "Paard toevoegen" om te beginnen.');
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: app.horses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final h = app.horses[i];
        final a = app.adviceFor(h);
        return _Tile(
          leading: Container(
            width: 72,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F0DC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: HorseAvatar(look: HorseLook.of(h, a, app.pickFor(h, a)), size: 64),
          ),
          title: h.name,
          subtitle: '${h.coat.label} · ${h.type.label} · ${h.age} jaar\n'
              '${h.clip.label} · ${h.housing.label.toLowerCase()}',
          trailing: a != null ? BlanketBadge(a.level) : null,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => HorseFormScreen(horse: h))),
        );
      },
    );
  }
}

class _BlanketsList extends StatelessWidget {
  const _BlanketsList();

  String _forWhom(Blanket b, List<Horse> horses) {
    if (b.horseIds.isEmpty) return 'Alle paarden';
    final names = [
      for (final h in horses)
        if (b.horseIds.contains(h.id)) h.name,
    ];
    return names.isEmpty ? 'Geen paard gekozen' : names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.blankets.isEmpty) {
      return const _Empty('Je dekenkast is nog leeg.\n\n'
          'Voeg je dekens toe (regendeken, buitendeken, staldeken, onderdeken…) '
          'met hun vulling in gram. Dan zegt het advies precies welke deken '
          'erop moet, en draagt je paard in de wei die deken.');
    }
    // Sorteer: eerst warmtedekens op gewicht, dan de rest.
    final list = app.blankets.toList()
      ..sort((a, b) {
        final k = a.kind.index.compareTo(b.kind.index);
        return k != 0 ? k : a.grams.compareTo(b.grams);
      });
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final b = list[i];
        return _Tile(
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: b.color, borderRadius: BorderRadius.circular(16)),
            child: Icon(b.kind.icon, color: Colors.white),
          ),
          title: b.name,
          subtitle: '${b.details}\n${_forWhom(b, app.horses)}',
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => BlanketFormScreen(blanket: b))),
        );
      },
    );
  }
}
