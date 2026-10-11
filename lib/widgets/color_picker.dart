import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui.dart';

/// Rij met vaste kleuren plus een "+" voor een eigen kleur. Een eigen kleur
/// die niet in [palette] zit, verschijnt als extra (gekozen) rondje.
class ColorSwatchRow extends StatelessWidget {
  const ColorSwatchRow({
    super.key,
    required this.palette,
    required this.selected,
    required this.onChanged,
    this.recent = const [],
  });

  final List<Color> palette;
  final int selected;
  final ValueChanged<int> onChanged;

  /// Eerder gekozen eigen kleuren (bijv. van je andere dekens).
  final List<Color> recent;

  @override
  Widget build(BuildContext context) {
    final inPalette = palette.any((c) => c.toARGB32() == selected);
    final extra = <Color>[
      if (!inPalette) Color(selected),
      for (final c in recent)
        if (c.toARGB32() != selected && !palette.any((p) => p.toARGB32() == c.toARGB32())) c,
    ];
    Widget dot(Color c) => GestureDetector(
          onTap: () => onChanged(c.toARGB32()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: c.toARGB32() == selected ? AppColors.ink : AppColors.line,
                width: 3,
              ),
            ),
          ),
        );
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final c in palette) dot(c),
      for (final c in extra) dot(c),
      GestureDetector(
        onTap: () async {
          final c = await showColorPickerSheet(context, initial: Color(selected));
          if (c != null) onChanged(c.toARGB32());
        },
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.card,
            border: Border.all(color: AppColors.line, width: 2),
          ),
          child: const Icon(Icons.add, color: AppColors.muted, size: 22),
        ),
      ),
    ]);
  }
}

/// Kleurkiezer: vlak voor verzadiging/helderheid, een balk voor de tint en
/// een kleurcode (#RRGGBB).
Future<Color?> showColorPickerSheet(BuildContext context, {required Color initial}) {
  return showModalBottomSheet<Color>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cream,
    showDragHandle: true,
    builder: (_) => _PickerSheet(initial: initial),
  );
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.initial});
  final Color initial;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late HSVColor _hsv = HSVColor.fromColor(widget.initial);
  late final TextEditingController _hex = TextEditingController(text: _hexOf(widget.initial));

  static String _hexOf(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _set(HSVColor h) {
    setState(() => _hsv = h);
    _hex.text = _hexOf(h.toColor());
  }

  void _fromHex(String text) {
    final t = text.replaceAll('#', '').trim();
    if (t.length != 6) return;
    final v = int.tryParse(t, radix: 16);
    if (v == null) return;
    setState(() => _hsv = HSVColor.fromColor(Color(0xFF000000 | v)));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Eigen kleur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          // verzadiging (links-rechts) en helderheid (boven-onder)
          LayoutBuilder(builder: (context, box) {
            const h = 180.0;
            final w = box.maxWidth;
            void at(Offset p) => _set(_hsv
                .withSaturation((p.dx / w).clamp(0.0, 1.0))
                .withValue(1 - (p.dy / h).clamp(0.0, 1.0)));
            return GestureDetector(
              onPanDown: (d) => at(d.localPosition),
              onPanUpdate: (d) => at(d.localPosition),
              child: SizedBox(
                width: w,
                height: h,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(colors: [
                          Colors.white,
                          HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
                        ]),
                      ),
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xFF000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: _hsv.saturation * w - 12,
                    top: (1 - _hsv.value) * h - 12,
                    child: _Knob(color: color),
                  ),
                ]),
              ),
            );
          }),
          const SizedBox(height: 14),
          // tint
          LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            void at(Offset p) => _set(_hsv.withHue((p.dx / w).clamp(0.0, 1.0) * 359.9));
            return GestureDetector(
              onPanDown: (d) => at(d.localPosition),
              onPanUpdate: (d) => at(d.localPosition),
              child: SizedBox(
                width: w,
                height: 28,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 5,
                    height: 18,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        gradient: LinearGradient(colors: [
                          for (var i = 0; i <= 6; i++) HSVColor.fromAHSV(1, i * 60.0 % 360, 1, 1).toColor(),
                        ]),
                      ),
                    ),
                  ),
                  Positioned(
                    left: _hsv.hue / 360 * w - 12,
                    top: 2,
                    child: _Knob(color: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor()),
                  ),
                ]),
              ),
            );
          }),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line, width: 2),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 130,
              child: TextField(
                controller: _hex,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
                  LengthLimitingTextInputFormatter(7),
                ],
                onChanged: _fromHex,
                decoration: const InputDecoration(
                  labelText: 'Kleurcode',
                  isDense: true,
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(color),
              child: const Text('Kies'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Knob extends StatelessWidget {
  const _Knob({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
        ),
      );
}
