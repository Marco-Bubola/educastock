import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../ml/presentation/controllers/risk_classifier_provider.dart';
import '../../../ml/presentation/widgets/risk_widgets.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final expiringCritical = ref.watch(expiringBatchesProvider(7));
    final expiringWarning = ref.watch(expiringBatchesProvider(30));
    final allBatches = ref.watch(allAvailableBatchesProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: ModernProfileAppBar(
        title: 'EducaStock',
        subtitle: 'Painel operacional',
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(AppRoutes.alerts),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            // KPIs
            const CasaSectionHeader(title: 'Visão Geral de Hoje'),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SizedBox(
                height: 116,
                child: Row(
                  children: [
                    Expanded(
                      child: allBatches.when(
                        data: (batches) => _KpiCard(
                          label: 'Lotes',
                          value: '${batches.length}',
                          icon: Icons.inventory_2_rounded,
                          gradientColors: const [Color(0xFF1D5FA8), Color(0xFF2F74C0)],
                          onTap: () => context.go(AppRoutes.productList),
                        ),
                        loading: () => const _KpiCardSkeleton(),
                        error: (_, __) => const _KpiCard(
                          label: 'Lotes',
                          value: '-',
                          icon: Icons.inventory_2_rounded,
                          gradientColors: [Color(0xFF1D5FA8), Color(0xFF2F74C0)],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: expiringCritical.when(
                        data: (batches) => _KpiCard(
                          label: 'Vencem 7d',
                          value: '${batches.length}',
                          icon: Icons.warning_rounded,
                          gradientColors: const [Color(0xFFC53030), Color(0xFFE53E3E)],
                          badge: batches.isNotEmpty ? '${batches.length}' : null,
                          onTap: () => context.go(AppRoutes.alerts),
                        ),
                        loading: () => const _KpiCardSkeleton(),
                        error: (_, __) => const _KpiCard(
                          label: 'Vencem 7d',
                          value: '-',
                          icon: Icons.warning_rounded,
                          gradientColors: [Color(0xFFC53030), Color(0xFFE53E3E)],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: expiringWarning.when(
                        data: (batches) => _KpiCard(
                          label: 'Atenção 30d',
                          value: '${batches.length}',
                          icon: Icons.schedule_rounded,
                          gradientColors: const [Color(0xFFB7791F), Color(0xFFD69E2E)],
                          onTap: () => context.go(AppRoutes.alerts),
                        ),
                        loading: () => const _KpiCardSkeleton(),
                        error: (_, __) => const _KpiCard(
                          label: 'Atenção 30d',
                          value: '-',
                          icon: Icons.schedule_rounded,
                          gradientColors: [Color(0xFFB7791F), Color(0xFFD69E2E)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Ações rápidas
            const CasaSectionHeader(title: 'Ações Rápidas'),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cross = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 620
                          ? 3
                          : 2;
                  return GridView.count(
                    crossAxisCount: cross,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1.72,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _AnimatedQuickAction(
                        delayMs: 0,
                        child: _QuickActionTile(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Escanear',
                          subtitle: 'Entrada por código',
                          color: AppColors.brandPrimary600,
                          onTap: () => context.push(AppRoutes.scanner),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 60,
                        child: _QuickActionTile(
                          icon: Icons.list_alt_rounded,
                          label: 'Estoque',
                          subtitle: 'Produtos e lotes',
                          color: AppColors.secondaryBlue600,
                          onTap: () => context.go(AppRoutes.productList),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 120,
                        child: _QuickActionTile(
                          icon: Icons.outbound_rounded,
                          label: 'Saída',
                          subtitle: 'Baixa de estoque',
                          color: AppColors.danger600,
                          onTap: () => context.push('${AppRoutes.movement}?batchId='),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 180,
                        child: _QuickActionTile(
                          icon: Icons.menu_book_rounded,
                          label: 'Receitas',
                          subtitle: 'Saída automática',
                          color: AppColors.brandPrimary600,
                          onTap: () => context.push(AppRoutes.recipes),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 240,
                        child: _QuickActionTile(
                          icon: Icons.notifications_active_rounded,
                          label: 'Alertas',
                          subtitle: 'Prazos e riscos',
                          color: AppColors.warning600,
                          onTap: () => context.go(AppRoutes.alerts),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 300,
                        child: _QuickActionTile(
                          icon: Icons.add_location_alt_rounded,
                          label: 'Localizações',
                          subtitle: 'Estrutura física',
                          color: AppColors.secondaryBlue600,
                          onTap: () => context.push(AppRoutes.locations),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Análise de Risco ML
            _MlRiskSection(),

            const SizedBox(height: AppSpacing.xl),

            // Alertas recentes
            expiringCritical.when(
              data: (batches) {
                if (batches.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: [
                    CasaSectionHeader(
                      title: 'Alertas Críticos',
                      count: batches.length,
                      action: 'Ver todos',
                      onAction: () => context.go(AppRoutes.alerts),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...batches.take(3).map(
                          (b) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.xs,
                            ),
                            child: _AlertBatchTile(batch: b),
                          ),
                        ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
      floatingActionButton: CasaFabScan(
        onPressed: () => context.push(AppRoutes.scanner),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.16 : 0.09),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.22),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedQuickAction extends StatelessWidget {
  final int delayMs;
  final Widget child;

  const _AnimatedQuickAction({
    required this.delayMs,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (_, value, c) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

class _AlertBatchTile extends StatelessWidget {
  final dynamic batch;
  const _AlertBatchTile({required this.batch});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger600.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.danger600.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded,
              color: AppColors.danger600, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.productName as String,
                  style: AppTypography.labelLarge.copyWith(
                    color: onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Vence em ${batch.daysToExpiry} dia(s) • ${batch.quantity} ${batch.quantity == 1 ? 'un' : 'uns'}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.danger600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI card colorido (linha horizontal)
// ---------------------------------------------------------------------------

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradientColors;
  final String? badge;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradientColors,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 22),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: AppTypography.numberMedium.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: const Offset(0, 1)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: gradientColors.first,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
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

class _KpiCardSkeleton extends StatelessWidget {
  const _KpiCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seção de Risco ML no dashboard
// ---------------------------------------------------------------------------

class _MlRiskSection extends ConsumerWidget {
  const _MlRiskSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(riskCountsProvider);
    final criticalAsync = ref.watch(criticalBatchPredictionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CasaSectionHeader(
          title: 'Análise de Risco ML',
          action: 'Ver detalhes',
          onAction: () => context.push(AppRoutes.mlInsights),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Contadores por nível
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: countsAsync.when(
            data: (counts) => RiskSummaryRow(counts: counts),
            loading: () => Row(
              children: List.generate(
                3,
                (_) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: CasaCardSkeleton(),
                  ),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Top críticos
        criticalAsync.when(
          data: (critical) {
            if (critical.isEmpty) return const SizedBox.shrink();
            return Column(
              children: critical.take(2).map(
                (p) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: RiskInsightCard(
                    prediction: p,
                    onTap: () => context.push(AppRoutes.mlInsights),
                  ),
                ),
              ).toList(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
