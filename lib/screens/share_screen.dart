import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/horse.dart';
import '../services/web_bridge.dart' as web;
import '../state/app_state.dart';
import '../ui.dart';
import '../widgets/horse_painter.dart';
import 'root_shell.dart';

// ---------------------------------------------------------------------------
// Versturen
// ---------------------------------------------------------------------------

/// Deel [horse] (met dekens, zorg en seizoenen) via het deelmenu van de
/// telefoon, bijv. WhatsApp.
Future<void> showShareHorseSheet(BuildContext context, Horse horse) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    showDragHandle: true,
    builder: (_) => _ShareSheet(horse: horse),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.horse});
  final Horse horse;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _blankets = true;
  bool _care = true;
  bool _seasons = true;
  bool _advice = false;

  HorsePackage _package(AppState app) => app.packageFor(widget.horse,
      blankets: _blankets, care: _care, seasons: _seasons, advice: _advice);

  String _link(AppState app) => _package(app).link(Uri.base);

  void _share(AppState app) {
    final h = widget.horse;
    final url = _link(app);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    // Het deelmenu moet direct vanuit de tik geopend worden (geen await ervoor).
    web
        .shareLink(
          '${h.name} in Dekenweer',
          'Hier is ${h.name} voor Dekenweer 🐴 Open de link om ${h.name} '
              'met dekens en zorg toe te voegen.',
          url,
        )
        .then((ok) async {
      if (!ok) {
        await Clipboard.setData(ClipboardData(text: url));
        messenger.showSnackBar(const SnackBar(
            content: Text('Link gekopieerd. Plak hem in WhatsApp of een bericht.')));
      }
      if (nav.mounted) nav.pop();
    });
  }

  Future<void> _copy(AppState app) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _link(app)));
    messenger.showSnackBar(const SnackBar(content: Text('Link gekopieerd')));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final h = widget.horse;
    final all = app.packageFor(h);
    final nBlankets = all.blankets.length;
    final nCare = all.care.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${h.name} delen',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'De ander krijgt een link en kan ${h.name} met één tik toevoegen aan '
            'de eigen app. Deel je later opnieuw, dan wordt het bijgewerkt.',
            style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(children: [
              _Toggle(
                icon: Icons.checkroom,
                title: 'Dekens',
                subtitle: nBlankets == 0
                    ? 'Geen dekens voor ${h.name}'
                    : '$nBlankets ${nBlankets == 1 ? 'deken' : 'dekens'} van ${h.name}',
                value: _blankets && nBlankets > 0,
                onChanged: nBlankets == 0 ? null : (v) => setState(() => _blankets = v),
              ),
              const Divider(height: 1, color: AppColors.line),
              _Toggle(
                icon: Icons.vaccines,
                title: 'Zorg',
                subtitle: nCare == 0
                    ? 'Nog geen vaccinaties of kuren'
                    : '$nCare ${nCare == 1 ? 'registratie' : 'registraties'} '
                        '(vaccinaties, kuren, mestonderzoek)',
                value: _care && nCare > 0,
                onChanged: nCare == 0 ? null : (v) => setState(() => _care = v),
              ),
              const Divider(height: 1, color: AppColors.line),
              _Toggle(
                icon: Icons.calendar_month,
                title: 'Seizoenen en stalschema',
                subtitle: 'Wanneer de paarden binnen of buiten staan',
                value: _seasons,
                onChanged: (v) => setState(() => _seasons = v),
              ),
              const Divider(height: 1, color: AppColors.line),
              _Toggle(
                icon: Icons.thermostat,
                title: 'Adviesgrenzen',
                subtitle: 'Jouw eigen instellingen voor het dekenadvies',
                value: _advice,
                onChanged: (v) => setState(() => _advice = v),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: () => _share(app),
            icon: const Icon(Icons.ios_share),
            label: const Text('Delen via WhatsApp of berichten',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: () => _copy(app),
              icon: const Icon(Icons.link),
              label: const Text('Alleen de link kopiëren'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        secondary: Icon(icon, color: AppColors.green),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      );
}

// ---------------------------------------------------------------------------
// Ontvangen
// ---------------------------------------------------------------------------

/// Kijkt bij het opstarten of de app via een deel-link geopend is.
void handleIncomingLink(BuildContext context) {
  final code = Uri.base.queryParameters[HorsePackage.linkParam];
  if (code == null) return;
  web.clearQuery();
  final p = HorsePackage.decode('?${HorsePackage.linkParam}=$code');
  if (p == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Deze link kon niet gelezen worden. Vraag of hij opnieuw '
            'gedeeld kan worden.')));
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ImportHorseScreen(package: p, fromLink: true)));
}

/// Paard ontvangen door een link of code te plakken.
class ReceiveHorseScreen extends StatefulWidget {
  const ReceiveHorseScreen({super.key});

  @override
  State<ReceiveHorseScreen> createState() => _ReceiveHorseScreenState();
}

