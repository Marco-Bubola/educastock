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

// Gradiente padrão de todos os headers do app
const _kHeaderGradient = LinearGradient(
  colors: [Color(0xFF0F2444), Color(0xFF1A3A6B), Color(0xFF1D5FA8)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class ModernProfileAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final String? profileName;
  final VoidCallback? onProfileTap;
  final List<Widget>? actions;
  final bool showBackButton;

  const ModernProfileAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.profileName,
    this.onProfileTap,
    this.actions,
    // backgroundColor / foregroundColor mantidos para não quebrar chamadas antigas
    // ignore: unused_element
    Color? backgroundColor,
    // ignore: unused_element
    Color? foregroundColor,
    this.showBackButton = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedName = profileName?.trim();
    final initial = (normalizedName == null || normalizedName.isEmpty)
        ? 'U'
        : normalizedName.substring(0, 1).toUpperCase();

    final alertCount = ref.watch(allAvailableBatchesProvider).when(
          data: (list) =>
              list.where((b) => !b.noExpiry && (b.isExpired || b.daysToExpiry <= 30)).length,
          loading: () => 0,
          error: (_, __) => 0,
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        decoration: const BoxDecoration(gradient: _kHeaderGradient),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  // ── Botão de voltar ─────────────────────────────────
                  if (showBackButton)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18, color: Colors.white),
                        ),
                      ),
                    ),

                  // ── Título + subtítulo ───────────────────────────────
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                title,
                                style: AppTypography.headingMedium.copyWith(
                                  color: Colors.white,
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
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Actions extras ───────────────────────────────────
                  if ((actions ?? []).isNotEmpty)
                    IconTheme(
                      data: const IconThemeData(color: Colors.white, size: 22),
                      child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
                    ),

                  // ── Sino de alertas ──────────────────────────────────
                  CasaAlertsBellButton(
                    alertCount: alertCount,
                    onDarkBg: true,
                  ),

                  // ── Toggle dark/light ────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: CasaThemeToggleButton(),
                  ),

                  // ── Avatar de perfil (se fornecido) ─────────────────
                  if (profileName != null || onProfileTap != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    GestureDetector(
                      onTap: onProfileTap,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
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
      ),
    );
  }
}

// ─── Toggle dark/light público ────────────────────────────────────────────

class CasaThemeToggleButton extends ConsumerWidget {
  const CasaThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
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
            color: Colors.white,
          ),
        ),
        tooltip: isDark ? 'Modo claro' : 'Modo escuro',
        onPressed: () =>
            ref.read(themeModeProvider.notifier).toggleDark(!isDark),
        style: IconButton.styleFrom(
          overlayColor: Colors.white.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}

// ─── Sino de alertas público ──────────────────────────────────────────────

class CasaAlertsBellButton extends ConsumerWidget {
  final int alertCount;
  /// Se `true`, força estilo sobre fundo escuro (branco semi-transparente)
  final bool onDarkBg;

  const CasaAlertsBellButton({
    super.key,
    required this.alertCount,
    this.onDarkBg = false,
  });

  void _showBubble(BuildContext context, WidgetRef ref) {
    final allBatches = ref.read(allAvailableBatchesProvider).valueOrNull ?? [];
    final alerts = allBatches
        .where((b) => !b.noExpiry && (b.isExpired || b.daysToExpiry <= 30))
        .toList()
      ..sort((a, b) {
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

    final bgColor = onDarkBg
        ? (count > 0
            ? AppColors.warning600.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.14))
        : (count > 0
            ? AppColors.warning600.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surfaceContainer);

    final borderColor = onDarkBg
        ? (count > 0
            ? AppColors.warning600.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.3))
        : (count > 0
            ? AppColors.warning600.withValues(alpha: 0.4)
            : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35));

    final iconColor = onDarkBg
        ? (count > 0 ? AppColors.warning600 : Colors.white)
        : (count > 0
            ? AppColors.warning600
            : Theme.of(context).colorScheme.onSurfaceVariant);

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
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 1.2),
              ),
              child: Icon(
                count > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_outlined,
                size: 18,
                color: iconColor,
              ),
            ),
            if (count > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger600,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: Colors.white, width: 1.5),
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

// ─── Conteúdo do balão de alertas ─────────────────────────────────────────

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
                      Text(
                          '$totalAlerts item${totalAlerts == 1 ? '' : 's'} precisam de atenção',
                          style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
                        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
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
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
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
                  vertical: AppSpacing.sm + 2, horizontal: AppSpacing.md),
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