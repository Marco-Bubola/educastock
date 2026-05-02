import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../controllers/scanner_provider.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> {
  final _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );

  bool _navigating = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_navigating) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;
    _navigating = true;
    ref.read(scannerProvider.notifier).onBarcodeDetected(barcode);
    context.push('${AppRoutes.productReview}?barcode=$barcode').then((_) {
      _navigating = false;
      ref.read(scannerProvider.notifier).reset();
    });
  }

  void _showManualBarcodeInput(BuildContext ctx) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.modal)),
            ),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                Text('Código de barras manual',
                    style: AppTypography.headingSmall.copyWith(
                        color: cs.onSurface, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                    'Digite o código para verificar se o produto já existe.',
                    style: AppTypography.bodySmall
                        .copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Ex: 7891234567890',
                    prefixIcon: const Icon(Icons.qr_code_rounded),
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.input)),
                    labelText: 'Código de barras',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final barcode = ctrl.text.trim();
                      if (barcode.isEmpty) return;
                      Navigator.of(sheetCtx).pop();
                      context.push(
                          '${AppRoutes.productReview}?barcode=$barcode');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button)),
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: ModernProfileAppBar(
        title: 'Escanear produto',
        subtitle: 'Leitor de codigo de barras',
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _cameraController,
              builder: (_, state, __) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flashlight_on_rounded
                    : Icons.flashlight_off_rounded,
                color: Colors.white,
              ),
            ),
            onPressed: _cameraController.toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white),
            onPressed: _cameraController.switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),
          // Overlay guia
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.brandPrimary100,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(AppRadius.modal),
              ),
            ),
          ),
          // Instrução
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'Aponte para o código de barras do produto',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // Botão cadastro manual
          Positioned(
            bottom: 24,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: TextButton.icon(
              onPressed: () => _showManualBarcodeInput(context),
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              icon: const Icon(Icons.keyboard_rounded, size: 18),
              label: const Text('Cadastro manual sem código de barras'),
            ),
          ),
        ],
      ),
    );
  }
}
