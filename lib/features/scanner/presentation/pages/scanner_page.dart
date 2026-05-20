import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../controllers/scanner_provider.dart';
// Interop de scan direto para web (polyfill BarcodeDetector via JS bridge)
import 'web_scan_interop_stub.dart'
    if (dart.library.html) 'web_scan_interop.dart';

// ── Constantes do scanner ────────────────────────────────────────────────────
const _kScanBoxSize = 260.0;
// Escala interna do mobile_scanner: 0.0 = mín, 1.0 = máx do device.
// 0.45 ≈ ~3× na maioria dos devices Android/iOS. Na web o zoom não é
// exposto pelo browser, então iniciamos em 0 e ocultamos os botões.
const _kInitialZoomMobile = 0.45;
const _kZoomStep          = 0.1;

// ── Página ───────────────────────────────────────────────────────────────────
class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});
  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage>
    with SingleTickerProviderStateMixin {

  // Camera ─────────────────────────────────────────────────────────────────
  final _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
    autoStart: false, // iniciamos manualmente pós-frame
  );

  bool   _navigating    = false;
  // Na web: zoom digital via Transform.scale (1.0× a 4.0×), inicia em 2.0×.
  // No app nativo: zoom óptico/digital via setZoomScale (0.0 a 1.0).
  // _zoomSupported fica false somente se setZoomScale falhar no device.
  bool   _zoomSupported = true;
  double _zoom          = kIsWeb ? 2.0 : _kInitialZoomMobile;
  // Piscar os cantos ao detectar
  bool   _detected      = false;

  // ── Log visual de diagnóstico ─────────────────────────────────────────
  bool _showDebugLog     = false;
  bool _cameraFailed     = false;  // permissão negada ou erro irrecuperável
  bool _scanningFromPhoto = false;
  int  _frameCount       = 0;
  Timer? _heartbeat;
  Timer? _webScanTimer;  // loop de scan ZXing para web (iOS Safari)
  final List<_LogEntry> _logs = [];

  void _log(String msg, {bool isError = false}) {
    final now = DateTime.now();
    final ts  = '${now.hour.toString().padLeft(2,'0')}:'
                '${now.minute.toString().padLeft(2,'0')}:'
                '${now.second.toString().padLeft(2,'0')}';
    if (mounted) {
      setState(() {
        _logs.insert(0, _LogEntry(ts: ts, msg: msg, isError: isError));
        if (_logs.length > 40) _logs.removeLast();
      });
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 3), (_) {
      final state = _camera.value;
      final label = kIsWeb ? 'tentativas ZXing' : 'frames processados';
      _log('💓 Scanner: running=${state.isRunning} | '
           '$label=$_frameCount');
      _frameCount = 0;
    });
  }

  // ── Loop de scan ZXing via JS bridge (somente web / iOS Safari) ──────────
  void _startWebScanLoop() {
    if (!kIsWeb) return;
    _webScanTimer?.cancel();
    _log('🔁 Iniciando loop ZXing direto (iOS Safari mode)');
    _webScanTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (_navigating || !mounted) return;
      _doWebScan();
    });
  }

  Future<void> _doWebScan() async {
    _frameCount++;
    try {
      final barcode = await callWebScanFrame();
      if (barcode != null && barcode.isNotEmpty && !_navigating && mounted) {
        _log('🎯 ZXing detectou: $barcode');
        _webScanTimer?.cancel();
        _processBarcode(barcode);
      }
    } catch (e) {
      _log('⚠️ ZXing erro: $e', isError: true);
    }
  }

  // Animação da linha de scan ──────────────────────────────────────────────
  late final AnimationController _lineCtrl;
  late final Animation<double>   _lineAnim;

  // ── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _lineAnim = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut);

    // Inicia câmera APÓS o primeiro frame para garantir que o widget
    // MobileScanner já está na árvore (necessário para autoStart:false).
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  Future<void> _startCamera({int attempt = 0}) async {
    if (!mounted) return;
    if (mounted) setState(() => _cameraFailed = false);
    _log('📷 Iniciando câmera... (tentativa ${attempt + 1})');

    // No iOS/web, parar câmera antes de reiniciar evita
    // que o browser trave o stream após a permissão ser concedida.
    if (kIsWeb && attempt > 0) {
      try { await _camera.stop(); } catch (_) {}
      await Future.delayed(Duration(milliseconds: 400 * attempt));
    }

    try {
      await _camera.start();
      _log('✅ Câmera iniciada com sucesso');
      _startHeartbeat();
      if (kIsWeb) _startWebScanLoop();
      if (!kIsWeb) {
        try {
          await _camera.setZoomScale(_zoom);
          _log('🔍 Zoom inicial: ${(_zoom * 7 + 1).toStringAsFixed(1)}×');
        } catch (e) {
          _log('⚠️ Zoom indisponível: $e', isError: true);
          if (mounted) setState(() => _zoomSupported = false);
        }
      }
    } catch (e) {
      final err = e.toString().toLowerCase();
      _log('❌ Erro (tentativa ${attempt + 1}): $e', isError: true);

      // Permissão negada — não adianta tentar novamente automaticamente
      if (err.contains('notallowed') ||
          err.contains('permission') ||
          err.contains('denied')) {
        _log('🚫 Permissão de câmera negada pelo usuário', isError: true);
        if (mounted) setState(() => _cameraFailed = true);
        return;
      }

      // iOS Safari: após conceder permissão, o stream é interrompido.
      // Aguardamos e tentamos até 3 vezes.
      if (kIsWeb && attempt < 3 && mounted) {
        _log('🔄 Aguardando iOS liberar câmera...');
        await Future.delayed(Duration(milliseconds: 600 + attempt * 400));
        if (mounted) await _startCamera(attempt: attempt + 1);
        return;
      }

      // Falha definitiva
      _log('❌ Não foi possível iniciar câmera após ${attempt + 1} tentativas', isError: true);
      if (mounted) setState(() => _cameraFailed = true);
    }
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _webScanTimer?.cancel();
    _lineCtrl.dispose();
    _camera.dispose();
    super.dispose();
  }

  // ── Detecção contínua ────────────────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    _frameCount++;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    // Só loga eventos com barcode para não poluir o log com frames vazios
    if (capture.barcodes.isNotEmpty || _frameCount % 10 == 0) {
      _log('📡 Frame #$_frameCount | barcodes: ${capture.barcodes.length}'
          '${raw != null ? " | valor: $raw" : ""}');
    }

    if (_navigating) return;
    if (raw == null || raw.isEmpty) return;
    _processBarcode(raw);
  }

  void _processBarcode(String raw) {
    if (_navigating) return;
    _navigating = true;
    _heartbeat?.cancel();
    _webScanTimer?.cancel();
    _log('🎯 Código aceito: $raw');
    if (!kIsWeb) HapticFeedback.mediumImpact();
    setState(() => _detected = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _detected = false);
    });
    _camera.stop();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _showConfirmation(raw);
    });
  }

  // ── Escanear a partir de foto ─────────────────────────────────────────────
  Future<void> _scanFromPhoto() async {
    if (kIsWeb) {
      // Na web (iOS Chrome/Safari): abre câmera nativa via <input capture=environment>.
      // analyzeImage() não é suportado na web — usamos BarcodeDetector na foto estática.
      _log('📸 Abrindo câmera nativa para capturar foto...');
      if (mounted) setState(() => _scanningFromPhoto = true);
      try {
        String? barcode;
        try {
          barcode = await callWebScanFromFile()
              .timeout(const Duration(seconds: 60), onTimeout: () => null);
        } catch (_) {
          barcode = null;
        }
        if (barcode == null || barcode.isEmpty) {
          _log('📸 Nenhum código detectado na foto', isError: true);
          if (mounted) {
            setState(() => _scanningFromPhoto = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    '❌ Nenhum código detectado. Aproxime mais e tente novamente.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        _log('📸 Código lido da foto: $barcode');
        if (mounted) setState(() => _scanningFromPhoto = false);
        _processBarcode(barcode);
      } catch (e) {
        _log('📸 Erro ao capturar foto: $e', isError: true);
        if (mounted) setState(() => _scanningFromPhoto = false);
      }
      return;
    }

    // Caminho nativo (Android / iOS app)
    _log('📸 Abrindo câmera para foto...');
    if (mounted) setState(() => _scanningFromPhoto = true);
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );
      if (photo == null) {
        _log('📸 Foto cancelada pelo usuário');
        if (mounted) setState(() => _scanningFromPhoto = false);
        return;
      }
      _log('📸 Foto capturada: ${photo.path} — analisando...');
      final result = await _camera.analyzeImage(photo.path);
      if (result == null || result.barcodes.isEmpty) {
        _log('📸 Nenhum código detectado na foto', isError: true);
        if (mounted) {
          setState(() => _scanningFromPhoto = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '❌ Nenhum código de barras detectado na foto. Tente novamente mais perto.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final raw = result.barcodes.first.rawValue;
      _log('📸 Código lido da foto: $raw');
      if (mounted) setState(() => _scanningFromPhoto = false);
      if (raw != null && raw.isNotEmpty) _processBarcode(raw);
    } catch (e) {
      _log('📸 Erro ao processar foto: $e', isError: true);
      if (mounted) setState(() => _scanningFromPhoto = false);
    }
  }

  void _showConfirmation(String barcode) {
    showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final tt = Theme.of(ctx).textTheme;
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              24, 16, 24, 24 + MediaQuery.of(ctx).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Ícone + título
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Código detectado!',
                          style: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Confirme antes de prosseguir',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Chip do código
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: cs.outline.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code_rounded,
                        color: cs.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        barcode,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Ações
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Escanear\nnovamente',
                          textAlign: TextAlign.center),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Confirmar código'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary600,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((confirmed) {
      if (confirmed == true) {
        _log('✔️ Confirmado → navegando para revisão');
        ref.read(scannerProvider.notifier).onBarcodeDetected(barcode);
        context
            .push('${AppRoutes.productReview}?barcode=$barcode')
            .then((_) {
          _log('↩️ Voltou da revisão — reiniciando câmera');
          _navigating = false;
          ref.read(scannerProvider.notifier).reset();
          _startCamera();
        });
      } else {
        _log('🔄 Cancelado — reiniciando câmera');
        _navigating = false;
        _startCamera();
      }
    });
  }

  // ── Zoom ─────────────────────────────────────────────────────────────────
  // Safari/Web: zoom digital via Transform.scale (1.0× a 4.0×, passo 0.5×).
  // App nativo: zoom via setZoomScale da câmera  (0.0 a 1.0, passo 0.1).
  Future<void> _adjustZoom(double delta) async {
    if (!_zoomSupported) return;

    if (kIsWeb) {
      // Zoom digital — apenas escala o widget Flutter, não a câmera.
      // Funciona em qualquer browser incluindo Safari iOS.
      final step = delta > 0 ? 0.5 : -0.5;
      final next = (_zoom + step).clamp(1.0, 4.0);
      if ((next - _zoom).abs() < 0.01) return;
      setState(() => _zoom = next);
      return;
    }

    // App nativo: zoom real da câmera
    final next = (_zoom + delta).clamp(0.0, 1.0);
    if ((next - _zoom).abs() < 0.005) return;
    setState(() => _zoom = next);
    try {
      await _camera.setZoomScale(next);
    } catch (_) {
      if (mounted) setState(() => _zoomSupported = false);
    }
  }

  String get _zoomLabel {
    if (kIsWeb) {
      // Web: _zoom já é o fator de escala real (ex: 2.0 = 2×)
      return '${_zoom.toStringAsFixed(1)}×';
    }
    // App nativo: 0.0 → 1.0×  …  1.0 → 8.0×
    return '${(1.0 + _zoom * 7.0).toStringAsFixed(1)}×';
  }

  // ── Código manual ────────────────────────────────────────────────────────
  void _showManualInput() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        final tt = Theme.of(sheetCtx).textTheme;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Código manual',
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Digite o código para buscar o produto.',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 20),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Ex: 7891234567890',
                    prefixIcon: const Icon(Icons.qr_code_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    labelText: 'Código de barras',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final code = ctrl.text.trim();
                      if (code.isEmpty) return;
                      Navigator.of(sheetCtx).pop();
                      context.push(
                          '${AppRoutes.productReview}?barcode=$code');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Buscar produto'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq       = MediaQuery.of(context);
    final sw       = mq.size.width;
    final sh       = mq.size.height;
    final boxLeft  = (sw - _kScanBoxSize) / 2;
    final boxTop   = (sh - _kScanBoxSize) / 2;
    final scanWin  = Rect.fromLTWH(boxLeft, boxTop, _kScanBoxSize, _kScanBoxSize);
    final topPad   = mq.padding.top;
    final botPad   = mq.padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          fit: StackFit.expand,
          children: [

            // ── Câmera ───────────────────────────────────────────────────
            // NÃO usamos scanWindow — não é suportado na web e em algumas
            // versões Android pode bloquear toda a detecção.
            // Na WEB: envolvemos com ClipRect + Transform.scale para zoom digital.
            // Isso funciona em Safari iOS onde a API de zoom de câmera não existe.
            // A detecção roda no frame nativo (sem corte), o zoom é só visual.
            if (kIsWeb)
              ClipRect(
                child: Transform.scale(
                  scale: _zoom,
                  alignment: Alignment.center,
                  child: MobileScanner(
                    controller: _camera,
                    onDetect: _onDetect,
                  ),
                ),
              )
            else
              MobileScanner(
                controller: _camera,
                onDetect: _onDetect,
              ),


            // ── Overlay escuro + cantos + linha de scan ──────────────────
            AnimatedBuilder(
              animation: _lineAnim,
              builder: (_, __) => CustomPaint(
                size: Size(sw, sh),
                painter: _ScanOverlayPainter(
                  scanWindow: scanWin,
                  lineProgress: _lineAnim.value,
                  detected: _detected,
                ),
              ),
            ),

            // ── Barra de controles superior ──────────────────────────────
            Positioned(
              top: topPad + 6,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  _FabBtn(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const Spacer(),
                  // ── Controles de Zoom ─────────────────────────────
                  if (_zoomSupported) ...[
                    _FabBtn(
                      icon: Icons.remove_rounded,
                      onTap: () => _adjustZoom(-_kZoomStep),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _zoomLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _FabBtn(
                      icon: Icons.add_rounded,
                      onTap: () => _adjustZoom(_kZoomStep),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    // Na web o browser não expõe controle de zoom de câmera
                    Tooltip(
                      message: 'Zoom indisponível no navegador',
                      child: Opacity(
                        opacity: 0.4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.zoom_in_rounded,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('zoom',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // Lanterna — indisponível no browser (Safari/Chrome iOS
                  // não expõem a API de torch via WebRTC).
                  if (!kIsWeb) ...[
                    ValueListenableBuilder(
                      valueListenable: _camera,
                      builder: (_, state, __) => _FabBtn(
                        icon: state.torchState == TorchState.on
                            ? Icons.flashlight_on_rounded
                            : Icons.flashlight_off_rounded,
                        onTap: _camera.toggleTorch,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Virar câmera
                  _FabBtn(
                    icon: Icons.flip_camera_ios_outlined,
                    onTap: () async {
                      await _camera.switchCamera();
                      // Na web o zoom é digital (Transform.scale), não precisa
                      // reaplicar setZoomScale após troca de câmera.
                      if (!kIsWeb) {
                        try { await _camera.setZoomScale(_zoom); } catch (_) {}
                      }
                    },
                  ),
                ],
              ),
            ),

            // ── Título / instrução (acima do quadrado) ────────────────────
            Positioned(
              top: topPad + 66,
              left: 24,
              right: 24,
              child: const Column(
                children: [
                  Text(
                    'Escanear produto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 8)],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Aponte o código para a área marcada',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // ── Instrução embaixo do quadrado ────────────────────────────
            Positioned(
              top: boxTop + _kScanBoxSize + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'EAN-8 · EAN-13 · QR Code · Code 128',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ),
            ),

            // ── Botões inferiores: foto + código manual ──────────────────
            Positioned(
              bottom: botPad + 20,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  // Botão tirar foto
                  Expanded(
                    child: _scanningFromPhoto
                        ? Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: _scanFromPhoto,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: const BorderSide(color: Colors.white30),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(
                              Icons.photo_camera_rounded,
                              size: 18,
                            ),
                            label: const Text('Tirar foto'),
                          ),
                  ),
                  const SizedBox(width: 10),
                  // Botão código manual
                  Expanded(
                    child: TextButton.icon(
                      onPressed: _showManualInput,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.keyboard_rounded, size: 18),
                      label: const Text('Código manual'),
                    ),
                  ),
                ],
              ),
            ),

            // ── Banner: câmera com falha definitiva ──────────────────────
            if (_cameraFailed)
              Positioned(
                top: topPad + 66,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.videocam_off_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Câmera indisponível',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Permita o acesso à câmera nas configurações do navegador e toque em "Tentar novamente".',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _startCamera(),
                          icon: const Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 16),
                          label: const Text('Tentar novamente',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white54),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Botão de log de diagnóstico ──────────────────────────────
            Positioned(
              bottom: botPad + 66,
              right: 16,
              child: _FabBtn(
                icon: Icons.bug_report_rounded,
                onTap: () => setState(() => _showDebugLog = !_showDebugLog),
              ),
            ),

            // ── Painel de log visual ─────────────────────────────────────
            if (_showDebugLog)
              Positioned(
                bottom: botPad + 110,
                left: 12,
                right: 12,
                child: _DebugLogPanel(
                  logs: _logs,
                  onClear: () => setState(() => _logs.clear()),
                ),
              ),

          ],
        ),
      ),
    );
  }
}

// ── Modelo de entrada de log ─────────────────────────────────────────────────
class _LogEntry {
  final String ts;
  final String msg;
  final bool   isError;
  const _LogEntry({required this.ts, required this.msg, this.isError = false});
}

// ── Painel de log visual ──────────────────────────────────────────────────────
class _DebugLogPanel extends StatelessWidget {
  final List<_LogEntry> logs;
  final VoidCallback onClear;
  const _DebugLogPanel({required this.logs, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          // Cabeçalho
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.bug_report_rounded,
                    color: Colors.greenAccent, size: 14),
                const SizedBox(width: 6),
                const Text(
                  'Log de diagnóstico',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onClear,
                  child: const Text(
                    'limpar',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Lista de eventos
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'Aguardando eventos...',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: logs.length,
                    itemBuilder: (_, i) {
                      final e = logs[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 1),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.ts,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                e.msg,
                                style: TextStyle(
                                  color: e.isError
                                      ? Colors.redAccent
                                      : Colors.white70,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Botão circular flutuante ─────────────────────────────────────────────────
class _FabBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FabBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ── Overlay CustomPainter ─────────────────────────────────────────────────────
class _ScanOverlayPainter extends CustomPainter {
  final Rect   scanWindow;
  final double lineProgress;
  final bool   detected;

  const _ScanOverlayPainter({
    required this.scanWindow,
    required this.lineProgress,
    this.detected = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Sombra ao redor do quadrado
    final shadow = Paint()..color = Colors.black.withOpacity(0.68);
    final path   = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
          scanWindow, const Radius.circular(14)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, shadow);

    // Cantos: branco piscante ao detectar, verde normal
    final cornerColor = detected ? Colors.white : Colors.greenAccent;
    final corner = Paint()
      ..color      = cornerColor
      ..strokeWidth = detected ? 5.0 : 3.5
      ..style       = PaintingStyle.stroke
      ..strokeCap   = StrokeCap.round;
    const cl = 30.0;
    final tl = scanWindow.topLeft;
    final tr = scanWindow.topRight;
    final bl = scanWindow.bottomLeft;
    final br = scanWindow.bottomRight;

    // top-left
    canvas.drawLine(tl + Offset(0, cl), tl, corner);
    canvas.drawLine(tl, tl + Offset(cl, 0), corner);
    // top-right
    canvas.drawLine(tr + Offset(-cl, 0), tr, corner);
    canvas.drawLine(tr, tr + Offset(0, cl), corner);
    // bottom-left
    canvas.drawLine(bl + Offset(0, -cl), bl, corner);
    canvas.drawLine(bl, bl + Offset(cl, 0), corner);
    // bottom-right
    canvas.drawLine(br + Offset(-cl, 0), br, corner);
    canvas.drawLine(br, br + Offset(0, -cl), corner);

    // Linha de scan animada
    final lineY = scanWindow.top + scanWindow.height * lineProgress;
    final lr = Rect.fromLTWH(
        scanWindow.left + 10, lineY - 1.5, scanWindow.width - 20, 3);
    final linePaint = Paint()
      ..shader = LinearGradient(colors: [
        Colors.transparent,
        Colors.greenAccent.withOpacity(0.9),
        Colors.transparent,
      ]).createShader(lr);
    canvas.drawRect(lr, linePaint);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.lineProgress != lineProgress || old.detected != detected;
}
