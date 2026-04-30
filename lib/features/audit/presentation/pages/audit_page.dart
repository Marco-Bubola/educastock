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
    final logsAsync = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
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
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: logs.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _AuditLogTile(log: logs[i]),
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
  const _AuditLogTile({required this.log});

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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Icon(Icons.history_rounded, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _actionLabel(action),
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.neutral900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Por: $performedByName',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.neutral500),
                ),
                if (date != null)
                  Text(
                    fmt.format(date),
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.neutral500),
                  ),
                if (log['before'] != null || log['after'] != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Antes: ${log['before']}  →  Depois: ${log['after']}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.neutral500,
                      fontFamily: 'monospace',
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
}
