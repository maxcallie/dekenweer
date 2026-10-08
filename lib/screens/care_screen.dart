import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/horse.dart';
import '../state/app_state.dart';
import '../ui.dart';
import 'stable_screen.dart';

String formatLongDate(DateTime d) => '${d.day} ${monthShort[d.month - 1]} ${d.year}';

/// Kleur voor iets op de planning: rood = te laat of nu nodig, oranje =
/// binnenkort, groen = nog even.
Color dueColor(CareDue d, CareSettings s, DateTime now) {
  final days = d.daysFrom(now);
  if (d.urgent || days < 0) return const Color(0xFFC8442F);
  if (days <= s.remindDays) return const Color(0xFFE0A21E);
  return AppColors.green;
}

String dueText(CareDue d, DateTime now) =>
    d.urgent ? 'zo snel mogelijk' : dueLabel(d.daysFrom(now));

/// Begin een nieuwe registratie: kies eerst wat je wilt vastleggen.
Future<void> showRegisterSheet(BuildContext context, {String? horseId}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.cream,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Wat wil je registreren?',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          for (final k in CareKind.values) ...[
            _KindButton(
              kind: k,
              onTap: () {
                Navigator.of(sheet).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CareFormScreen(
                        kind: k, horseIds: horseId == null ? null : [horseId])));
              },
            ),
            const SizedBox(height: 8),
          ],
        ]),
      ),
    ),
  );
}

class _KindButton extends StatelessWidget {
  const _KindButton({required this.kind, required this.onTap});
  final CareKind kind;
  final VoidCallback onTap;

  String get _hint => switch (kind) {
        CareKind.vaccination => 'Enting door de dierenarts, met de volgende datum',
        CareKind.deworming => 'Gegeven wormenkuur, eventueel met een vast volgend moment',
        CareKind.fecalTest => 'Uitslag van de mestcontrole (eieren per gram)',
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(children: [
            _RoundIcon(icon: kind.icon, color: AppColors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(kind.label,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(_hint, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.color, this.size = 42});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(size * 0.34),
        ),
        child: Icon(icon, color: color, size: size * 0.52),
      );
}

// ---------------------------------------------------------------------------
// Overzicht (tab "Zorg" in Mijn stal)
// ---------------------------------------------------------------------------

class CareTab extends StatefulWidget {
  const CareTab({super.key});

  @override
  State<CareTab> createState() => _CareTabState();
}

class _CareTabState extends State<CareTab> {
  /// Filter op één paard (null = alle paarden).
  String? _horseId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final now = DateTime.now();
    if (app.horses.isEmpty) {
      return const LargeTitlePage(title: 'Zorg', slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(32, 16, 32, 100),
              child: Text(
                'Voeg eerst je paarden toe. Daarna kun je hier vaccinaties, '
                'wormenkuren en mestonderzoeken bijhouden.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.4),
              ),
            ),
          ),
        ),
      ]);
    }
    if (_horseId != null && app.horseById(_horseId!) == null) _horseId = null;
    bool show(String horseId) => _horseId == null || _horseId == horseId;

    final plan = app.carePlan.where((d) => show(d.horseId)).toList();
    final history = app.careRecords.where((r) => show(r.horseId)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return LargeTitlePage(
      title: 'Zorg',
      fab: FloatingActionButton.extended(
        heroTag: 'fab-zorg',
        onPressed: () => showRegisterSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Registreren'),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          sliver: SliverList.list(children: [
        if (app.horses.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Alle paarden'),
                  selected: _horseId == null,
                  onSelected: (_) => setState(() => _horseId = null),
                ),
              ),
              for (final h in app.horses)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(h.name),
                    selected: _horseId == h.id,
                    onSelected: (_) => setState(() => _horseId = h.id),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        const _Title('Op de planning'),
        const SizedBox(height: 8),
        if (plan.isEmpty)
          const _Muted('Nog niets gepland. Registreer een vaccinatie, wormenkuur of '
              'mestonderzoek; de app rekent dan uit wanneer de volgende is.')
        else
          for (final d in plan)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CareDueTile(due: d, now: now),
            ),
        const SizedBox(height: 18),
        const _Title('Geschiedenis'),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const _Muted('Nog geen registraties.')
        else
          for (final r in history)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RecordTile(record: r),
            ),
        const SizedBox(height: 14),
        Center(
          child: TextButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CareSettingsScreen())),
            icon: const Icon(Icons.tune),
            label: const Text('Vaccins en instellingen'),
          ),
        ),
          ]),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4));
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.onLongPress,
  });
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.3)),
              ]),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

