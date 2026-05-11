import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../data/datasources/stock_remote_datasource.dart';

final _keyApprovalCard = GlobalKey();

final _stockDatasourceProvider= Provider<StockRemoteDatasource>(
  (_) => StockRemoteDatasource(),
);

final pendingAdjustmentsProvider = StreamProvider<List<Map<String, dynamic>>>(
  (ref) => ref.read(_stockDatasourceProvider).watchPendingAdjustmentApprovals(),
);

class AdjustmentApprovalsPage extends ConsumerWidget {
  const AdjustmentApprovalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null || !currentUser.canApproveAdjustments) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: ModernProfileAppBar(
          title: 'Aprovações de Ajuste',
          subtitle: 'Acesso restrito',
          showBackButton: true,
          actions: [
            buildHelpButton(
              context: context,
              onPressed: () => showCasaTutorial(
                context: context,
                steps: [
                  TutorialStep(
                    key: _keyApprovalCard,
                    title: 'Aprovação de Ajustes',
                    description: 'Ajustes de estoque realizados por colaboradores ficam pendentes de aprovação pelo administrador. Revise cada ajuste, verifique o motivo e aprove ou rejeite.',
                    icon: Icons.approval_rounded,
                    align: ContentAlign.bottom,
                    hints: const [
                      'Ajustes incluem correções de quantidade e descarte por avaria',
                      'Verifique o motivo informado pelo colaborador',
                      'Aprovações ficam registradas no log de auditoria',
                      'Rejeições devolvem o estoque ao valor original',
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        body: const SafeArea(
          child: CasaEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Acesso restrito',
            description: 'Apenas administradores podem aprovar ajustes.',
          ),
        ),
      );
    }

    final requestsAsync = ref.watch(pendingAdjustmentsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ModernProfileAppBar(
        title: 'Aprovações de Ajuste',
        subtitle: 'Solicitações pendentes de revisão',
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyApprovalCard,
                  title: 'Aprovação de Ajustes',
                  description: 'Ajustes de estoque realizados por colaboradores ficam pendentes de aprovação pelo administrador. Revise cada ajuste, verifique o motivo e aprove ou rejeite.',
                  icon: Icons.approval_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Ajustes incluem correções de quantidade e descarte por avaria',
                    'Verifique o motivo informado pelo colaborador',
                    'Aprovações ficam registradas no log de auditoria',
                    'Rejeições devolvem o estoque ao valor original',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: requestsAsync.when(
          data: (requests) {
            if (requests.isEmpty) {
              return const CasaEmptyState(
                icon: Icons.verified_rounded,
                title: 'Tudo em dia!',
                description: 'Nenhuma solicitação de ajuste aguardando aprovação.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final req = requests[i];
                final requestId = req['id'] as String;
                final productName = req['productName'] as String? ?? '-';
                final qty = (req['quantity'] as num?)?.toInt() ?? 0;
                final requestedByName = req['requestedByName'] as String? ?? '-';
                final reason = req['reason'] as String? ?? 'Sem motivo';

                final card = _AdjustmentCard(
                  productName: productName,
                  qty: qty,
                  requestedByName: requestedByName,
                  reason: reason,
                  cs: cs,
                  onApprove: () async {
                    await ref
                        .read(_stockDatasourceProvider)
                        .processAdjustmentApproval(
                          requestId: requestId,
                          approve: true,
                          approverId: currentUser.id,
                          approverName: currentUser.name,
                        );
                    if (context.mounted) {
                      showCasaSnackbar(context,
                          message: 'Ajuste aprovado!', isSuccess: true);
                    }
                  },
                  onReject: () async {
                    await ref
                        .read(_stockDatasourceProvider)
                        .processAdjustmentApproval(
                          requestId: requestId,
                          approve: false,
                          approverId: currentUser.id,
                          approverName: currentUser.name,
                        );
                    if (context.mounted) {
                      showCasaSnackbar(context,
                          message: 'Solicitação rejeitada.', isSuccess: true);
                    }
                  },
                );
                if (i == 0) {
                  return KeyedSubtree(key: _keyApprovalCard, child: card);
                }
                return card;
              },
            );
          },
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 4,
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

class _AdjustmentCard extends StatelessWidget {
  final String productName;
  final int qty;
  final String requestedByName;
  final String reason;
  final ColorScheme cs;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _AdjustmentCard({
    required this.productName,
    required this.qty,
    required this.requestedByName,
    required this.reason,
    required this.cs,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border(
          left: BorderSide(color: AppColors.warning600, width: 3),
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.warning600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: AppColors.warning600, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(productName,
                        style: AppTypography.labelLarge.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      'Por $requestedByName',
                      style: AppTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  qty > 0 ? '+$qty' : '$qty',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.warning600,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
            child: Text(
              'Motivo: $reason',
              style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: CasaButton(
                  label: 'Aprovar',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: onApprove,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: CasaButton(
                  label: 'Rejeitar',
                  variant: CasaButtonVariant.secondary,
                  icon: Icons.close_rounded,
                  onPressed: onReject,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
