import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final expiringCritical = ref.watch(expiringBatchesProvider(7));
    final expiringWarning = ref.watch(expiringBatchesProvider(30));
    final allBatches = ref.watch(allAvailableBatchesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EducaStock',
              style: AppTypography.headingMedium
                  .copyWith(color: AppColors.neutral900),
            ),
            Text(
              'Olá, ${user?.name.split(' ').first ?? 'Usuário'}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push(AppRoutes.alerts),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            // KPIs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.2,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Total lotes disponíveis
                  allBatches.when(
                    data: (batches) => CasaInfoCard(
                      title: 'Lotes Disponíveis',
                      value: '${batches.length}',
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.brandPrimary600,
                      onTap: () => context.push(AppRoutes.productList),
                    ),
                    loading: () => const CasaCardSkeleton(),
                    error: (_, __) => const CasaInfoCard(
                      title: 'Lotes Disponíveis',
                      value: '-',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),

                  // Críticos (vence em 7 dias)
                  expiringCritical.when(
                    data: (batches) => CasaInfoCard(
                      title: 'Vencem em 7 dias',
                      value: '${batches.length}',
                      icon: Icons.warning_rounded,
                      iconColor: AppColors.danger600,
                      backgroundColor: batches.isNotEmpty
                          ? AppColors.danger600.withValues(alpha: 0.05)
                          : null,
                      onTap: () => context.push(AppRoutes.alerts),
                    ),
                    loading: () => const CasaCardSkeleton(),
                    error: (_, __) => const CasaInfoCard(
                      title: 'Vencem em 7 dias',
                      value: '-',
                      icon: Icons.warning_rounded,
                      iconColor: AppColors.danger600,
                    ),
                  ),

                  // Atenção (30 dias)
                  expiringWarning.when(
                    data: (batches) => CasaInfoCard(
                      title: 'Vencem em 30 dias',
                      value: '${batches.length}',
                      icon: Icons.schedule_rounded,
                      iconColor: AppColors.warning600,
                      onTap: () => context.push(AppRoutes.alerts),
                    ),
                    loading: () => const CasaCardSkeleton(),
                    error: (_, __) => const CasaInfoCard(
                      title: 'Vencem em 30 dias',
                      value: '-',
                      icon: Icons.schedule_rounded,
                      iconColor: AppColors.warning600,
                    ),
                  ),

                  CasaInfoCard(
                    title: 'Relatórios',
                    value: 'Ver',
                    icon: Icons.bar_chart_rounded,
                    iconColor: AppColors.secondaryBlue600,
                    onTap: () => context.push(AppRoutes.reports),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Ações rápidas
            const CasaSectionHeader(title: 'Ações Rápidas'),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  _QuickActionTile(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Escanear Produto',
                    subtitle: 'Cadastrar entrada por código de barras',
                    color: AppColors.brandPrimary600,
                    onTap: () => context.push(AppRoutes.scanner),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _QuickActionTile(
                    icon: Icons.list_alt_rounded,
                    label: 'Estoque',
                    subtitle: 'Ver todos os produtos e lotes',
                    color: AppColors.secondaryBlue600,
                    onTap: () => context.push(AppRoutes.productList),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _QuickActionTile(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Movimentação',
                    subtitle: 'Registrar entrada, saída ou ajuste',
                    color: AppColors.success600,
                    onTap: () => context.push(
                        '${AppRoutes.movement}?batchId='),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _QuickActionTile(
                    icon: Icons.history_rounded,
                    label: 'Auditoria',
                    subtitle: 'Histórico de alterações',
                    color: AppColors.neutral700,
                    onTap: () => context.push(AppRoutes.audit),
                  ),
                ],
              ),
            ),

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
                      onAction: () => context.push(AppRoutes.alerts),
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
      bottomNavigationBar: NavigationBar(
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Estoque',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Alertas',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Relatórios',
          ),
        ],
        selectedIndex: 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go(AppRoutes.dashboard);
            case 1:
              context.go(AppRoutes.productList);
            case 2:
              context.go(AppRoutes.alerts);
            case 3:
              context.go(AppRoutes.reports);
          }
        },
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.neutral900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.neutral500, size: 20),
          ],
        ),
      ),
    );
  }
}

class _AlertBatchTile extends StatelessWidget {
  final dynamic batch;
  const _AlertBatchTile({required this.batch});

  @override
  Widget build(BuildContext context) {
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
                    color: AppColors.neutral900,
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
