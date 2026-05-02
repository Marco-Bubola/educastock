import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/router/app_router.dart';
import '../../../features/batches/presentation/controllers/batches_provider.dart';
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
                // Sino de alertas
                _AlertsBellButton(
                  alertCount: ref.watch(allAvailableBatchesProvider).when(
                    data: (list) => list.where((b) => !b.noExpiry && (b.isExpired || b.daysToExpiry <= 30)).length,
                    loading: () => 0,
                    error: (_, __) => 0,
                  ),
                  cs: cs,
                ),
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

// ─── Sino de alertas com balão popup ─────────────────────────────────────

class _AlertsBellButton extends ConsumerWidget {
  final int alertCount;
  final ColorScheme cs;

  const _AlertsBellButton({required this.alertCount, required this.cs});

  void _showBubble(BuildContext context, WidgetRef ref) {
    final allBatches = ref.read(allAvailableBatchesProvider).valueOrNull ?? [];
    final alerts = allBatches
        .where((b) => !b.noExpiry && (b.isExpired || b.daysToExpiry <= 30))
        .toList()
      ..sort((a, b) {
        // Vencidos primeiro, depois por daysToExpiry asc
        if (a.isExpired && !b.isExpired) return -1;
        if (!a.isExpired && b.isExpired) return 1;
        return a.daysToExpiry.compareTo(b.daysToExpiry);
      });
    final top5 = alerts.take(5).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final bubbleWidth = (screenWidth - 24).clamp(0.0, 320.0);
    final statusBarH = MediaQuery.of(context).padding.top;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'fechar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, _) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return Stack(
          children: [
            // toque fora fecha
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(ctx).pop(),
              child: const SizedBox.expand(),
            ),
            Positioned(
              top: statusBarH + 68,
              right: 8,
              child: ScaleTransition(
                alignment: Alignment.topRight,
                scale: curved,
                child: FadeTransition(
                  opacity: anim,
                  child: Material(
                    color: Colors.transparent,
                    child: _AlertBubble(
                      batches: top5,
                      totalAlerts: alerts.length,
                      width: bubbleWidth,
                      cs: Theme.of(context).colorScheme,
                      isDark:
                          Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = alertCount;

    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: GestureDetector(
        onTap: () => _showBubble(context, ref),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: count > 0
                    ? AppColors.warning600.withValues(alpha: 0.12)
                    : cs.surfaceContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: count > 0
                      ? AppColors.warning600.withValues(alpha: 0.4)
                      : cs.outlineVariant.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Icon(
                count > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_outlined,
                size: 18,
                color: count > 0
                    ? AppColors.warning600
                    : cs.onSurfaceVariant,
              ),
            ),
            if (count > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger600,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                    border:
                        Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Conteúdo do balão de alertas ────────────────────────────────────────

class _AlertBubble extends StatelessWidget {
  final List<dynamic> batches;
  final int totalAlerts;
  final double width;
  final ColorScheme cs;
  final bool isDark;

  const _AlertBubble({
    required this.batches,
    required this.totalAlerts,
    required this.width,
    required this.cs,
    required this.isDark,
  });

  Color _dotColor(dynamic b) {
    if (b.isExpired) return AppColors.danger600;
    final d = b.daysToExpiry as int;
    if (d <= 7) return AppColors.danger600;
    if (d <= 30) return AppColors.warning600;
    return AppColors.success600;
  }

  String _daysLabel(dynamic b) {
    if (b.isExpired) {
      final d = b.daysToExpiry as int;
      return 'Vencido há ${(-d).abs()} dia${(-d).abs() == 1 ? '' : 's'}';
    }
    final d = b.daysToExpiry as int;
    if (d == 0) return 'Vence hoje!';
    return 'Vence em $d dia${d == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.modal),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do balão
          Container(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.warning600.withValues(alpha: isDark ? 0.18 : 0.09),
                  AppColors.warning600.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.modal)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.warning600.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded,
                      size: 15, color: AppColors.warning600),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alertas de validade',
                          style: AppTypography.labelMedium.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700)),
                      Text('$totalAlerts item${totalAlerts == 1 ? '' : 's'} precisam de atenção',
                          style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Lista das últimas 5
          if (batches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success600, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Tudo em dia!',
                      style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.success600,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )
          else
            ...batches.map((b) {
              final dot = _dotColor(b);
              return InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('${AppRoutes.productDetail}/${b.productId}');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: dot, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.productName as String,
                              style: AppTypography.labelSmall.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              _daysLabel(b),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: dot,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 16, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              );
            }),

          if (batches.isNotEmpty)
            Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.4)),

          // Botão "Ver todas"
          InkWell(
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.alerts);
            },
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.modal)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm + 2,
                  horizontal: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.list_alt_rounded,
                      size: 15, color: AppColors.brandPrimary600),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Ver todas as notificações',
                      style: AppTypography.labelSmall.copyWith(
                          color: AppColors.brandPrimary600,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

