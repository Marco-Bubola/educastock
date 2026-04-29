import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

class CasaFabScan extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const CasaFabScan({
    super.key,
    required this.onPressed,
    this.label = 'Escanear',
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppColors.brandPrimary600,
      foregroundColor: AppColors.surface,
      elevation: AppElevation.medium,
      icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
      label: Text(
        label,
        style: AppTypography.buttonMedium.copyWith(color: AppColors.surface),
      ),
    );
  }
}