/// Eén punt op de planning. Tikken opent het formulier, alvast ingevuld.
class CareDueTile extends StatelessWidget {
  const CareDueTile({super.key, required this.due, required this.now});
  final CareDue due;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final horse = app.horseById(due.horseId);
    final color = dueColor(due, app.careSettings, now);
    return _Tile(
      leading: _RoundIcon(icon: due.kind.icon, color: color),
      title: '${horse?.name ?? ''} · ${due.title}',
      subtitle: due.urgent
          ? 'Zo snel mogelijk · uitslag van ${formatLongDate(due.due)}'
          : '${_cap(dueText(due, now))} · ${formatLongDate(due.due)}',
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CareFormScreen(
          kind: due.kind,
          horseIds: [due.horseId],
          vaccineId: due.vaccineId,
          name: due.name,
        ),
      )),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});
  final CareRecord record;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final r = record;
    final horse = app.horseById(r.horseId)?.name ?? '';
    final String title;
    final parts = <String>[horse, formatLongDate(r.date)];
    switch (r.kind) {
      case CareKind.vaccination:
        title = r.name.isEmpty ? 'Vaccinatie' : r.name;
        if (r.next != null) parts.add('volgende ${formatLongDate(r.next!)}');
      case CareKind.deworming:
        title = r.name.isEmpty ? 'Wormenkuur' : 'Wormenkuur · ${r.name}';
        if (r.next != null) parts.add('volgende ${formatLongDate(r.next!)}');
      case CareKind.fecalTest:
        title = r.epg == null ? 'Mestonderzoek' : 'Mestonderzoek · ${r.epg} EPG';
        if (r.epg != null) {
          parts.add(r.epg! >= app.careSettings.epgThreshold ? 'kuur aangeraden' : 'geen kuur nodig');
        }
    }
    final high = r.kind == CareKind.fecalTest &&
        r.epg != null &&
        r.epg! >= app.careSettings.epgThreshold;
    return _Tile(
      leading: _RoundIcon(
          icon: r.kind.icon,
          color: high ? const Color(0xFFC8442F) : AppColors.muted,
          size: 38),
      title: title,
      subtitle: parts.where((p) => p.isNotEmpty).join(' · ') +
          (r.note.isEmpty ? '' : '\n${r.note}'),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => CareFormScreen(kind: r.kind, record: r))),
    );
  }
}

// ---------------------------------------------------------------------------
// Registreren / bewerken
// ---------------------------------------------------------------------------

class CareFormScreen extends StatefulWidget {
  const CareFormScreen({
    super.key,
    required this.kind,
    this.record,
    this.horseIds,
    this.vaccineId,
    this.name,
  });

  final CareKind kind;

  /// Bestaande registratie om te bewerken.
  final CareRecord? record;

  /// Voorgeselecteerde paarden (nieuwe registratie).
  final List<String>? horseIds;
  final String? vaccineId;
  final String? name;

  @override
  State<CareFormScreen> createState() => _CareFormScreenState();
}

enum _NextChoice { none, m3, m6, m12, custom }

class _CareFormScreenState extends State<CareFormScreen> {
  late final Set<String> _horses;
  late DateTime _date;
  String? _vaccineId;
  late final TextEditingController _name;
  late final TextEditingController _epg;
  late final TextEditingController _note;
  DateTime? _next;
  bool _remind = true;
  bool _nextEdited = false;
  _NextChoice _kuurNext = _NextChoice.none;
  bool _checkAfter = false;

