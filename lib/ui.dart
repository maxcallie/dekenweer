import 'package:flutter/material.dart';

import 'state/app_state.dart';

/// Maakt de [AppState] beschikbaar in de hele widgetboom.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Zonder te luisteren naar wijzigingen (bijv. in callbacks).
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class AppColors {
  static const cream = Color(0xFFF6F1E7);
  static const card = Color(0xFFFFFCF6);
  static const ink = Color(0xFF1F2A22);
  static const muted = Color(0xFF6F7A70);
  static const green = Color(0xFF2E6B3F);
  static const line = Color(0xFFE7DFD0);
}
