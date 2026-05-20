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

/// Captura foto do stream atual e detecta o código.
/// Usa ImageCapture.takePhoto() — NÃO abre câmera nativa do iOS.
/// Retorna null se nenhum código detectado ou captura falhou.
Future<String?> callWebCaptureAndScan() async {
  try {
    final dynamic promise = js.context.callMethod('_captureAndScan', []);
    if (promise == null) return null;
    final dynamic result = await js_util.promiseToFuture<dynamic>(promise);
    if (result == null) return null;
    final str = result.toString();
    if (str.startsWith('ERR:')) return null;
    return str.isEmpty ? null : str;
  } catch (_) {
    return null;
  }
}

/// Captura foto do stream atual e retorna o código OU a string de erro 'ERR:...'
/// para que o caller possa mostrar mensagem específica.
Future<String?> callWebCaptureAndScanRaw() async {
  try {
    final dynamic promise = js.context.callMethod('_captureAndScan', []);
    if (promise == null) return 'ERR:no_promise';
    final dynamic result = await js_util.promiseToFuture<dynamic>(promise);
    return result?.toString();
  } catch (e) {
    return 'ERR:$e';
  }
}

/// Retorna diagnóstico do stream de vídeo (string JSON) — chamada síncrona.
String callWebGetDiagnostics() {
  try {
    final dynamic result = js.context.callMethod('_getStreamDiagnostics', []);
    return result?.toString() ?? '{}';
  } catch (_) {
    return '{}';
  }
}

/// Stub mantido para compatibilidade (não usado).
Future<String?> callWebScanFromFile() async => null;