  bool get _isNew => widget.record == null;
  CareKind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _horses = {...?widget.horseIds, if (r != null) r.horseId};
    _date = r?.date ?? dateOnly(DateTime.now());
    _vaccineId = r?.vaccineId ?? widget.vaccineId;
    _name = TextEditingController(text: r?.name ?? widget.name ?? '');
    _epg = TextEditingController(text: r?.epg?.toString() ?? '');
    _note = TextEditingController(text: r?.note ?? '');
    _checkAfter = r?.checkAfter ?? false;
    if (r != null) {
      _next = r.next;
      _remind = r.next != null;
      _nextEdited = true;
      if (kind == CareKind.deworming) {
        _kuurNext = r.next == null ? _NextChoice.none : _NextChoice.custom;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isNew && kind == CareKind.vaccination && _next == null) _recalcNext();
  }

  @override
  void dispose() {
    _name.dispose();
    _epg.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Volgende enting = datum + termijn van het gekozen vaccin.
  void _recalcNext() {
    if (_nextEdited) return;
    final v = AppScope.read(context).vaccineById(_vaccineId);
    _next = v == null ? null : addMonths(_date, v.intervalMonths);
  }

  void _setKuurNext(_NextChoice c) async {
    if (c == _NextChoice.custom) {
      final d = await _pickDate(_next ?? addMonths(_date, 6), future: true);
      if (d == null || !mounted) return;
      setState(() {
        _kuurNext = c;
        _next = d;
      });
      return;
    }
    setState(() {
      _kuurNext = c;
      _next = switch (c) {
        _NextChoice.m3 => addMonths(_date, 3),
        _NextChoice.m6 => addMonths(_date, 6),
        _NextChoice.m12 => addMonths(_date, 12),
        _ => null,
      };
    });
  }

  Future<DateTime?> _pickDate(DateTime initial, {bool future = false}) {
    final now = DateTime.now();
    final first = DateTime(now.year - 15);
    final last = DateTime(now.year + (future ? 5 : 1), 12, 31);
    return showDatePicker(
      context: context,
      // De beginwaarde moet tussen first en last liggen, anders crasht de kiezer.
      initialDate: initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial),
      firstDate: first,
      lastDate: last,
      locale: const Locale('nl'),
    );
  }

  Future<void> _addVaccine({String name = '', int months = 12}) async {
    final v = await showVaccineDialog(context, name: name, months: months);
    if (v == null || !mounted) return;
    await AppScope.read(context).saveVaccine(v);
    if (!mounted) return;
    setState(() {
      _vaccineId = v.id;
      _recalcNext();
    });
  }

  int? get _epgValue => int.tryParse(_epg.text.trim());

