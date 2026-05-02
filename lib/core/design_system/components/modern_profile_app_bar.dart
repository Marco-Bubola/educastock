import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../tokens/color_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';

class ModernProfileAppBar extends ConsumerWidget implements PreferredSizeWidget {
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
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // AppBar usa surfaceContainerLow para se diferenciar do scaffold
    final bg = backgroundColor ?? cs.surfaceContainerLow;
    final fg = foregroundColor ?? cs.onSurface;
    final normalizedName = profileName?.trim();
    final initial = (normalizedName == null || normalizedName.isEmpty)
        ? 'U'
        : normalizedName.substring(0, 1).toUpperCase();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Container(
        color: bg,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                if (showBackButton)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 18, color: fg),
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 3.5,
                            height: 16,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.brandPrimary600,
                                  AppColors.secondaryBlue600,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              title,
                              style: AppTypography.headingMedium.copyWith(
                                color: fg,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          style: AppTypography.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                ...(actions ?? []),
                // Botão de toggle dark/light
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: _ThemeToggleButton(isDark: isDark, ref: ref),
                ),
                // Avatar de perfil
                if (profileName != null || onProfileTap != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  GestureDetector(
                    onTap: onProfileTap,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.brandPrimary600,
                            AppColors.secondaryBlue600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brandPrimary600.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: AppTypography.labelMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  final bool isDark;
  final WidgetRef ref;

  const _ThemeToggleButton({required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2563EB).withValues(alpha: 0.18)
            : const Color(0xFFB7791F).withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark
              ? const Color(0xFF2563EB).withValues(alpha: 0.4)
              : const Color(0xFFD69E2E).withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
            key: ValueKey(isDark),
            size: 18,
            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFFD69E2E),
          ),
        ),
        tooltip: isDark ? 'Modo claro' : 'Modo escuro',
        onPressed: () => ref.read(themeModeProvider.notifier).toggleDark(!isDark),
        style: IconButton.styleFrom(
          overlayColor: cs.onSurface.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}
