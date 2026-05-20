// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;

/// Chama `window._zxingScanFrame()` (JS Promise) e retorna o barcode ou null.
Future<String?> callWebScanFrame() async {
  try {
    final dynamic promise = js.context.callMethod('_zxingScanFrame', []);
    if (promise == null) return null;
    final dynamic result = await js_util.promiseToFuture<dynamic>(promise);
    if (result == null) return null;
    final str = result.toString();
    return str.isEmpty ? null : str;
  } catch (_) {
    return null;
  }
}

/// Abre a câmera nativa via `<input capture=environment>` e retorna o barcode
/// detectado na foto ou null (usuário cancelou / não detectado).
Future<String?> callWebScanFromFile() async {
  try {
    final dynamic promise = js.context.callMethod('_scanFromFileInput', []);
    if (promise == null) return null;
    final dynamic result = await js_util.promiseToFuture<dynamic>(promise);
    if (result == null) return null;
    final str = result.toString();
    return str.isEmpty ? null : str;
  } catch (_) {
    return null;
  }
}
