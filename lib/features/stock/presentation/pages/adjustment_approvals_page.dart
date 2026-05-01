import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../data/datasources/stock_remote_datasource.dart';

final _stockDatasourceProvider = Provider<StockRemoteDatasource>(
  (_) => StockRemoteDatasource(),
);

final pendingAdjustmentsProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref.read(_stockDatasourceProvider).watchPendingAdjustmentApprovals(),
);

class AdjustmentApprovalsPage extends ConsumerWidget {
  const AdjustmentApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    if (currentUser == null || !currentUser.canApproveAdjustments) {
      return Scaffold(
        appBar: const ModernProfileAppBar(
          title: 'Aprovações de Ajuste',
          subtitle: 'Acesso restrito',
          showBackButton: true,
        ),
        body: const Center(
          child: Text('Acesso permitido apenas para administradores.'),
        ),
      );
    }

    final requestsAsync = ref.watch(pendingAdjustmentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ModernProfileAppBar(
        title: 'Aprovações de Ajuste',
        subtitle: 'Solicitações pendentes',
        showBackButton: true,
      ),
      body: SafeArea(
        child: requestsAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return const CasaEmptyState(
                icon: Icons.verified_outlined,
                title: 'Nenhuma solicitação pendente',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final req = requests[i];
                final requestId = req['id'] as String;
                final productName = req['productName'] as String? ?? '-';
                final qty = (req['quantity'] as num?)?.toInt() ?? 0;
                final requestedByName = req['requestedByName'] as String? ?? '-';
                final reason = req['reason'] as String? ?? 'Sem motivo';

                return Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: AppTypography.headingSmall.copyWith(
                          color: AppColors.neutral900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Qtd ajuste: $qty • Solicitado por: $requestedByName',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Motivo: $reason',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.neutral700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: CasaButton(
                              label: 'Aprovar',
                              onPressed: () async {
                                await ref
                                    .read(_stockDatasourceProvider)
                                    .processAdjustmentApproval(
                                      requestId: requestId,
                                      approve: true,
                                      approverId: currentUser.id,
                                      approverName: currentUser.name,
                                    );
                                if (context.mounted) {
                                  showCasaSnackbar(
                                    context,
                                    message: 'Ajuste aprovado.',
                                    isSuccess: true,
                                  );
                                }
                              },
                              icon: Icons.check_circle_outline,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: CasaButton(
                              label: 'Rejeitar',
                              variant: CasaButtonVariant.secondary,
                              onPressed: () async {
                                await ref
                                    .read(_stockDatasourceProvider)
                                    .processAdjustmentApproval(
                                      requestId: requestId,
                                      approve: false,
                                      approverId: currentUser.id,
                                      approverName: currentUser.name,
                                    );
                                if (context.mounted) {
                                  showCasaSnackbar(
                                    context,
                                    message: 'Solicitação rejeitada.',
                                    isSuccess: true,
                                  );
                                }
                              },
                              icon: Icons.close_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
        ),
      ),
    );
  }
}
