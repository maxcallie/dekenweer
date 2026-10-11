import 'package:flutter/material.dart';

/// Een periode met één deken: overdag, avond & nacht, of het hele etmaal
/// (afhankelijk van het aantal dekenwissels per dag).
enum AdviceSlot {
  day('Overdag', Icons.wb_sunny),
  night('Avond & nacht', Icons.bedtime),
  allDay('Hele etmaal', Icons.schedule);

  const AdviceSlot(this.label, this.icon);
  final String label;
  final IconData icon;
}
