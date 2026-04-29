import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

enum CasaButtonVariant { primary, secondary, ghost, danger }

class CasaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final CasaButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final IconData? icon;
  final double? height;

  const CasaButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CasaButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height ?? 52,
      child: _buildButton(),
    );
  }

  Widget _buildButton() {
    final isDisabled = onPressed == null || isLoading;
    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: variant == CasaButtonVariant.primary
                  ? AppColors.surface
                  : AppColors.brandPrimary600,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(label, style: AppTypography.buttonLarge),
            ],
          );

    switch (variant) {
      case CasaButtonVariant.primary:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPrimary600,
            foregroundColor: AppColors.surface,
            disabledBackgroundColor: AppColors.neutral100,
            disabledForegroundColor: AppColors.neutral500,
          ),
          child: child,
        );

      case CasaButtonVariant.secondary:
        return OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          child: child,
        );

      case CasaButtonVariant.ghost:
        return TextButton(
          onPressed: isDisabled ? null : onPressed,
          child: child,
        );

      case CasaButtonVariant.danger:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger600,
            foregroundColor: AppColors.surface,
            disabledBackgroundColor: AppColors.neutral100,
            disabledForegroundColor: AppColors.neutral500,
          ),
          child: child,
        );
    }
  }
}
