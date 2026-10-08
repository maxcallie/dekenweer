import 'package:flutter/material.dart';

import '../services/haptics.dart';
import '../ui.dart';
import '../widgets/horseshoe_icon.dart';
import 'care_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'share_screen.dart';
import 'stable_screen.dart';

/// Vaste tabbladen onderin.
enum AppTab { wei, paarden, dekens, zorg, instellingen }

/// Het hoofdframe van de app: de tabs met de tabbalk onderin.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  /// Sleutel om vanuit elk scherm (ook een pop-up) van tab te wisselen.
  static final shellKey = GlobalKey<RootShellState>();

  /// Ga naar een tab (bijv. vanuit een melding op het beginscherm).
  static void go(AppTab tab) => shellKey.currentState?.go(tab);

  @override
  State<RootShell> createState() => RootShellState();
}

class RootShellState extends State<RootShell> {
  AppTab _tab = AppTab.wei;

  @override
  void initState() {
    super.initState();
    // Geopend via een deel-link (…?paard=…)? Dan meteen het voorbeeld tonen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) handleIncomingLink(context);
    });
  }

  void go(AppTab tab) {
    if (tab == _tab) return;
    Haptics.select();
    setState(() => _tab = tab);
  }

  static const _pages = <Widget>[
    HomeScreen(),
    HorsesTab(),
    BlanketsTab(),
    CareTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        for (final t in AppTab.values)
          _TabLayer(active: t == _tab, child: _pages[t.index]),
      ]),
      bottomNavigationBar: _TabBar(selected: _tab, onSelect: go),
    );
  }
}

/// Houdt elke tab in leven (scrollpositie, paarden in de wei) en laat
/// wisselen zacht in elkaar overvloeien.
class _TabLayer extends StatelessWidget {
  const _TabLayer({required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !active,
        child: ExcludeSemantics(
          excluding: !active,
          // AnimatedOpacity buiten TickerMode: anders staat de fade-animatie
          // van een tab die verdwijnt stil en blijft die tab zichtbaar.
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: TickerMode(enabled: active, child: child),
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});
  final AppTab selected;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final soon = AppScope.of(context).careSoon.length;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFAF6EE),
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(children: [
            _item(AppTab.wei, 'Wei', (c) => Icon(Icons.grass, color: c, size: 25)),
            _item(AppTab.paarden, 'Paarden', (c) => HorseshoeIcon(size: 24, color: c)),
            _item(AppTab.dekens, 'Dekens', (c) => Icon(Icons.checkroom, color: c, size: 25)),
            _item(AppTab.zorg, 'Zorg', (c) => Icon(Icons.vaccines, color: c, size: 25),
                badge: soon),
            _item(AppTab.instellingen, 'Instellingen',
                (c) => Icon(Icons.tune, color: c, size: 25)),
          ]),
        ),
      ),
    );
  }

  Widget _item(AppTab tab, String label, Widget Function(Color) icon, {int badge = 0}) {
    final on = tab == selected;
    final color = on ? AppColors.green : const Color(0xFF8A938A);
    return Expanded(
      child: Semantics(
        button: true,
        selected: on,
        label: label,
        child: InkResponse(
          onTap: () => onSelect(tab),
          radius: 32,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, children: [
              icon(color),
              if (badge > 0)
                Positioned(
                  right: -10,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17),
                    height: 17,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8442F),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFFFAF6EE), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text('$badge',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
            const SizedBox(height: 3),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                    fontSize: 10.5,
                    color: color,
                    fontWeight: on ? FontWeight.w800 : FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
