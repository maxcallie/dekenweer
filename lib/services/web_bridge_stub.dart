/// Buiten de web-app: geen deelmenu.
Future<bool> shareLink(String title, String text, String url) async => false;

/// Buiten de web-app draait de app altijd "als app".
bool isStandalone() => true;

void clearQuery() {}
