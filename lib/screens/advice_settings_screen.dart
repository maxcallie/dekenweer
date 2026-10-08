import 'package:flutter/material.dart';

import '../logic/blanket_advisor.dart';
import '../models/advice_settings.dart';
import '../models/horse.dart';
import '../ui.dart';

/// Zelf de grenzen en correcties van het dekenadvies instellen.
class AdviceSettingsScreen extends StatefulWidget {
  const AdviceSettingsScreen({super.key});

  @override
  State<AdviceSettingsScreen> createState() => _AdviceSettingsScreenState();
}

class _AdviceSettingsScreenState extends State<AdviceSettingsScreen> {
  double _exampleTemp = 5;

  static const _rowLabels = [
    BlanketLevel.none,
    BlanketLevel.rainSheet,
    BlanketLevel.light,
    BlanketLevel.medium,
    BlanketLevel.heavy,
  ];

  String _deg(double v) => '${v.round()}°C';

  /// Bij droog weer heeft een ongeschoren paard geen regendeken nodig.
  BlanketLevel _exampleLevel(BlanketAdvisor advisor, ClipType clip) {
    final l = advisor.levelFor(clip, _exampleTemp);
    return clip == ClipType.none && l == BlanketLevel.rainSheet ? BlanketLevel.none : l;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;
    final advisor = BlanketAdvisor(s);
    void save(AdviceSettings n) => app.saveSettings(n);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adviesinstellingen', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: s.isDefault
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Standaard herstellen?'),
                        content: const Text(
                            'Alle grenzen en correcties gaan terug naar de standaardwaarden.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Annuleren')),
                          TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Herstellen')),
                        ],
                      ),
                    );
                    if (ok == true) save(AdviceSettings.defaults);
                  },
            child: const Text('Standaard'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          const Text(
            'Bepaal zelf vanaf welke temperatuur welke deken nodig is. Het gaat om '
            'de temperatuur zoals je paard die ervaart: na correcties voor wind, '
            'regen, stal en het paard zelf (type, leeftijd, koukleum).',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),

          // ---- Voorbeeld ------------------------------------------------
          _Card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Text('Voorbeeld',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
                Text(_deg(_exampleTemp),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
              Slider(
                value: _exampleTemp,
                min: -20,
                max: 25,
                divisions: 45,
                label: _deg(_exampleTemp),
                onChanged: (v) => setState(() => _exampleTemp = v),
              ),
              for (final clip in ClipType.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text(clip.label)),
                    _LevelLabel(_exampleLevel(advisor, clip)),
                  ]),
                ),
              const SizedBox(height: 4),
              const Text('Droog, windstil en zonder correcties voor het paard.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),

          // ---- Grenzen per scheertype -------------------------------------
          for (final clip in ClipType.values) ...[
            const SizedBox(height: 22),
            Text(clip.label,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _Card(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.line),
                  _StepRow(
                    dot: _rowLabels[i].color,
                    label: _rowLabels[i].label,
                    hint: i == 1 && clip == ClipType.none ? 'alleen bij nat weer' : null,
                    prefix: 'vanaf',
                    value: _deg(s.thresholdsFor(clip)[i]),
                    onMinus: () => save(
                        s.withThreshold(clip, i, s.thresholdsFor(clip)[i] - 1)),
                    onPlus: () => save(
                        s.withThreshold(clip, i, s.thresholdsFor(clip)[i] + 1)),
                  ),
                ],
                const Divider(height: 1, color: AppColors.line),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(children: [
                    _Dot(BlanketLevel.extraHeavy.color),
                    const SizedBox(width: 10),
                    Expanded(child: Text(BlanketLevel.extraHeavy.label)),
                    Text('onder ${_deg(s.thresholdsFor(clip)[4])}',
                        style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
          ],

          // ---- Correcties --------------------------------------------------
          const SizedBox(height: 22),
          const Text('Correcties voor het weer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Hoeveel graden het kouder (of warmer) voelt.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 10),
          _Card(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _StepRow(
                icon: Icons.air,
                label: 'Wind',
                hint: 'vanaf 20 km/u',
                value: '−${s.windModerate.round()}°',
                onMinus: () => save(s.copyWith(
                    windModerate: (s.windModerate - 1).clamp(0.0, 10.0))),
                onPlus: () => save(s.copyWith(
                    windModerate: (s.windModerate + 1).clamp(0.0, 10.0))),
              ),
              const Divider(height: 1, color: AppColors.line),
              _StepRow(
                icon: Icons.storm,
                label: 'Harde wind',
                hint: 'vanaf 35 km/u',
                value: '−${s.windStrong.round()}°',
                onMinus: () => save(
                    s.copyWith(windStrong: (s.windStrong - 1).clamp(0.0, 12.0))),
                onPlus: () => save(
                    s.copyWith(windStrong: (s.windStrong + 1).clamp(0.0, 12.0))),
              ),
              const Divider(height: 1, color: AppColors.line),
              _StepRow(
                icon: Icons.umbrella,
                label: 'Regen of sneeuw',
                value: '−${s.wet.round()}°',
                onMinus: () => save(s.copyWith(wet: (s.wet - 1).clamp(0.0, 10.0))),
                onPlus: () => save(s.copyWith(wet: (s.wet + 1).clamp(0.0, 10.0))),
              ),
              const Divider(height: 1, color: AppColors.line),
              _StepRow(
                icon: Icons.house_siding,
                label: '\'s Nachts op stal',
                hint: 'warmer dan buiten',
                value: '+${s.stable.round()}°',
                onMinus: () => save(s.copyWith(stable: (s.stable - 1).clamp(0.0, 12.0))),
                onPlus: () => save(s.copyWith(stable: (s.stable + 1).clamp(0.0, 12.0))),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Text(
            'Met een schuilstal tellen wind en regen half mee. Wil je één paard '
            'warmer of kouder inschatten, zet dat paard dan op "heeft het snel '
            'koud" of "heeft het snel warm".',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _LevelLabel extends StatelessWidget {
  const _LevelLabel(this.level);
  final BlanketLevel level;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _Dot(level.color),
        const SizedBox(width: 6),
        Text(level.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]);
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    this.dot,
    this.icon,
    required this.label,
    this.hint,
    this.prefix,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final Color? dot;
  final IconData? icon;
  final String label;
  final String? hint;
  final String? prefix;
  final String value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(children: [
        if (dot != null) _Dot(dot!),
        if (icon != null) Icon(icon, size: 20, color: AppColors.green),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (hint != null)
              Text(hint!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ]),
        ),
        if (prefix != null)
          Text(prefix!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        IconButton(
          onPressed: onMinus,
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.green,
          visualDensity: VisualDensity.compact,
        ),
        SizedBox(
          width: 50,
          child: Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        IconButton(
          onPressed: onPlus,
          icon: const Icon(Icons.add_circle_outline),
          color: AppColors.green,
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}
