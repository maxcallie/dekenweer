import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/blanket_advisor.dart';
import '../models/horse.dart';
import '../ui.dart';
import 'share_screen.dart';
import '../widgets/horse_painter.dart';

/// Paard toevoegen of bewerken.
class HorseFormScreen extends StatefulWidget {
  const HorseFormScreen({super.key, this.horse});
  final Horse? horse;

  @override
  State<HorseFormScreen> createState() => _HorseFormScreenState();
}

class _HorseFormScreenState extends State<HorseFormScreen> {
  late final Horse h;
  late final TextEditingController _name;
  late final TextEditingController _age;
  bool get _isNew => widget.horse == null;
  bool _showLeft = false;

  @override
  void initState() {
    super.initState();
    h = widget.horse?.copy() ??
        Horse(id: DateTime.now().microsecondsSinceEpoch.toString(), name: '');
    _name = TextEditingController(text: h.name);
    _age = TextEditingController(text: _isNew ? '' : '${h.age}');
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geef je paard een naam')));
      return;
    }
    final wasNero = widget.horse?.blindLeftEye ?? false;
    h.name = name;
    h.age = int.tryParse(_age.text.trim()) ?? h.age;
    final messenger = ScaffoldMessenger.of(context);
    await AppScope.read(context).saveHorse(h);
    if (h.blindLeftEye && !wasNero) {
      // easter egg
      messenger.showSnackBar(const SnackBar(
        duration: Duration(seconds: 5),
        content: Text('Hoi Nero! Kijk maar eens goed naar zijn linkeroog 💛'),
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('${h.name} verwijderen?'),
        content: const Text('Dit kun je niet ongedaan maken.'),
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
    await AppScope.read(context).deleteHorse(h.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nieuw paard' : h.name,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: '${h.name} delen',
              onPressed: () => showShareHorseSheet(context, widget.horse!),
              icon: const Icon(Icons.ios_share),
            ),
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
          // Live voorbeeld
          Container(
            height: 170,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFCDEBF7), Color(0xFFCDEBF7), Color(0xFF8CC26B), Color(0xFF6FAE55)],
                stops: [0, 0.6, 0.6, 1],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(children: [
              Center(
                child: HorseAvatar(
                  look: HorseLook(
                    coat: h.coat,
                    blanketColor: h.blanketColor,
                    level: BlanketLevel.rainSheet,
                    blaze: h.blaze,
                    legs: h.legs,
                  ),
                  size: 165,
                  leftSide: _showLeft,
                ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: IconButton.filledTonal(
                  tooltip: 'Andere kant bekijken',
                  onPressed: () => setState(() => _showLeft = !_showLeft),
                  icon: const Icon(Icons.flip),
                ),
              ),
              Positioned(
                left: 14,
                top: 10,
                child: Text(_showLeft ? 'Linkerkant' : 'Rechterkant',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted)),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Naam'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _age,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Leeftijd (jaren)'),
          ),
          _Section(
            title: 'Vachtkleur',
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in CoatColor.values)
                ChoiceChip(
                  avatar: CircleAvatar(backgroundColor: c.body, radius: 8),
                  label: Text(c.label),
                  selected: h.coat == c,
                  onSelected: (_) => setState(() => h.coat = c),
                ),
            ]),
          ),
          _Section(
            title: 'Aftekeningen',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Hoofd', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final b in Blaze.values)
                  ChoiceChip(
                    label: Text(b.label),
                    selected: h.blaze == b,
                    onSelected: (_) => setState(() => h.blaze = b),
                  ),
              ]),
              const SizedBox(height: 14),
              const Text('Witte benen', style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 4),
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Expanded(
                      child: Text(legNames[i],
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    SegmentedButton<LegMark>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      segments: [
                        for (final v in LegMark.values)
                          ButtonSegment(value: v, label: Text(v.label)),
                      ],
                      selected: {h.legs[i]},
                      onSelectionChanged: (sel) => setState(() {
                        final legs = List<LegMark>.of(h.legs);
                        legs[i] = sel.first;
                        h.legs = legs;
                        // laat zien aan welke kant het been zit
                        _showLeft = i.isEven;
                      }),
                    ),
                  ]),
                ),
            ]),
          ),
          _Section(
            title: 'Standaardkleur deken',
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              for (final c in blanketColors)
                GestureDetector(
                  onTap: () => setState(() => h.blanketColorValue = c.toARGB32()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: h.blanketColorValue == c.toARGB32()
                            ? AppColors.ink
                            : Colors.white,
                        width: 3,
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          _Section(
            title: 'Type',
            child: _Choices<HorseType>(
              values: HorseType.values,
              selected: h.type,
              label: (v) => v.label,
              hint: (v) => v.hint,
              onChanged: (v) => setState(() => h.type = v),
            ),
          ),
          _Section(
            title: 'Geschoren?',
            child: _Choices<ClipType>(
              values: ClipType.values,
              selected: h.clip,
              label: (v) => v.label,
              onChanged: (v) => setState(() => h.clip = v),
            ),
          ),
          _Section(
            title: 'Waar staat je paard?',
            child: _Choices<Housing>(
              values: Housing.values,
              selected: h.housing,
              label: (v) => v.label,
              hint: (v) => v.hint,
              onChanged: (v) => setState(() => h.housing = v),
            ),
          ),
          if (h.housing == Housing.schedule)
            Builder(builder: (context) {
              final app = AppScope.of(context);
              final mine = app.blankets.where((b) => b.fits(h.id)).toList()
                ..sort((a, b) => a.grams.compareTo(b.grams));
              final ids = <String?>[null, Horse.noBlanket, for (final b in mine) b.id];
              // een gekozen deken die niet meer bestaat → terug naar automatisch
              final selected = ids.contains(h.stableBlanket) ? h.stableBlanket : null;
              String label(String? id) {
                if (id == null) return 'Automatisch';
                if (id == Horse.noBlanket) return 'Geen deken';
                return mine.firstWhere((b) => b.id == id).name;
              }

              String hint(String? id) {
                if (id == null) return 'Volgens het advies (staldeken als die er is)';
                if (id == Horse.noBlanket) return 'Op stal altijd zonder deken';
                return mine.firstWhere((b) => b.id == id).details;
              }

              return _Section(
                title: 'Deken op stal',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Choices<String?>(
                    values: ids,
                    selected: selected,
                    label: label,
                    hint: hint,
                    onChanged: (v) => setState(() => h.stableBlanket = v),
                  ),
                  if (mine.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Leg je dekens vast onder Mijn stal → Dekens om hier een vaste '
                        'deken te kiezen.',
                        style: TextStyle(fontSize: 13, color: AppColors.muted),
                      ),
                    ),
                ]),
              );
            }),
          _Section(
            title: 'Conditie',
            child: _Choices<BodyCondition>(
              values: BodyCondition.values,
              selected: h.condition,
              label: (v) => v.label,
              onChanged: (v) => setState(() => h.condition = v),
            ),
          ),
          _Section(
            title: 'Hoe ervaart je paard kou?',
            child: _Choices<Sensitivity>(
              values: Sensitivity.values,
              selected: h.sensitivity,
              label: (v) => v.label,
              onChanged: (v) => setState(() => h.sensitivity = v),
            ),
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
            child: Text(_isNew ? 'Paard toevoegen' : 'Opslaan',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
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

/// Lijst met keuzes als nette kaartjes (één kolom).
class _Choices<T> extends StatelessWidget {
  const _Choices({
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.hint,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final String Function(T)? hint;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const Divider(height: 1, color: AppColors.line),
          InkWell(
            onTap: () => onChanged(values[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label(values[i]),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    if (hint != null)
                      Text(hint!(values[i]),
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                Icon(
                  values[i] == selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: values[i] == selected ? AppColors.green : AppColors.line,
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}
