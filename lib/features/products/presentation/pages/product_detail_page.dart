import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../controllers/products_provider.dart';

class ProductDetailPage extends ConsumerWidget {
  final String productId;
  const ProductDetailPage({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(batchesByProductProvider(productId));
    final productAsync = ref.watch(productByIdProvider(productId));
    final productName = productAsync.valueOrNull?.name ?? 'Produto';
    final productUnit = productAsync.valueOrNull?.unit ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ModernProfileAppBar(
        title: productName,
        subtitle: productUnit.isNotEmpty ? 'Unidade: $productUnit' : 'Lotes e histórico',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push('${AppRoutes.productForm}?id=$productId'),
          ),
        ],
      ),
      body: SafeArea(
        child: batchesAsync.when(
          data: (batches) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                // Summary
                CasaSectionHeader(
                  title: 'Lotes',
                  count: batches.length,
                  action: 'Novo Lote',
                  onAction: () =>
                      context.push('${AppRoutes.batchForm}?productId=$productId'),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (batches.isEmpty)
                  CasaEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Nenhum lote cadastrado',
                    description:
                        'Cadastre o primeiro lote para controlar a validade.',
                    ctaLabel: 'Cadastrar Lote',
                    onCta: () => context
                        .push('${AppRoutes.batchForm}?productId=$productId'),
                  )
                else
                  ...batches.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _BatchCard(batch: b),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('${AppRoutes.batchForm}?productId=$productId'),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  final dynamic batch;
  const _BatchCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final urgency = batch.expiryUrgency as int;
    final statusMap = {
      0: StockStatus.vencido,
      1: StockStatus.critico,
      2: StockStatus.atencao,
      3: StockStatus.ok,
      4: StockStatus.semValidade,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lote • ${batch.origin}',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.neutral900),
                ),
              ),
              CasaStatusChip(status: statusMap[urgency] ?? StockStatus.ok),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: Icons.numbers_rounded,
            label: 'Quantidade',
            value: '${batch.quantity}',
          ),
          if (!batch.noExpiry && batch.expiryDate != null)
            _InfoRow(
              icon: Icons.event_rounded,
              label: 'Validade',
              value: fmt.format(batch.expiryDate as DateTime),
            ),
          if ((batch.batchNumber as String?) != null)
            _InfoRow(
              icon: Icons.tag_rounded,
              label: 'Nº Lote',
              value: batch.batchNumber as String,
            ),
          if ((batch.unitPrice as num?) != null) ...[
            _InfoRow(
              icon: Icons.attach_money_rounded,
              label: 'Preço unitário',
              value: currencyFmt.format((batch.unitPrice as num).toDouble()),
            ),
            _InfoRow(
              icon: Icons.calculate_outlined,
              label: 'Total estimado',
              value: currencyFmt.format((batch.unitPrice as num).toDouble() * (batch.quantity as int)),
            ),
          ],
          if (batch.shelfLocation != null)
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Localização',
              value: batch.shelfLocation as String,
            ),
          if ((batch.imageUrl as String?) != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Image.network(
                batch.imageUrl as String,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                      '${AppRoutes.movement}?batchId=${batch.id}'),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Movimentar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    textStyle: AppTypography.buttonMedium,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.neutral500),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$label: ',
            style: AppTypography.bodySmall.copyWith(color: AppColors.neutral500),
          ),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.neutral900,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
