import 'package:flutter/material.dart';

import '../logic/blanket_advisor.dart';
import '../models/blanket.dart';
import '../models/horse.dart';
import '../ui.dart';
import '../widgets/horse_painter.dart';

/// Deken toevoegen of bewerken.
class BlanketFormScreen extends StatefulWidget {
  const BlanketFormScreen({super.key, this.blanket});
  final Blanket? blanket;

  @override
  State<BlanketFormScreen> createState() => _BlanketFormScreenState();
}

class _BlanketFormScreenState extends State<BlanketFormScreen> {
  late final Blanket b;
  late final TextEditingController _name;
  bool get _isNew => widget.blanket == null;

  @override
  void initState() {
    super.initState();
    b = widget.blanket?.copy() ??
        Blanket(id: DateTime.now().microsecondsSinceEpoch.toString(), name: '');
    _name = TextEditingController(text: b.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setKind(BlanketKind k) {
    setState(() {
      // Bij een andere soort nemen we de standaardwaarden van die soort over.
      if (b.kind != k) {
        b.waterproof = k.defaultWaterproof;
        b.grams = k.defaultGrams;
      }
      b.kind = k;
    });
  }

  /// Bij welk advies past deze vulling (alleen ter info).
  String _levelHint() {
    if (!b.kind.isMain && b.kind != BlanketKind.under) {
      return 'Telt niet mee in het dekenadvies.';
    }
    if (b.kind == BlanketKind.under) {
      return 'Wordt gecombineerd met een andere deken als die alleen te licht is.';
    }
    final g = b.grams;
    final level = g == 0
        ? BlanketLevel.rainSheet
        : g <= 125
            ? BlanketLevel.light
            : g <= 225
                ? BlanketLevel.medium
                : g < 350
                    ? BlanketLevel.heavy
                    : BlanketLevel.extraHeavy;
    return 'Telt als: ${level.label.toLowerCase()} (${level.grams})'
        '${b.waterproof ? '' : ' — alleen voor op stal, want niet waterdicht'}.';
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geef de deken een naam')));
      return;
    }
    b.name = name;
    await AppScope.read(context).saveBlanket(b);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${b.name} verwijderen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuleren')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Verwijderen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AppScope.read(context).deleteBlanket(b.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final horses = AppScope.of(context).horses;
    final previewCoat = horses.isNotEmpty ? horses.first.coat : CoatColor.bay;
    final previewLevel = b.grams == 0
        ? BlanketLevel.rainSheet
        : b.grams >= 250
            ? BlanketLevel.heavy
            : BlanketLevel.medium;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nieuwe deken' : b.name,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Verwijderen',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFCDEBF7), Color(0xFFCDEBF7), Color(0xFF8CC26B), Color(0xFF6FAE55)],
                stops: [0, 0.6, 0.6, 1],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: HorseAvatar(
                look: HorseLook(
                  coat: previewCoat,
                  blanketColor: b.color,
                  level: previewLevel,
                  neckCover: b.neck,
                ),
                size: 145,
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Naam',
              hintText: 'bijv. Bucas winterdeken',
            ),
          ),
          _Section(
            title: 'Soort',
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(children: [
                for (var i = 0; i < BlanketKind.values.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.line),
                  _KindRow(
                    kind: BlanketKind.values[i],
                    selected: b.kind == BlanketKind.values[i],
                    onTap: () => _setKind(BlanketKind.values[i]),
                  ),
                ],
              ]),
            ),
          ),
          _Section(
            title: 'Vulling: ${b.grams} gram',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Slider(
                value: b.grams.toDouble(),
                min: 0,
                max: 500,
                divisions: 20,
                label: '${b.grams} g',
                onChanged: (v) => setState(() => b.grams = v.round()),
              ),
              Text(_levelHint(),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ]),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(children: [
              SwitchListTile(
                title: const Text('Waterdicht'),
                subtitle: const Text('Kan buiten in de regen'),
                value: b.waterproof,
                onChanged: (v) => setState(() => b.waterproof = v),
              ),
              const Divider(height: 1, color: AppColors.line),
              SwitchListTile(
                title: const Text('Met halsstuk'),
                subtitle: const Text('Vast of los halsstuk'),
                value: b.neck,
                onChanged: (v) => setState(() => b.neck = v),
              ),
            ]),
          ),
          _Section(
            title: 'Kleur',
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              for (final c in blanketColors)
                GestureDetector(
                  onTap: () => setState(() => b.colorValue = c.toARGB32()),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: b.colorValue == c.toARGB32() ? AppColors.ink : Colors.white,
                        width: 3,
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          if (horses.isNotEmpty)
            _Section(
              title: 'Voor welke paarden?',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final h in horses)
                    FilterChip(
                      label: Text(h.name),
                      selected: b.horseIds.contains(h.id),
                      onSelected: (on) => setState(() {
                        if (on) {
                          b.horseIds.add(h.id);
                        } else {
                          b.horseIds.remove(h.id);
                        }
                      }),
                    ),
                ]),
                const SizedBox(height: 6),
                Text(
                  b.horseIds.isEmpty
                      ? 'Niets gekozen: de deken kan voor alle paarden gebruikt worden.'
                      : 'Alleen voor de gekozen paarden.',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ]),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: _save,
            child: Text(_isNew ? 'Deken toevoegen' : 'Opslaan',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _KindRow extends StatelessWidget {
  const _KindRow({required this.kind, required this.selected, required this.onTap});
  final BlanketKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          Icon(kind.icon, color: AppColors.green, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kind.label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text(kind.hint, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: selected ? AppColors.green : AppColors.line,
          ),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}
