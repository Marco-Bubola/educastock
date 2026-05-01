import 'package:flutter/material.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

class ModernProfileAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final String? profileName;
  final VoidCallback? onProfileTap;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool showBackButton;

  const ModernProfileAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.profileName,
    this.onProfileTap,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.showBackButton = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.surface;
    final fg = foregroundColor ?? AppColors.neutral900;
    final normalizedName = profileName?.trim();
    final initial = (normalizedName == null || normalizedName.isEmpty)
      ? 'U'
      : normalizedName.substring(0, 1).toUpperCase();

    return AppBar(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: showBackButton,
      titleSpacing: AppSpacing.lg,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.headingMedium.copyWith(color: fg),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: AppTypography.bodySmall.copyWith(
                color: fg.withValues(alpha: 0.65),
              ),
            ),
        ],
      ),
      actions: [
        ...(actions ?? []),
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg, left: AppSpacing.xs),
          child: InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary100,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.brandPrimary600.withValues(alpha: 0.25)),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.brandPrimary700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
