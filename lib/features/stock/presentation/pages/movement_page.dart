import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/controllers/products_provider.dart';
import '../../../recipes/domain/entities/stock_recipe.dart';
import '../../../recipes/presentation/controllers/recipes_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../../data/datasources/stock_remote_datasource.dart';
import '../../domain/entities/stock_movement.dart';

enum _OutputMode { products, recipes }

final stockDatasourceProvider = Provider<StockRemoteDatasource>(
  (_) => StockRemoteDatasource(),
);

class MovementPage extends ConsumerStatefulWidget {
  final String batchId;
  const MovementPage({super.key, required this.batchId});

  @override
  ConsumerState<MovementPage> createState() => _MovementPageState();
}

class _MovementPageState extends ConsumerState<MovementPage> {
  final _searchController = TextEditingController();
  final _activityController = TextEditingController();

  _OutputMode _mode = _OutputMode.products;
  String _search = '';
  String? _categoryKey;
  String _reasonCode = MovementReasonCode.uso.name;
  String? _selectedRecipeId;
  final Map<String, int> _selectedQtyByProduct = {};
  bool _isLoading = false;

  static const _reasonLabels = {
    'uso': 'Uso/Distribuição',
    'validade': 'Vencimento',
    'avaria': 'Avaria/Perda',
    'outro': 'Outro',
  };

