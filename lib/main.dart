import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState()..init();
  runApp(DekenweerApp(state: state));
}

class DekenweerApp extends StatelessWidget {
  const DekenweerApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      surface: AppColors.cream,
    );
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Dekenweer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: scheme,
          scaffoldBackgroundColor: AppColors.cream,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.cream,
            foregroundColor: AppColors.ink,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
          ),
          textTheme: Typography.blackCupertino.apply(
            bodyColor: AppColors.ink,
            displayColor: AppColors.ink,
          ),
          chipTheme: const ChipThemeData(
            side: BorderSide(color: AppColors.line),
            shape: StadiumBorder(),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.line),
            ),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