class _ReceiveHorseScreenState extends State<ReceiveHorseScreen> {
  final _ctrl = TextEditingController();
  HorsePackage? _found;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _check() => setState(() => _found = HorsePackage.decode(_ctrl.text));

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    _ctrl.text = data?.text ?? '';
    _check();
    if (_found == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Geen paard gevonden in wat je gekopieerd hebt.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _found;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paard ontvangen', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          const Text(
            'Heeft iemand een paard met je gedeeld? Houd de link in WhatsApp '
            'ingedrukt, kies "Kopieer" en plak hem hier.',
            style: TextStyle(fontSize: 15, color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _paste,
            icon: const Icon(Icons.content_paste),
            label: const Text('Plakken', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => _check(),
            decoration: const InputDecoration(hintText: 'of plak de link hier zelf'),
          ),
          if (p != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => ImportHorseScreen(package: p))),
              child: Text('${p.horse.name} bekijken',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ] else if (_ctrl.text.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text('Hier staat (nog) geen geldige deel-link in.',
                style: TextStyle(color: Color(0xFFC8442F))),
          ],
        ],
      ),
    );
  }
}

/// Voorbeeld van een ontvangen paard, met de knop om het toe te voegen.
class ImportHorseScreen extends StatefulWidget {
  const ImportHorseScreen({super.key, required this.package, this.fromLink = false});
  final HorsePackage package;

  /// Geopend via een link (en dus misschien in Safari i.p.v. de app).
  final bool fromLink;

  @override
  State<ImportHorseScreen> createState() => _ImportHorseScreenState();
}

class _ImportHorseScreenState extends State<ImportHorseScreen> {
  bool _seasons = true;
  bool _advice = true;
  bool _busy = false;

  Future<void> _import() async {
    setState(() => _busy = true);
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final p = widget.package;
    final existed = app.horseById(p.horse.id) != null;
    await app.importPackage(p, withSeasons: _seasons, withAdvice: _advice);
    messenger.showSnackBar(SnackBar(
        content: Text(existed
            ? '${p.horse.name} is bijgewerkt'
            : '${p.horse.name} staat nu bij je paarden')));
    nav.pop();
    RootShell.go(AppTab.paarden);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = widget.package;
    final h = p.horse;
    final existing = app.horseById(h.id) != null;
    final inSafari = widget.fromLink && !web.isStandalone();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paard ontvangen', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          if (inSafari) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3D6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Gebruik je Dekenweer vanaf je beginscherm?',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Deze link is in Safari geopend, en Safari bewaart zijn gegevens '
                  'los van de app. Kopieer de link, open Dekenweer vanaf je '
                  'beginscherm en kies Paarden → Paard ontvangen.',
                  style: TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: p.link(Uri.base)));
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Gekopieerd. Open nu de app op je beginscherm.')));
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Link kopiëren'),
                ),
              ]),
            ),
            const SizedBox(height: 14),
          ],
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
            child: Center(child: HorseAvatar(look: HorseLook.of(h), size: 160)),
          ),
          const SizedBox(height: 14),
          Text(h.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          Text('${h.coat.label} · ${h.type.label} · ${h.age} jaar',
              style: const TextStyle(fontSize: 15, color: AppColors.muted)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(children: [
              _Included(
                icon: Icons.checkroom,
                text: p.blankets.isEmpty
                    ? 'Geen dekens'
                    : '${p.blankets.length} ${p.blankets.length == 1 ? 'deken' : 'dekens'}: '
                        '${p.blankets.map((b) => b.name).join(', ')}',
              ),
              const Divider(height: 1, color: AppColors.line),
              _Included(
                icon: Icons.vaccines,
                text: p.care.isEmpty
                    ? 'Geen zorgregistraties'
                    : '${p.care.length} zorgregistraties (vaccinaties, kuren, mestonderzoek)',
              ),
              if (p.seasons != null) ...[
                const Divider(height: 1, color: AppColors.line),
                SwitchListTile(
                  secondary: const Icon(Icons.calendar_month, color: AppColors.green),
                  title: const Text('Seizoenen en stalschema overnemen'),
                  subtitle: Text('Zomer vanaf ${p.seasons!.startLabel(Season.summer)}, '
                      'winter vanaf ${p.seasons!.startLabel(Season.winter)}'),
                  value: _seasons,
                  onChanged: (v) => setState(() => _seasons = v),
                ),
              ],
              if (p.advice != null) ...[
                const Divider(height: 1, color: AppColors.line),
                SwitchListTile(
                  secondary: const Icon(Icons.thermostat, color: AppColors.green),
                  title: const Text('Adviesgrenzen overnemen'),
                  subtitle: const Text('Vervangt je eigen instellingen voor het dekenadvies'),
                  value: _advice,
                  onChanged: (v) => setState(() => _advice = v),
                ),
              ],
            ]),
          ),
          if (existing) ...[
            const SizedBox(height: 12),
            Text(
              'Je hebt ${h.name} al. Zijn gegevens, dekens en zorg worden bijgewerkt '
              'met deze versie.',
              style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
            ),
          ],
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
            onPressed: _busy ? null : _import,
            child: Text(existing ? '${h.name} bijwerken' : 'Toevoegen aan mijn paarden',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

class _Included extends StatelessWidget {
  const _Included({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.green),
        title: Text(text, style: const TextStyle(fontSize: 14.5)),
      );
}
