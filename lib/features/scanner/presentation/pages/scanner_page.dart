import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../controllers/scanner_provider.dart';

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

  Future<void> _startCamera() async {
    try {
      await _camera.start();
      // Zoom só aplicável em mobile — na web lança UnsupportedError.
      if (!kIsWeb) {
        try {
          await _camera.setZoomScale(_zoom);
        } catch (_) {
          // Device não suporta controle de zoom programático.
          if (mounted) setState(() => _zoomSupported = false);
        }
      }
    } catch (_) {
      // Câmera não disponível — usuário vai usar código manual.
    }
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    _camera.dispose();
    super.dispose();
  }

  // ── Detecção ─────────────────────────────────────────────────────────────
  void _onDetect(BarcodeCapture capture) {
    if (_navigating) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _navigating = true;
    // Feedback tátil imediato (somente mobile)
    if (!kIsWeb) HapticFeedback.mediumImpact();
    // Piscar cantos verdes
    setState(() => _detected = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _detected = false);
    });
    _camera.stop();
    // Pequena pausa para o usuário ver o flash antes do sheet
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _showConfirmation(raw);
    });
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
        ref.read(scannerProvider.notifier).onBarcodeDetected(barcode);
        context
            .push('${AppRoutes.productReview}?barcode=$barcode')
            .then((_) {
          _navigating = false;
          ref.read(scannerProvider.notifier).reset();
          _startCamera();
        });
      } else {
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
                    'EAN-13 · QR Code · Code 128',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ),
            ),

            // ── Botão de código manual ───────────────────────────────────
            Positioned(
              bottom: botPad + 20,
              left: 24,
              right: 24,
              child: TextButton.icon(
                onPressed: _showManualInput,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.keyboard_rounded, size: 18),
                label: const Text('Inserir código manualmente'),
              ),
            ),

          ],
        ),
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
