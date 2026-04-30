import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../controllers/scanner_provider.dart';
import '../../../products/presentation/controllers/products_provider.dart';

class ProductReviewPage extends ConsumerWidget {
  final String barcode;

  const ProductReviewPage({super.key, required this.barcode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(scannerProvider);
    final localProduct = ref.watch(productByBarcodeProvider(barcode));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ModernProfileAppBar(
        title: 'Revisão de Dados',
        subtitle: 'Confirme as informações do produto',
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner código detectado
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary100,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_rounded,
                        color: AppColors.brandPrimary600, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Código detectado',
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.brandPrimary800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            barcode,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.brandPrimary600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Produto já cadastrado no sistema?
              localProduct.when(
                data: (product) {
                  if (product != null) {
                    return Column(
                      children: [
                        _ProductFoundCard(
                          name: product.name,
                          brand: product.brand ?? '',
                          category: product.categoryLabel,
                          isFromLocal: true,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        CasaButton(
                          label: 'Cadastrar Lote para este Produto',
                          icon: Icons.add_box_rounded,
                          onPressed: () => context.push(
                            '${AppRoutes.batchForm}?productId=${product.id}',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        CasaButton(
                          label: 'Editar Produto',
                          variant: CasaButtonVariant.secondary,
                          onPressed: () => context.push(
                            '${AppRoutes.productForm}?id=${product.id}',
                          ),
                        ),
                      ],
                    );
                  }
                  // Não encontrado local — busca na API
                  return scanState.apiResult.when(
                    data: (apiResult) {
                      if (apiResult == null) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }
                      if (!apiResult.found) {
                        return Column(
                          children: [
                            CasaEmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'Produto não encontrado',
                              description:
                                  'Não encontramos dados para este código. Preencha as informações manualmente.',
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            CasaButton(
                              label: 'Cadastrar Manualmente',
                              icon: Icons.edit_rounded,
                              onPressed: () => context.push(
                                '${AppRoutes.productForm}?barcode=$barcode',
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _ProductFoundCard(
                            name: apiResult.name ?? '',
                            brand: apiResult.brand ?? '',
                            category: apiResult.category ?? '',
                            imageUrl: apiResult.imageUrl,
                            isFromLocal: false,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.warning600.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    color: AppColors.warning600, size: 16),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'Dados da API. Confirme nome, categoria e informe a validade físicamente.',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.warning600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          CasaButton(
                            label: 'Confirmar e Cadastrar',
                            icon: Icons.check_rounded,
                            onPressed: () => context.push(
                              '${AppRoutes.productForm}?barcode=$barcode'
                              '&name=${Uri.encodeComponent(apiResult.name ?? '')}'
                              '&brand=${Uri.encodeComponent(apiResult.brand ?? '')}'
                              '&category=${apiResult.category ?? ''}',
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: AppSpacing.md),
                            Text('Buscando dados do produto...'),
                          ],
                        ),
                      ),
                    ),
                    error: (_, __) => CasaEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Sem conexão',
                      description: 'Não foi possível buscar dados da API.',
                      ctaLabel: 'Cadastrar Manualmente',
                      onCta: () => context.push(
                        '${AppRoutes.productForm}?barcode=$barcode',
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductFoundCard extends StatelessWidget {
  final String name;
  final String brand;
  final String category;
  final String? imageUrl;
  final bool isFromLocal;

  const _ProductFoundCard({
    required this.name,
    required this.brand,
    required this.category,
    this.imageUrl,
    required this.isFromLocal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.small),
              child: Image.network(
                imageUrl!,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              ),
            )
          else
            _placeholder(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isFromLocal
                            ? AppColors.success600.withValues(alpha: 0.12)
                            : AppColors.info600.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        isFromLocal ? 'Sistema' : 'API',
                        style: AppTypography.labelSmall.copyWith(
                          color: isFromLocal
                              ? AppColors.success600
                              : AppColors.info600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  name,
                  style: AppTypography.headingSmall.copyWith(
                    color: AppColors.neutral900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (brand.isNotEmpty)
                  Text(
                    brand,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                if (category.isNotEmpty)
                  Text(
                    category,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.brandPrimary600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: const Icon(Icons.inventory_2_outlined,
          color: AppColors.neutral500, size: 28),
    );
  }
}
