import 'package:flutter/material.dart';
import '../../../../core/design_system/design_system.dart';

class AuthCenterLogo extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthCenterLogo({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brandPrimary700, AppColors.brandPrimary500],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x331D5FA8),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: AppColors.surface.withValues(alpha: 0.65),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.inventory_2_rounded,
            color: AppColors.surface,
            size: 42,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          style: AppTypography.headingLarge.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
