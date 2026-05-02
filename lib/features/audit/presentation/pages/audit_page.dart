import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../stock/presentation/pages/movement_page.dart';

final auditLogsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(stockDatasourceProvider).watchAuditLogs(limit: 100);
});

class AuditPage extends ConsumerWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: const ModernProfileAppBar(
        title: 'Auditoria',
        subtitle: 'Histórico de alterações críticas',
        showBackButton: true,
      ),
      body: SafeArea(
        child: logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return const CasaEmptyState(
                icon: Icons.history_rounded,
                title: 'Nenhum log registrado',
                description: 'As alterações críticas aparecerão aqui.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              itemCount: logs.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _AuditLogTile(log: logs[i], cs: cs),
            );
          },
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 8,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const CasaCardSkeleton(),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar',
            description: e.toString(),
          ),
        ),
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  final Map<String, dynamic> log;
  final ColorScheme cs;
  const _AuditLogTile({required this.log, required this.cs});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final action = log['action'] as String? ?? '';
    final performedAt = log['performedAt'] as String? ?? '';
    final performedByName = log['performedByName'] as String? ?? 'Desconhecido';
    DateTime? date;
    try {
      date = DateTime.parse(performedAt);
    } catch (_) {}

    final color = switch (action) {
      'entrada' || 'ajustePositivo' => AppColors.success600,
      'saida' => AppColors.brandPrimary600,
      'ajusteNegativo' => AppColors.warning600,
      'descarte' => AppColors.danger600,
      _ => AppColors.neutral500,
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border(
          left: BorderSide(color: color, width: 3),
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(_actionIcon(action), color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _actionLabel(action),
                        style: AppTypography.labelMedium.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (date != null)
                      Text(
                        fmt.format(date),
                        style: AppTypography.bodySmall
                            .copyWith(color: cs.onSurfaceVariant, fontSize: 10),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Por: $performedByName',
                  style: AppTypography.bodySmall
                      .copyWith(color: cs.onSurfaceVariant),
                ),
                if (log['before'] != null || log['after'] != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      'Antes: ${log['before']}  →  Depois: ${log['after']}',
                      style: AppTypography.labelSmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _actionLabel(String action) => switch (action) {
        'entrada' => 'Entrada registrada',
        'saida' => 'Saída registrada',
        'ajustePositivo' => 'Ajuste positivo',
        'ajusteNegativo' => 'Ajuste negativo',
        'descarte' => 'Descarte registrado',
        _ => 'Operação: $action',
      };

  IconData _actionIcon(String action) => switch (action) {
        'entrada' => Icons.add_circle_outline_rounded,
        'saida' => Icons.outbound_rounded,
        'ajustePositivo' => Icons.trending_up_rounded,
        'ajusteNegativo' => Icons.trending_down_rounded,
        'descarte' => Icons.delete_outline_rounded,
        _ => Icons.history_rounded,
      };
}

