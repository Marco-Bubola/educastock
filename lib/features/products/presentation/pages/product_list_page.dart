import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../controllers/products_provider.dart';

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Estoque')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
              child: CasaSearchBar(
                controller: _searchController,
                hint: 'Buscar produto...',
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                showFilter: true,
              ),
            ),
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  final filtered = _query.isEmpty
                      ? products
                      : products
                          .where((p) =>
                              p.name.toLowerCase().contains(_query) ||
                              (p.brand?.toLowerCase().contains(_query) ??
                                  false) ||
                              (p.barcode?.contains(_query) ?? false))
                          .toList();

                  if (filtered.isEmpty) {
                    return CasaEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: _query.isEmpty
                          ? 'Nenhum produto cadastrado'
                          : 'Nenhum resultado',
                      description: _query.isEmpty
                          ? 'Escaneie um código de barras para começar.'
                          : 'Tente outra busca.',
                      ctaLabel: _query.isEmpty ? 'Escanear produto' : null,
                      onCta: _query.isEmpty
                          ? () => context.push(AppRoutes.scanner)
                          : null,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      return InkWell(
                        onTap: () =>
                            context.push('/products/${p.id}'),
                        borderRadius:
                            BorderRadius.circular(AppRadius.card),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.card),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary100,
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.small),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppColors.brandPrimary600,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: AppTypography.labelLarge
                                          .copyWith(
                                              color: AppColors.neutral900,
                                              fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${p.categoryLabel} • ${p.unit}${p.brand != null ? ' • ${p.brand}' : ''}',
                                      style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.neutral500),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                p.isPerishable
                                    ? Icons.schedule_rounded
                                    : Icons.all_inclusive_rounded,
                                size: 16,
                                color: p.isPerishable
                                    ? AppColors.warning600
                                    : AppColors.neutral500,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.neutral500, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: 6,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, __) => const CasaCardSkeleton(),
                ),
                error: (e, _) => CasaEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Erro ao carregar',
                  description: e.toString(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: CasaFabScan(
        onPressed: () => context.push(AppRoutes.scanner),
      ),
    );
  }
}