  Future<void> _save() async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_horses.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Kies minstens één paard')));
      return;
    }
    String name = _name.text.trim();
    if (kind == CareKind.vaccination) {
      final v = app.vaccineById(_vaccineId);
      if (v == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Kies welk vaccin')));
        return;
      }
      name = v.name;
    }
    final next = switch (kind) {
      CareKind.vaccination => _remind ? _next : null,
      CareKind.deworming => _next,
      CareKind.fecalTest => null,
    };
    final base = DateTime.now().microsecondsSinceEpoch;
    final list = <CareRecord>[];
    var i = 0;
    for (final horseId in _horses) {
      final r = widget.record?.copy() ??
          CareRecord(
            id: '${base + i++}',
            horseId: horseId,
            kind: kind,
            date: _date,
          );
      r
        ..horseId = horseId
        ..date = _date
        ..name = kind == CareKind.fecalTest ? '' : name
        ..vaccineId = kind == CareKind.vaccination ? _vaccineId : null
        ..next = next
        ..epg = kind == CareKind.fecalTest ? _epgValue : null
        ..checkAfter = kind == CareKind.deworming && _checkAfter
        ..note = _note.text.trim();
      list.add(r);
    }
    await app.saveCareRecords(list);
    if (kind == CareKind.fecalTest &&
        _epgValue != null &&
        _epgValue! >= app.careSettings.epgThreshold) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Boven de grens: een wormenkuur wordt aangeraden. '
              'Die staat nu op de planning.')));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Registratie verwijderen?'),
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
    await AppScope.read(context).deleteCareRecord(widget.record!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final horses = app.horses;
    return Scaffold(
      appBar: AppBar(
        title: Text(kind.label, style: const TextStyle(fontWeight: FontWeight.w800)),
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          _Section(
            title: _isNew ? 'Voor welke paarden?' : 'Paard',
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final Horse h in horses)
                FilterChip(
                  label: Text(h.name),
                  selected: _horses.contains(h.id),
                  onSelected: (on) => setState(() {
                    if (!_isNew) {
                      // bewerken: precies één paard
                      _horses
                        ..clear()
                        ..add(h.id);
                    } else if (on) {
                      _horses.add(h.id);
                    } else {
                      _horses.remove(h.id);
                    }
                  }),
                ),
            ]),
          ),
          _Section(
            title: 'Datum',
            child: _DateRow(
              icon: Icons.event,
              label: formatLongDate(_date),
              onTap: () async {
                final d = await _pickDate(_date);
                if (d == null || !mounted) return;
                setState(() {
                  _date = d;
                  if (kind == CareKind.vaccination) _recalcNext();
                });
                if (kind == CareKind.deworming &&
                    _kuurNext != _NextChoice.custom &&
                    _kuurNext != _NextChoice.none) {
                  _setKuurNext(_kuurNext);
                }
              },
            ),
          ),
          ...switch (kind) {
            CareKind.vaccination => _vaccinationFields(app),
            CareKind.deworming => _dewormingFields(),
            CareKind.fecalTest => _fecalFields(app),
          },
          _Section(
            title: 'Notitie',
            child: TextField(
              controller: _note,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'bijv. dierenarts, chargenummer'),
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
            child: Text(_isNew ? 'Registreren' : 'Opslaan',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  List<Widget> _vaccinationFields(AppState app) {
    final v = app.vaccineById(_vaccineId);
    return [
      _Section(
        title: 'Vaccin',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in app.vaccines)
              ChoiceChip(
                label: Text(t.name),
                selected: _vaccineId == t.id,
                onSelected: (_) => setState(() {
                  _vaccineId = t.id;
                  _nextEdited = false;
                  _recalcNext();
                }),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Nieuw vaccin'),
              onPressed: () => _addVaccine(),
            ),
          ]),
          if (app.vaccines.isEmpty) ...[
            const SizedBox(height: 12),
            const _Muted('Snel toevoegen:'),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (n, m) in vaccineSuggestions)
                ActionChip(
                  label: Text('$n · ${_months(m)}'),
                  onPressed: () => _addVaccine(name: n, months: m),
                ),
            ]),
          ],
        ]),
      ),
      if (v != null) ...[
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(children: [
            SwitchListTile(
              title: const Text('Herinnering voor de volgende'),
              subtitle: Text('Standaard na ${_months(v.intervalMonths)}'),
              value: _remind,
              onChanged: (on) => setState(() {
                _remind = on;
                // Bestaande registratie zonder volgende datum: alsnog uitrekenen.
                if (on && _next == null) {
                  _nextEdited = false;
                  _recalcNext();
                }
              }),
            ),
            if (_remind && _next != null) ...[
              const Divider(height: 1, color: AppColors.line),
              ListTile(
                leading: const Icon(Icons.update, color: AppColors.green),
                title: const Text('Volgende enting'),
                trailing: Text(formatLongDate(_next!),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () async {
                  final d = await _pickDate(_next!, future: true);
                  if (d == null || !mounted) return;
                  setState(() {
                    _next = d;
                    _nextEdited = true;
                  });
                },
              ),
            ],
          ]),
        ),
      ],
    ];
  }

  List<Widget> _dewormingFields() {
    String label(_NextChoice c) => switch (c) {
          _NextChoice.none => 'Geen vast moment',
          _NextChoice.m3 => 'Over 3 mnd',
          _NextChoice.m6 => 'Over 6 mnd',
          _NextChoice.m12 => 'Over 1 jaar',
          _NextChoice.custom =>
            _kuurNext == _NextChoice.custom && _next != null
                ? formatLongDate(_next!)
                : 'Kies datum',
        };
    return [
      _Section(
        title: 'Middel',
        child: TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'bijv. Equest Pramox (optioneel)'),
        ),
      ),
      _Section(
        title: 'Volgende vaste kuur',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in _NextChoice.values)
              ChoiceChip(
                label: Text(label(c)),
                selected: _kuurNext == c,
                onSelected: (_) => _setKuurNext(c),
              ),
          ]),
          const SizedBox(height: 6),
          const _Muted('Voor een vast moment, zoals een kuur tegen lintworm in het najaar. '
              'Werk je alleen op mestonderzoek, kies dan "Geen vast moment".'),
        ]),
      ),
      const SizedBox(height: 14),
      Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: SwitchListTile(
          title: const Text('Controle na 2 weken'),
          subtitle: const Text('Mestonderzoek om te zien of de kuur heeft gewerkt'),
          value: _checkAfter,
          onChanged: (on) => setState(() => _checkAfter = on),
        ),
      ),
    ];
  }

  List<Widget> _fecalFields(AppState app) {
    final s = app.careSettings;
    final epg = _epgValue;
    final String advice;
    final Color color;
    if (epg == null) {
      advice = 'Vul de uitslag in zodra je die hebt. Vanaf ${s.epgThreshold} '
          'eieren per gram (EPG) raadt de app een kuur aan.';
      color = AppColors.muted;
    } else if (epg >= s.epgThreshold) {
      advice = 'Boven de grens van ${s.epgThreshold} EPG: een wormenkuur wordt '
          'aangeraden. Overleg met je dierenarts welk middel.';
      color = const Color(0xFFC8442F);
    } else {
      advice = 'Onder de grens van ${s.epgThreshold} EPG: geen kuur nodig. Het volgende '
          'mestonderzoek staat rond ${formatLongDate(addMonths(_date, s.testIntervalMonths))}.';
      color = AppColors.green;
    }
    return [
      _Section(
        title: 'Uitslag',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _epg,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Eieren per gram mest (EPG)',
              hintText: 'bijv. 150',
              suffixText: 'EPG',
            ),
          ),
          const SizedBox(height: 10),
          Text(advice, style: TextStyle(fontSize: 14, color: color, height: 1.4)),
        ]),
      ),
    ];
  }
}

