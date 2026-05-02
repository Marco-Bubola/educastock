import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';

class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final alertsConfig = ref.watch(alertsConfigProvider);

    return alertsConfig.when(
      data: (config) {
        if (!config.expiryEnabled) {
          return Scaffold(
            backgroundColor: cs.surface,
            appBar: ModernProfileAppBar(
              title: 'Alertas de Vencimento',
              subtitle: 'Monitoramento de prazos',
              profileName: user?.name,
              onProfileTap: () => context.push(AppRoutes.settings),
            ),
            body: const SafeArea(
              child: CasaEmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'Alertas desativados',
                description:
                    'Ative em Configurações → Alertas para monitorar prazos.',
              ),
            ),
          );
        }

        final critical = ref.watch(expiringBatchesProvider(config.criticalDays));
        final warning = ref.watch(expiringBatchesProvider(config.warningDays));

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: ModernProfileAppBar(
            title: 'Alertas de Vencimento',
            subtitle: 'Priorize lotes críticos e de atenção',
            profileName: user?.name,
            onProfileTap: () => context.push(AppRoutes.settings),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  0, AppSpacing.sm, 0, AppSpacing.xxxl),
              children: [
                // ─── Banner resumo
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                      AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
                  child: Row(
                    children: [
                      critical.maybeWhen(
                        data: (b) => _SummaryPill(
                          label: 'Críticos',
                          count: b.length,
                          color: AppColors.danger600,
                          icon: Icons.warning_rounded,
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      warning.maybeWhen(
                        data: (b) {
                          final filtered = b
                              .where((x) =>
                                  x.daysToExpiry > config.criticalDays)
                              .length;
                          return _SummaryPill(
                            label: 'Atenção',
                            count: filtered,
                            color: AppColors.warning600,
                            icon: Icons.schedule_rounded,
                          );
                        },
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

                critical.when(
                  data: (batches) => _AlertSection(
                    title: 'Críticos (≤ ${config.criticalDays} dias)',
                    batches: batches,
                    color: AppColors.danger600,
                    icon: Icons.warning_rounded,
                    cs: cs,
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CasaCardSkeleton(),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                warning.when(
                  data: (batches) {
                    final filtered = batches
                        .where((b) => b.daysToExpiry > config.criticalDays)
                        .toList();
                    return _AlertSection(
                      title:
                          'Atenção (${config.criticalDays + 1}–${config.warningDays} dias)',
                      batches: filtered,
                      color: AppColors.warning600,
                      icon: Icons.schedule_rounded,
                      cs: cs,
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CasaCardSkeleton(),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
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
            title: 'Erro ao carregar configurações',
            description:
                'Não foi possível carregar as configurações de alertas.',
          ),
        ),
      ),
    );
  }
}

// ─── Pill de resumo ────────────────────────────────────────────────────────

class _SummaryPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _SummaryPill(
      {required this.label,
      required this.count,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Seção de alertas ──────────────────────────────────────────────────────

class _AlertSection extends StatelessWidget {
  final String title;
  final List<Batch> batches;
  final Color color;
  final IconData icon;
  final ColorScheme cs;

  const _AlertSection({
    required this.title,
    required this.batches,
    required this.color,
    required this.icon,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: AppTypography.labelLarge.copyWith(
                  color: color, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${batches.length}',
                style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ]),
        ),
        if (batches.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.success600.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                    color: AppColors.success600.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.success600, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Nenhum lote neste prazo. Ótimo!',
                    style: AppTypography.bodySmall
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
              child: _AlertBatchCard(batch: b, accentColor: color, cs: cs),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

// ─── Card de lote alerta ───────────────────────────────────────────────────

class _AlertBatchCard extends StatelessWidget {
  final Batch batch;
  final Color accentColor;
  final ColorScheme cs;

  const _AlertBatchCard(
      {required this.batch, required this.accentColor, required this.cs});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final days = batch.daysToExpiry;
    final isExpired = batch.isExpired;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border(
          left: BorderSide(color: accentColor, width: 3),
          top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
          right: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
          bottom: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(
              isExpired
                  ? Icons.cancel_outlined
                  : Icons.inventory_2_outlined,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.productName,
                  style: AppTypography.labelLarge
                      .copyWith(color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isExpired
                      ? 'Vencido'
                      : 'Vence em $days dia${days == 1 ? '' : 's'}${batch.expiryDate != null ? ' · ${fmt.format(batch.expiryDate!)}' : ''}',
                  style: AppTypography.bodySmall.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Qtd: ${batch.quantity} · ${batch.shelfLocation ?? 'Sem localização'}',
                  style: AppTypography.bodySmall
                      .copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              isExpired ? 'Vencido' : '${days}d',
              style: TextStyle(
                  fontSize: 12,
                  color: accentColor,
                  fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}


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
