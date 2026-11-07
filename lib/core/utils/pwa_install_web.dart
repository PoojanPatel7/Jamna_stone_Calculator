// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

bool isPwaStandaloneImpl() {
  try {
    final result = js.context.callMethod('isPwaStandalone');
    if (result is bool) return result;
    return html.window.matchMedia('(display-mode: standalone)').matches;
  } catch (_) {
    return false;
  }
}

Future<bool> triggerPwaInstallImpl() async {
  try {
    final result = js.context.callMethod('triggerPwaInstall');
    if (result == true) return true;
    return false;
  } catch (_) {
    return false;
  }
}
