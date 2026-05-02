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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final alertsConfig = ref.watch(alertsConfigProvider);
    final allBatchesAsync = ref.watch(allAvailableBatchesProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ModernProfileAppBar(
        title: 'Alertas de Validade',
        subtitle: 'Monitore prazos e tome ação rápida',
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
      ),
      body: SafeArea(
        child: alertsConfig.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar configurações',
          ),
          data: (config) {
            if (!config.expiryEnabled) {
              return const CasaEmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'Alertas desativados',
                description:
                    'Ative em Configurações → Alertas para monitorar prazos.',
              );
            }

            return allBatchesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const CasaEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Erro ao carregar lotes',
              ),
              data: (all) {
                // Filtra apenas perecíveis vencidos ou a vencer
                final alertBatches =
                    all.where((b) => !b.noExpiry).toList();

                final expired = alertBatches
                    .where((b) => b.isExpired)
                    .toList()
                  ..sort((a, b) =>
                      a.daysToExpiry.compareTo(b.daysToExpiry));

                final critical = alertBatches
                    .where((b) =>
                        !b.isExpired &&
                        b.daysToExpiry <= config.criticalDays)
                    .toList()
                  ..sort((a, b) =>
                      a.daysToExpiry.compareTo(b.daysToExpiry));

                final warning = alertBatches
                    .where((b) =>
                        !b.isExpired &&
                        b.daysToExpiry > config.criticalDays &&
                        b.daysToExpiry <= config.warningDays)
                    .toList()
                  ..sort((a, b) =>
                      a.daysToExpiry.compareTo(b.daysToExpiry));

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                      0, AppSpacing.sm, 0, AppSpacing.xxxl),
                  children: [
                    // ── Banner de resumo
                    _StatsBanner(
                      expired: expired.length,
                      critical: critical.length,
                      warning: warning.length,
                      cs: cs,
                      isDark: isDark,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Seção: Vencidos
                    _AlertSection(
                      title: 'Vencidos',
                      subtitle: 'Remova ou descarte imediatamente',
                      icon: Icons.cancel_rounded,
                      accentColor: AppColors.danger600,
                      batches: expired,
                      emptyMessage: 'Nenhum lote vencido!',
                      cs: cs,
                      isDark: isDark,
                    ),

                    // ── Seção: Críticos
                    _AlertSection(
                      title: 'Críticos',
                      subtitle: '≤ ${config.criticalDays} dias para vencer',
                      icon: Icons.warning_rounded,
                      accentColor: const Color(0xFFE53E3E),
                      batches: critical,
                      emptyMessage: 'Sem lotes críticos!',
                      cs: cs,
                      isDark: isDark,
                    ),

                    // ── Seção: Atenção
                    _AlertSection(
                      title: 'Atenção',
                      subtitle:
                          '${config.criticalDays + 1}–${config.warningDays} dias',
                      icon: Icons.schedule_rounded,
                      accentColor: AppColors.warning600,
                      batches: warning,
                      emptyMessage: 'Sem lotes em atenção!',
                      cs: cs,
                      isDark: isDark,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── Banner de estatísticas ────────────────────────────────────────────────

class _StatsBanner extends StatelessWidget {
  final int expired;
  final int critical;
  final int warning;
  final ColorScheme cs;
  final bool isDark;

  const _StatsBanner({
    required this.expired,
    required this.critical,
    required this.warning,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final total = expired + critical + warning;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: total > 0
              ? [
                  AppColors.danger600.withValues(alpha: isDark ? 0.18 : 0.08),
                  AppColors.warning600.withValues(alpha: 0.03),
                ]
              : [
                  AppColors.success600.withValues(alpha: isDark ? 0.15 : 0.07),
                  AppColors.success600.withValues(alpha: 0.02),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: total > 0
              ? AppColors.danger600.withValues(alpha: 0.25)
              : AppColors.success600.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                total > 0
                    ? Icons.notifications_active_rounded
                    : Icons.check_circle_rounded,
                color: total > 0 ? AppColors.danger600 : AppColors.success600,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                total > 0
                    ? '$total item${total == 1 ? '' : 's'} precisam de atenção'
                    : 'Tudo em dia! Nenhum alerta ativo.',
                style: AppTypography.labelMedium.copyWith(
                  color: total > 0 ? AppColors.danger600 : AppColors.success600,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _StatChip(
                    label: 'Vencidos',
                    count: expired,
                    color: AppColors.danger600),
                const SizedBox(width: AppSpacing.sm),
                _StatChip(
                    label: 'Críticos',
                    count: critical,
                    color: const Color(0xFFE53E3E)),
                const SizedBox(width: AppSpacing.sm),
                _StatChip(
                    label: 'Atenção',
                    count: warning,
                    color: AppColors.warning600),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─── Seção com linha de timeline ───────────────────────────────────────────

class _AlertSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final List<Batch> batches;
  final String emptyMessage;
  final ColorScheme cs;
  final bool isDark;

  const _AlertSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.batches,
    required this.emptyMessage,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho da seção
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border:
                      Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: AppTypography.labelLarge.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '${batches.length}',
                            style: TextStyle(
                                fontSize: 11,
                                color: accentColor,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                          color: cs.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Estado vazio
          if (batches.isEmpty)
            Container(
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
                    emptyMessage,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.success600),
                  ),
                ],
              ),
            )
          else
            // Timeline
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha vertical com dots
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: List.generate(batches.length, (i) {
                        final isLast = i == batches.length - 1;
                        return Expanded(
                          child: Column(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(top: 16),
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: cs.surface, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                        color: accentColor
                                            .withValues(alpha: 0.4),
                                        blurRadius: 4),
                                  ],
                                ),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accentColor
                                          .withValues(alpha: 0.25),
                                      borderRadius:
                                          BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Cards
                  Expanded(
                    child: Column(
                      children: batches
                          .map((b) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: _AlertCard(
                                    batch: b,
                                    accentColor: accentColor,
                                    cs: cs,
                                    isDark: isDark),
                              ))
                          .toList(),
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

// ─── Card de lote com timeline ─────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final Batch batch;
  final Color accentColor;
  final ColorScheme cs;
  final bool isDark;

  const _AlertCard({
    required this.batch,
    required this.accentColor,
    required this.cs,
    required this.isDark,
  });

  String _urgencyLabel() {
    if (batch.isExpired) {
      final d = batch.daysToExpiry.abs();
      return 'Vencido há $d dia${d == 1 ? '' : 's'}';
    }
    final d = batch.daysToExpiry;
    if (d == 0) return 'Vence hoje!';
    return 'Vence em $d dia${d == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final fmtDate = DateFormat('dd/MM/yy');
    final fmtFull = DateFormat('dd/MM/yyyy');
    final b = batch;

    return GestureDetector(
      onTap: () =>
          context.push('${AppRoutes.productDetail}/${b.productId}'),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
            top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3)),
            right: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3)),
            bottom: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ícone
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppRadius.small),
                  ),
                  child: Icon(
                    b.isExpired
                        ? Icons.cancel_outlined
                        : Icons.inventory_2_outlined,
                    color: accentColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.productName,
                        style: AppTypography.labelLarge.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _urgencyLabel(),
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badge de dias
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                        color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    b.isExpired
                        ? 'Vencido'
                        : b.daysToExpiry == 0
                            ? 'Hoje'
                            : '${b.daysToExpiry}d',
                    style: TextStyle(
                        fontSize: 11,
                        color: accentColor,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Linha de chips de detalhes
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                // Qtd
                _DetailChip(
                  icon: Icons.widgets_outlined,
                  label: '${b.quantity} unid.',
                  cs: cs,
                ),
                // Lote
                if ((b.batchNumber ?? '').isNotEmpty)
                  _DetailChip(
                    icon: Icons.label_outline_rounded,
                    label: 'Lote ${b.batchNumber}',
                    cs: cs,
                  ),
                // Validade
                if (!b.noExpiry && b.expiryDate != null)
                  _DetailChip(
                    icon: Icons.event_rounded,
                    label: fmtFull.format(b.expiryDate!),
                    cs: cs,
                    color: accentColor,
                  ),
                // Localização
                if ((b.shelfLocation ?? '').isNotEmpty)
                  _DetailChip(
                    icon: Icons.location_on_rounded,
                    label: b.shelfLocation!,
                    cs: cs,
                  ),
                // Entrada
                _DetailChip(
                  icon: Icons.input_rounded,
                  label: 'Entrada: ${fmtDate.format(b.entryDate)}',
                  cs: cs,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final Color? color;

  const _DetailChip(
      {required this.icon,
      required this.label,
      required this.cs,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? cs.onSurfaceVariant;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.small),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, color: c, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