  @override
  void dispose() {
    _searchController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  int _availableForProduct(String productId, List<Batch> batches) {
    return batches
        .where((b) => b.productId == productId && b.status == BatchStatus.disponivel)
        .fold<int>(0, (acc, b) => acc + b.quantity);
  }

  Future<void> _openFilterModal({
    required List<String> categoryKeys,
    required Map<String, String> categoryLabelMap,
  }) async {
    String? draftCategory = _categoryKey;
    String draftReason = _reasonCode;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filtros de saída', style: AppTypography.headingMedium),
                  const SizedBox(height: AppSpacing.md),
                  Text('Categoria', style: AppTypography.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ChoiceChip(
                        label: const Text('Todas'),
                        selected: draftCategory == null,
                        onSelected: (_) => setSheetState(() => draftCategory = null),
                      ),
                      ...categoryKeys.map(
                        (key) => ChoiceChip(
                          label: Text(categoryLabelMap[key] ?? key),
                          selected: draftCategory == key,
                          onSelected: (_) => setSheetState(() => draftCategory = key),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('Motivo da saída', style: AppTypography.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: _reasonLabels.entries
                        .map(
                          (e) => ChoiceChip(
                            label: Text(e.value),
                            selected: draftReason == e.key,
                            onSelected: (_) => setSheetState(() => draftReason = e.key),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _categoryKey = null;
                              _reasonCode = MovementReasonCode.uso.name;
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Limpar'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: CasaButton(
                          label: 'Aplicar filtros',
                          onPressed: () {
                            setState(() {
                              _categoryKey = draftCategory;
                              _reasonCode = draftReason;
                            });
                            Navigator.pop(ctx);
                          },
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
    );
  }

  Future<void> _submitProducts(List<Product> products) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final requests = <ProductOutputRequest>[];
    for (final entry in _selectedQtyByProduct.entries) {
      if (entry.value <= 0) continue;
      final product = products.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => Product(
          id: entry.key,
          name: 'Produto',
          category: ProductCategory.outro,
          unit: 'un',
          isPerishable: true,
          createdAt: DateTime.now(),
          createdBy: user.id,
        ),
      );
      requests.add(
        ProductOutputRequest(
          productId: product.id,
          productName: product.name,
          quantity: entry.value,
        ),
      );
    }

    if (requests.isEmpty) {
      showCasaSnackbar(
        context,
        message: 'Selecione ao menos um produto com quantidade.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(stockDatasourceProvider).registerBulkOutputFefo(
            items: requests,
            performedBy: user.id,
            performedByName: user.name,
            reasonCode: _reasonCode,
            reason: _reasonLabels[_reasonCode],
            activity: _activityController.text.trim().isEmpty
                ? null
                : _activityController.text.trim(),
          );
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: 'Saída registrada com sucesso!',
        isSuccess: true,
      );
      setState(() => _selectedQtyByProduct.clear());
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRecipe(StockRecipe recipe) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(recipesNotifierProvider.notifier).executeRecipe(recipe);
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: 'Saída por receita registrada com sucesso!',
        isSuccess: true,
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final batchesAsync = ref.watch(allAvailableBatchesProvider);
    final recipesAsync = ref.watch(recipesProvider);
    final categoryLabelMap = ref.watch(categoryLabelMapProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: ModernProfileAppBar(
        title: 'Saída de Estoque',
        subtitle: 'Produtos avulsos ou receita ativa',
        showBackButton: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.danger600.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'SAÍDA',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.danger600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: batchesAsync.when(
          data: (batches) => productsAsync.when(
            data: (products) {
              final categories = products.map((e) => e.category.name).toSet().toList()..sort();
              final filteredProducts = products.where((p) {
                final q = _search.trim().toLowerCase();
                final searchOk = q.isEmpty ||
                    p.name.toLowerCase().contains(q) ||
                    (p.brand?.toLowerCase().contains(q) ?? false);
                final categoryOk = _categoryKey == null || p.category.name == _categoryKey;
                return searchOk && categoryOk;
              }).toList();

              final width = MediaQuery.of(context).size.width;
              final cross = width >= 900
                  ? 4
                  : width >= 700
                      ? 3
                      : 2;

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Produtos avulsos'),
                          selected: _mode == _OutputMode.products,
                          onSelected: (_) => setState(() => _mode = _OutputMode.products),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Receita ativa'),
                          selected: _mode == _OutputMode.recipes,
                          onSelected: (_) => setState(() => _mode = _OutputMode.recipes),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: CasaTextField(
                          label: 'Busca rápida',
                          controller: _searchController,
                          hint: 'Nome ou marca',
                          onChanged: (v) => setState(() => _search = v),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.filledTonal(
                        onPressed: () => _openFilterModal(
                          categoryKeys: categories,
                          categoryLabelMap: categoryLabelMap,
                        ),
                        icon: const Icon(Icons.tune_rounded),
                        tooltip: 'Filtros',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      if (_categoryKey != null)
                        Chip(label: Text(categoryLabelMap[_categoryKey] ?? _categoryKey!)),
                      Chip(label: Text(_reasonLabels[_reasonCode] ?? 'Uso/Distribuição')),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CasaTextField(
                    label: 'Atividade / Projeto (opcional)',
                    controller: _activityController,
                    prefixIcon: const Icon(Icons.work_outline_rounded, size: 20),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_mode == _OutputMode.products) ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredProducts.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 0.82,
                      ),
                      itemBuilder: (_, i) {
                        final p = filteredProducts[i];
                        final available = _availableForProduct(p.id, batches);
                        final qty = _selectedQtyByProduct[p.id] ?? 0;

                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color: qty > 0
                                  ? AppColors.brandPrimary600
                                  : Theme.of(context).dividerColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(AppRadius.small),
                                  child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          p.imageUrl!,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: AppColors.brandPrimary100,
                                            child: const Center(child: Icon(Icons.inventory_2_outlined)),
                                          ),
                                        )
                                      : Container(
                                          color: AppColors.brandPrimary100,
                                          child: const Center(child: Icon(Icons.inventory_2_outlined)),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelSmall.copyWith(
                                  color: onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Disponível: $available ${p.unit}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: onSurfaceVariant,
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
                                    onPressed: qty > 0
                                        ? () => setState(() {
                                              final next = qty - 1;
                                              if (next <= 0) {
                                                _selectedQtyByProduct.remove(p.id);
                                              } else {
                                                _selectedQtyByProduct[p.id] = next;
                                              }
                                            })
                                        : null,
                                  ),
                                  Expanded(
                                    child: Text(
                                      '$qty',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.labelMedium.copyWith(color: onSurface),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                                    onPressed: available > qty
                                        ? () => setState(() {
                                              _selectedQtyByProduct[p.id] = qty + 1;
                                            })
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CasaButton(
                      label: 'Confirmar saída de produtos',
                      icon: Icons.outbound_rounded,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : () => _submitProducts(products),
                    ),
                  ] else ...[
                    recipesAsync.when(
                      data: (recipes) {
                        final filtered = recipes.where((r) {
                          final q = _search.trim().toLowerCase();
                          if (q.isEmpty) return true;
                          return r.name.toLowerCase().contains(q) ||
                              (r.description?.toLowerCase().contains(q) ?? false);
                        }).toList();

                        if (filtered.isEmpty) {
                          return const CasaEmptyState(
                            icon: Icons.menu_book_outlined,
                            title: 'Nenhuma receita ativa encontrada',
                          );
                        }

                        return Column(
                          children: [
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: cross,
                                mainAxisSpacing: AppSpacing.sm,
                                crossAxisSpacing: AppSpacing.sm,
                                childAspectRatio: 1.02,
                              ),
                              itemBuilder: (_, i) {
                                final r = filtered[i];
                                final selected = _selectedRecipeId == r.id;
                                return InkWell(
                                  onTap: () => setState(() => _selectedRecipeId = r.id),
                                  borderRadius: BorderRadius.circular(AppRadius.card),
                                  child: Container(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(AppRadius.card),
                                      border: Border.all(
                                        color: selected
                                            ? AppColors.brandPrimary600
                                            : Theme.of(context).dividerColor.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                r.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.labelLarge.copyWith(
                                                  color: onSurface,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            if (selected)
                                              const Icon(Icons.check_circle_rounded,
                                                  color: AppColors.brandPrimary600, size: 18),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${r.items.length} itens',
                                          style: AppTypography.bodySmall.copyWith(
                                            color: onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Expanded(
                                          child: Text(
                                            r.description ?? 'Sem descrição',
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.bodySmall.copyWith(
                                              color: onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            CasaButton(
                              label: 'Executar saída por receita',
                              icon: Icons.play_arrow_rounded,
                              isLoading: _isLoading,
                              onPressed: _isLoading || _selectedRecipeId == null
                                  ? null
                                  : () {
                                      final recipe = filtered.firstWhere((r) => r.id == _selectedRecipeId);
                                      _submitRecipe(recipe);
                                    },
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => CasaEmptyState(
                        icon: Icons.error_outline_rounded,
                        title: 'Erro ao carregar receitas',
                        description: e.toString(),
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erro: $e')),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
        ),
      ),
    );
  }
}
