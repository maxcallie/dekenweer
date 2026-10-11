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
  bool _exampleWet = false;
  int _exampleSun = 0; // 0 = bewolkt, 1 = zonnig, 2 = volle zon

  static const _rowLabels = [
    BlanketLevel.none,
    BlanketLevel.rainSheet,
    BlanketLevel.light,
    BlanketLevel.medium,
    BlanketLevel.heavy,
  ];

  String _deg(double v) => '${v.round()}°C';

  /// Het voorbeeld: dezelfde regels als het echte advies (regendeken alleen
  /// bij nat weer, vliegendeken met regenstuk), voor een standaardpaard.
  BlanketLevel _exampleLevel(BlanketAdvisor advisor, AdviceSettings s, ClipType clip) {
    var dry = _exampleTemp;
    if (_exampleSun == 1) dry += s.sunny;
    if (_exampleSun == 2) dry += s.fullSun;
    final eff = _exampleWet ? dry - s.wet : dry;
    return advisor.levelForWeather(clip, eff,
        wet: _exampleWet, base: _exampleTemp, dryEff: dry);
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
                            'Alle grenzen, correcties en schakelaars gaan terug naar de standaardwaarden.'),
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
                    _LevelLabel(_exampleLevel(advisor, s, clip)),
                  ]),
                ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                FilterChip(
                  label: const Text('Regen'),
                  avatar: const Icon(Icons.umbrella, size: 16),
                  selected: _exampleWet,
                  onSelected: (v) => setState(() => _exampleWet = v),
                ),
                for (final (i, l) in const [(0, 'Bewolkt'), (1, 'Zonnig'), (2, 'Volle zon')])
                  ChoiceChip(
                    label: Text(l),
                    selected: _exampleSun == i,
                    onSelected: (_) => setState(() => _exampleSun = i),
                  ),
              ]),
              const SizedBox(height: 6),
              Text(
                  '${_exampleWet ? 'Regen' : 'Droog'}, windstil, overdag en zonder '
                  'correcties voor het paard.',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),

          // ---- Vliegendeken met regenstuk --------------------------------
          const SizedBox(height: 16),
          _Card(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              secondary: _Dot(BlanketLevel.flyRain.color),
              title: const Text('Vliegendeken met regenstuk'),
              subtitle: const Text(
                  'Bij warm, nat weer: houdt de rug droog zonder dat je paard het '
                  'te warm krijgt. Zet uit als je er geen hebt.'),
              value: s.flyRain,
              onChanged: (v) => save(s.copyWith(flyRain: v)),
            ),
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
                if (s.flyRain) ...[
                  _StepRow(
                    dot: BlanketLevel.flyRain.color,
                    label: 'Vliegendeken met regenstuk',
                    hint: 'alleen bij regen · ondergrens is die van Geen deken · '
                        'regen telt hier niet als kouder',
                    prefix: 'vanaf',
                    value: _deg(s.thresholdsFor(clip)[0]),
                    onMinus: () => save(
                        s.withThreshold(clip, 0, s.thresholdsFor(clip)[0] - 1)),
                    onPlus: () => save(
                        s.withThreshold(clip, 0, s.thresholdsFor(clip)[0] + 1)),
                  ),
                  _StepRow(
                    indent: true,
                    label: 'Bovengrens',
                    hint: 'daarboven bij regen geen deken',
                    prefix: 'tot',
                    value: _deg(s.flyRainUpToFor(clip)),
                    onMinus: () => save(
                        s.withFlyRainUpTo(clip, s.flyRainUpToFor(clip) - 1)),
                    onPlus: () => save(
                        s.withFlyRainUpTo(clip, s.flyRainUpToFor(clip) + 1)),
                  ),
                  const Divider(height: 1, color: AppColors.line),
                ],
                for (var i = 0; i < 5; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.line),
                  _StepRow(
                    dot: _rowLabels[i].color,
                    label: _rowLabels[i].label,
                    hint: i == 1 && s.rainOnlyWetFor(clip) ? 'alleen bij nat weer' : null,
                    prefix: 'vanaf',
                    value: _deg(s.thresholdsFor(clip)[i]),
                    onMinus: () => save(
                        s.withThreshold(clip, i, s.thresholdsFor(clip)[i] - 1)),
                    onPlus: () => save(
                        s.withThreshold(clip, i, s.thresholdsFor(clip)[i] + 1)),
                  ),
                  if (i == 1)
                    SwitchListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.fromLTRB(36, 0, 14, 4),
                      title: const Text('Regendeken alleen bij nat weer',
                          style: TextStyle(fontSize: 14)),
                      subtitle: Text(s.rainOnlyWetFor(clip)
                          ? 'Bij droog weer: geen deken'
                          : 'Ook bij droog weer (houdt wind tegen en de vacht droog)'),
                      value: s.rainOnlyWetFor(clip),
                      onChanged: (v) => save(s.withRainOnlyWet(clip, v)),
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
                label: 'Sterke wind',
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
                icon: Icons.wb_cloudy_outlined,
                label: 'Zonnig',
                hint: 'overdag, deels zonnig',
                value: '+${s.sunny.round()}°',
                onMinus: () => save(s.copyWith(sunny: (s.sunny - 1).clamp(0.0, 10.0))),
                onPlus: () => save(s.copyWith(sunny: (s.sunny + 1).clamp(0.0, 10.0))),
              ),
              const Divider(height: 1, color: AppColors.line),
              _StepRow(
                icon: Icons.wb_sunny,
                label: 'Volle zon',
                hint: 'overdag, (bijna) onbewolkt',
                value: '+${s.fullSun.round()}°',
                onMinus: () =>
                    save(s.copyWith(fullSun: (s.fullSun - 1).clamp(0.0, 12.0))),
                onPlus: () =>
                    save(s.copyWith(fullSun: (s.fullSun + 1).clamp(0.0, 12.0))),
              ),
              const Divider(height: 1, color: AppColors.line),
              _StepRow(
                icon: Icons.house_siding,
                label: 'Op stal',
                hint: 'warmer dan buiten, geen wind of regen',
                value: '+${s.stable.round()}°',
                onMinus: () => save(s.copyWith(stable: (s.stable - 1).clamp(0.0, 12.0))),
                onPlus: () => save(s.copyWith(stable: (s.stable + 1).clamp(0.0, 12.0))),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Text(
            'Alle correcties worden bij elkaar opgeteld (bijv. volle zon +4° en '
            'wind −2° geeft +2°). Zon telt alleen overdag en niet op stal. '
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
    this.indent = false,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final Color? dot;
  final IconData? icon;
  final String label;
  final String? hint;
  final String? prefix;
  final bool indent;
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
        if (indent) const SizedBox(width: 12),
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
