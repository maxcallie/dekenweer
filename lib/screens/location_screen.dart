import 'dart:async';

import 'package:flutter/material.dart';

import '../models/weather.dart';
import '../ui.dart';

/// Kies de plaats van je stal / weiland.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<FarmLocation> _results = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final r = await AppScope.read(context).weatherService.searchPlaces(q);
      if (!mounted || _ctrl.text != q) return;
      setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _error = 'Zoeken lukt niet. Heb je internet?');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Locatie van je stal',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: 'Zoek een plaats, bijv. Barneveld',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Text('Nu: ${app.location.name}'
              '${app.location.region.isNotEmpty ? ' (${app.location.region})' : ''}',
              style: const TextStyle(color: AppColors.muted)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 8),
          for (final r in _results)
            Card(
              color: AppColors.card,
              elevation: 0,
              margin: const EdgeInsets.only(top: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.line),
              ),
              child: ListTile(
                leading: const Icon(Icons.place_outlined, color: AppColors.green),
                title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(r.region),
                onTap: () {
                  app.setLocation(r);
                  Navigator.of(context).pop();
                },
              ),
            ),
        ],
      ),
    );
  }
}
