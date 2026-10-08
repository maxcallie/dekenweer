import 'package:flutter/material.dart';

import '../models/blanket.dart';
import '../models/horse.dart';
import '../ui.dart';
import '../widgets/advice_widgets.dart';
import '../widgets/horse_painter.dart';
import '../widgets/nero.dart';
import 'blanket_form_screen.dart';
import 'horse_form_screen.dart';
import 'share_screen.dart';

/// Een tab met een grote titel bovenaan die bij het scrollen kleiner wordt
/// (zoals in iOS-apps), en optioneel een knop rechtsonder.
class LargeTitlePage extends StatelessWidget {
  const LargeTitlePage({
    super.key,
    required this.title,
    required this.slivers,
    this.fab,
    this.actions = const [],
  });

  final String title;
  final List<Widget> slivers;
  final Widget? fab;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: fab,
      body: CustomScrollView(slivers: [
        SliverAppBar.large(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: actions,
        ),
        ...slivers,
      ]),
    );
  }
}

/// Tab "Paarden".
class HorsesTab extends StatelessWidget {
  const HorsesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return LargeTitlePage(
      title: 'Paarden',
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const ReceiveHorseScreen())),
          icon: const Icon(Icons.move_to_inbox),
          label: const Text('Ontvangen'),
        ),
        const SizedBox(width: 8),
      ],
      fab: FloatingActionButton.extended(
        heroTag: 'fab-paarden',
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const HorseFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Paard toevoegen'),
      ),
      slivers: const [_HorsesList()],
    );
  }
}

/// Tab "Dekens".
class BlanketsTab extends StatelessWidget {
  const BlanketsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return LargeTitlePage(
      title: 'Dekens',
      fab: FloatingActionButton.extended(
        heroTag: 'fab-dekens',
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const BlanketFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Deken toevoegen'),
      ),
      slivers: const [_BlanketsList()],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 100),
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
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _Empty('Je hebt nog geen paarden toegevoegd.\n'
            'Tik op "Paard toevoegen" om te beginnen.'),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      sliver: SliverList.separated(
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
      ),
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
      return const SliverFillRemaining(hasScrollBody: false, child: _Empty('Je dekenkast is nog leeg.\n\n'
          'Voeg je dekens toe (regendeken, buitendeken, staldeken, onderdeken…) '
          'met hun vulling in gram. Dan zegt het advies precies welke deken '
          'erop moet, en draagt je paard in de wei die deken.'));
    }
    // Sorteer: eerst warmtedekens op gewicht, dan de rest.
    final list = app.blankets.toList()
      ..sort((a, b) {
        final k = a.kind.index.compareTo(b.kind.index);
        return k != 0 ? k : a.grams.compareTo(b.grams);
      });
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      sliver: SliverList.separated(
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
      ),
    );
  }
}
