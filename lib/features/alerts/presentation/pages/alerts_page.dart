import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';

class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final alertsConfig = ref.watch(alertsConfigProvider);

    return alertsConfig.when(
      data: (config) {
        if (!config.expiryEnabled) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: ModernProfileAppBar(
              title: 'Alertas de vencimento',
              subtitle: 'Priorize lotes criticos e de atencao',
              profileName: user?.name,
              onProfileTap: () => context.push(AppRoutes.settings),
            ),
            body: const SafeArea(
              child: CasaEmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'Alertas de vencimento desativados',
                description:
                    'Ative novamente em Configuracoes de Alertas para visualizar esta tela.',
              ),
            ),
          );
        }

        final critical = ref.watch(expiringBatchesProvider(config.criticalDays));
        final warning = ref.watch(expiringBatchesProvider(config.warningDays));

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: ModernProfileAppBar(
            title: 'Alertas de vencimento',
            subtitle: 'Priorize lotes criticos e de atencao',
            profileName: user?.name,
            onProfileTap: () => context.push(AppRoutes.settings),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              children: [
                critical.when(
                  data: (batches) => _AlertSection(
                    title: 'Criticos (<= ${config.criticalDays} dias)',
                    batches: batches,
                    status: StockStatus.critico,
                    criticalDays: config.criticalDays,
                  ),
                  loading: () => const CasaCardSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                warning.when(
                  data: (batches) {
                    final filtered = batches
                        .where((b) => b.daysToExpiry > config.criticalDays)
                        .toList();
                    return _AlertSection(
                      title:
                          'Atencao (${config.criticalDays + 1}-${config.warningDays} dias)',
                      batches: filtered,
                      status: StockStatus.atencao,
                      criticalDays: config.criticalDays,
                    );
                  },
                  loading: () => const CasaCardSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: const ModernProfileAppBar(
          title: 'Alertas',
          subtitle: 'Erro ao carregar',
          showBackButton: true,
        ),
        body: const SafeArea(
          child: CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar configuracoes',
            description: 'Nao foi possivel carregar as configuracoes de alertas.',
          ),
        ),
      ),
    );
  }
}

class _AlertSection extends StatelessWidget {
  final String title;
  final List<dynamic> batches;
  final StockStatus status;
  final int criticalDays;

  const _AlertSection({
    required this.title,
    required this.batches,
    required this.status,
    required this.criticalDays,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CasaSectionHeader(title: title, count: batches.length),
        const SizedBox(height: AppSpacing.sm),
        if (batches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.success600.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success600, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Nenhum lote neste prazo.',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.success600),
                  ),
                ],
              ),
            ),
          )
        else
          ...batches.map(
            (b) => Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0,
                  AppSpacing.lg, AppSpacing.sm),
              child: _AlertBatchCard(batch: b, status: status),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _AlertBatchCard extends StatelessWidget {
  final dynamic batch;
  final StockStatus status;

  const _AlertBatchCard({required this.batch, required this.status});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final isExpired = batch.isExpired as bool;
    final days = batch.daysToExpiry as int;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: status == StockStatus.critico
              ? AppColors.danger600.withValues(alpha: 0.3)
              : AppColors.warning600.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.productName as String,
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.neutral900),
                ),
                const SizedBox(height: 2),
                Text(
                  isExpired
                      ? 'VENCIDO'
                      : 'Vence em $days dia${days == 1 ? '' : 's'} • ${fmt.format(batch.expiryDate as DateTime)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: status == StockStatus.critico
                        ? AppColors.danger600
                        : AppColors.warning600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Qtd: ${batch.quantity} • ${batch.shelfLocation ?? 'Sem localização'}',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.neutral500),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CasaStatusChip(status: status),
        ],
      ),
    );
  }
}