String _months(int m) => m % 12 == 0
    ? (m == 12 ? '1 jaar' : '${m ~/ 12} jaar')
    : (m == 1 ? '1 maand' : '$m maanden');

class _DateRow extends StatelessWidget {
  const _DateRow({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(children: [
              Icon(icon, color: AppColors.green),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
              const Icon(Icons.edit_calendar, color: AppColors.muted, size: 20),
            ]),
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Vaccins en instellingen
// ---------------------------------------------------------------------------

/// Vaccin toevoegen of bewerken (naam + termijn in maanden).
Future<VaccineType?> showVaccineDialog(BuildContext context,
    {VaccineType? vaccine, String name = '', int months = 12}) {
  final ctrl = TextEditingController(text: vaccine?.name ?? name);
  var m = vaccine?.intervalMonths ?? months;
  return showDialog<VaccineType>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setD) => AlertDialog(
        title: Text(vaccine == null ? 'Nieuw vaccin' : 'Vaccin bewerken'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            autofocus: vaccine == null && name.isEmpty,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Naam', hintText: 'bijv. Influenza'),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Expanded(child: Text('Volgende na')),
            IconButton(
              onPressed: m > 1 ? () => setD(() => m--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
                width: 84,
                child: Text(_months(m),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            IconButton(
              onPressed: m < 60 ? () => setD(() => m++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuleren')),
          FilledButton(
            onPressed: () {
              final n = ctrl.text.trim();
              if (n.isEmpty) return;
              Navigator.pop(
                c,
                VaccineType(
                  id: vaccine?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                  name: n,
                  intervalMonths: m,
                ),
              );
            },
            child: const Text('Opslaan'),
          ),
        ],
      ),
    ),
  );
}

class CareSettingsScreen extends StatelessWidget {
  const CareSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.careSettings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaccins en instellingen',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          const _Title('Mijn vaccins'),
          const SizedBox(height: 4),
          const _Muted('De termijn bepaalt wanneer de volgende enting op de planning komt.'),
          const SizedBox(height: 10),
          for (final v in app.vaccines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Tile(
                leading: const _RoundIcon(icon: Icons.vaccines, color: AppColors.green, size: 38),
                title: v.name,
                subtitle: 'Volgende na ${_months(v.intervalMonths)}',
                onTap: () async {
                  final nv = await showVaccineDialog(context, vaccine: v);
                  if (nv != null) await app.saveVaccine(nv);
                },
                onLongPress: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text('${v.name} verwijderen?'),
                      content: const Text('Eerdere registraties blijven bewaard.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Annuleren')),
                        TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('Verwijderen', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await app.deleteVaccine(v.id);
                },
              ),
            ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Nieuw vaccin'),
              onPressed: () async {
                final v = await showVaccineDialog(context);
                if (v != null) await app.saveVaccine(v);
              },
            ),
            for (final (n, m) in vaccineSuggestions)
              if (!app.vaccines.any((v) => v.name.toLowerCase() == n.toLowerCase()))
                ActionChip(
                  label: Text('$n · ${_months(m)}'),
                  onPressed: () => app.saveVaccine(VaccineType(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      name: n,
                      intervalMonths: m)),
                ),
          ]),
          if (app.vaccines.isNotEmpty) ...[
            const SizedBox(height: 6),
            const _Muted('Tik op een vaccin om het te wijzigen. Houd vast om te verwijderen.'),
          ],
          const SizedBox(height: 24),
          const _Title('Ontworming'),
          const SizedBox(height: 10),
          _StepCard(children: [
            _StepRow(
              label: 'Kuur aanraden vanaf',
              value: '${s.epgThreshold} EPG',
              onMinus: s.epgThreshold > 50
                  ? () => app.saveCareSettings(s.copyWith(epgThreshold: s.epgThreshold - 50))
                  : null,
              onPlus: s.epgThreshold < 2000
                  ? () => app.saveCareSettings(s.copyWith(epgThreshold: s.epgThreshold + 50))
                  : null,
            ),
            _StepRow(
              label: 'Volgend mestonderzoek na',
              value: _months(s.testIntervalMonths),
              onMinus: s.testIntervalMonths > 1
                  ? () => app.saveCareSettings(
                      s.copyWith(testIntervalMonths: s.testIntervalMonths - 1))
                  : null,
              onPlus: s.testIntervalMonths < 12
                  ? () => app.saveCareSettings(
                      s.copyWith(testIntervalMonths: s.testIntervalMonths + 1))
                  : null,
            ),
          ]),
          const SizedBox(height: 8),
          const _Muted('Veel dierenartsen adviseren een kuur vanaf 200 tot 250 eieren '
              'per gram. Overleg met je eigen dierenarts wat voor jouw paarden past.'),
          const SizedBox(height: 24),
          const _Title('Herinneringen'),
          const SizedBox(height: 10),
          _StepCard(children: [
            _StepRow(
              label: 'Melding vooraf',
              value: '${s.remindDays} dagen',
              onMinus: s.remindDays > 1
                  ? () => app.saveCareSettings(s.copyWith(remindDays: s.remindDays - 1))
                  : null,
              onPlus: s.remindDays < 60
                  ? () => app.saveCareSettings(s.copyWith(remindDays: s.remindDays + 1))
                  : null,
            ),
          ]),
          const SizedBox(height: 8),
          const _Muted('Zoveel dagen van tevoren verschijnt een melding bovenaan het '
              'dekenadvies op het beginscherm.'),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.line),
            children[i],
          ],
        ]),
      );
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.value, this.onMinus, this.onPlus});
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline)),
          SizedBox(
            width: 86,
            child: Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add_circle_outline)),
        ]),
      );
}
