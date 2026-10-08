import 'package:flutter/material.dart';

/// Fase van de dag. Avond & nacht loopt door tot 06:00 de volgende dag.
enum DayPhase {
  morning('Ochtend', 6, 12, Icons.wb_twilight),
  afternoon('Middag', 12, 18, Icons.wb_sunny),
  evening('Avond & nacht', 18, 30, Icons.bedtime);

  const DayPhase(this.label, this.startHour, this.endHour, this.icon);
  final String label;
  final int startHour;

  /// Eindtijd in uren vanaf middernacht van de gekozen dag (30 = 06:00 volgende dag).
  final int endHour;
  final IconData icon;

  bool get isNight => this == DayPhase.evening;

  String get range =>
      '${startHour.toString().padLeft(2, '0')}–${(endHour % 24).toString().padLeft(2, '0')}';

  /// De fase waar dit tijdstip in valt (voor 06:00 rekenen we de komende ochtend).
  static DayPhase of(DateTime t) {
    if (t.hour >= 6 && t.hour < 12) return DayPhase.morning;
    if (t.hour >= 12 && t.hour < 18) return DayPhase.afternoon;
    if (t.hour >= 18) return DayPhase.evening;
    return DayPhase.morning;
  }
}
