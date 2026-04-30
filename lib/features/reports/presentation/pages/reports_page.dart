import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBatches = ref.watch(allAvailableBatchesProvider);
    final expiring7 = ref.watch(expiringBatchesProvider(7));
    final expiring30 = ref.watch(expiringBatchesProvider(30));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ModernProfileAppBar(
        title: 'Relatórios',
        subtitle: 'Visão geral do estoque',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () {
              // TODO: Exportar PDF
            },
            tooltip: 'Exportar PDF',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            const CasaSectionHeader(title: 'Visão Geral do Estoque'),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.3,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  allBatches.when(
                    data: (b) => CasaInfoCard(
                      title: 'Lotes Disponíveis',
                      value: '${b.length}',
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.brandPrimary600,
                    ),
                    loading: () => const CasaCardSkeleton(),
                    error: (_, __) => const CasaInfoCard(
                        title: 'Lotes', value: '-',
                        icon: Icons.inventory_2_outlined),
                  ),
                  expiring7.when(
                    data: (b) => CasaInfoCard(
                      title: 'Críticos (≤7d)',
                      value: '${b.length}',
                      icon: Icons.warning_rounded,
                      iconColor: AppColors.danger600,
                    ),
                    loading: () => const CasaCardSkeleton(),
                    error: (_, __) => const CasaInfoCard(
                        title: 'Críticos', value: '-',
                        icon: Icons.warning_rounded,
                        iconColor: AppColors.danger600),
                  ),
                  expiring30.when(
                    data: (b) => CasaInfoCard(
                      title: 'Atenção (≤30d)',
                      value: '${b.length}',
                      icon: Icons.schedule_rounded,
                      iconColor: AppColors.warning600,
                    ),
                    loading: () => const CasaCardSkeleton(),
                    error: (_, __) => const CasaInfoCard(
                        title: 'Atenção', value: '-',
                        icon: Icons.schedule_rounded,
                        iconColor: AppColors.warning600),
                  ),
                  allBatches.when(
                    data: (b) {
                      final total = b.fold<int>(0, (sum, bt) => sum + bt.quantity);
                      return CasaInfoCard(
                        title: 'Total de Itens',
                        value: '$total',
                        icon: Icons.widgets_outlined,
                        iconColor: AppColors.secondaryBlue600,
                      );
                    },
                    loading: () => const CasaCardSkeleton(),
                    error: (_, __) => const CasaInfoCard(
                        title: 'Itens', value: '-',
                        icon: Icons.widgets_outlined),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            const CasaSectionHeader(title: 'Próximas a Vencer'),
            const SizedBox(height: AppSpacing.sm),
            expiring30.when(
              data: (batches) {
                if (batches.isEmpty) {
                  return const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: CasaEmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Nenhum item vencendo em 30 dias',
                    ),
                  );
                }
                final fmt = DateFormat('dd/MM/yyyy');
                return Column(
                  children: batches
                      .take(10)
                      .map(
                        (b) => Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0,
                              AppSpacing.lg, AppSpacing.sm),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.productName,
                                        style: AppTypography.labelLarge
                                            .copyWith(
                                                color: AppColors.neutral900),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        b.expiryDate != null
                                            ? fmt.format(b.expiryDate!)
                                            : 'Sem validade',
                                        style: AppTypography.bodySmall
                                            .copyWith(
                                                color: AppColors.neutral500),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${b.daysToExpiry}d',
                                  style: AppTypography.numberSmall.copyWith(
                                    color: b.daysToExpiry <= 7
                                        ? AppColors.danger600
                                        : AppColors.warning600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
