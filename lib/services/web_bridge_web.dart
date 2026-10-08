import 'dart:js_interop';

@JS('dekenweerShare')
external JSPromise<JSBoolean> _share(JSString title, JSString text, JSString url);

@JS('dekenweerStandalone')
external JSBoolean _standalone();

/// Opent het deelmenu van de telefoon (WhatsApp, Berichten, …). Geeft false
/// als dat niet kan, zodat de link gekopieerd kan worden.
Future<bool> shareLink(String title, String text, String url) async {
  try {
    final r = await _share(title.toJS, text.toJS, url.toJS).toDart;
    return r.toDart;
  } catch (_) {
    return false;
  }
}

/// Draait de web-app vanaf het beginscherm (en niet in Safari)?
bool isStandalone() {
  try {
    return _standalone().toDart;
  } catch (_) {
    return true;
  }
}

@JS('dekenweerClearQuery')
external void _clearQuery();

/// Haalt de link-parameter (?paard=…) weg uit de adresbalk.
void clearQuery() {
  try {
    _clearQuery();
  } catch (_) {}
}
