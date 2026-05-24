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
          width: 112,
          height: 112,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            boxShadow: const [
              BoxShadow(
                color: Color(0x331D5FA8),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: AppColors.brandPrimary100,
              width: 2,
            ),
          ),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
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
