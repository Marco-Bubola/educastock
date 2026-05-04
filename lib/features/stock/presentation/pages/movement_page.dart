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
            activity: null,
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
        title: 'Distribuição',
        subtitle: 'Produtos avulsos ou por receita',
        showBackButton: true,
      ),
      floatingActionButton: _mode == _OutputMode.products
          ? _ConfirmFab(
              isLoading: _isLoading,
              label: 'Confirmar Distribuição',
              icon: Icons.outbound_rounded,
              onPressed: () => _submitProducts(productsAsync.valueOrNull ?? []),
            )
          : recipesAsync.valueOrNull?.any((r) => r.id == _selectedRecipeId) == true
              ? _ConfirmFab(
                  isLoading: _isLoading,
                  label: 'Executar Receita',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () {
                    final recipe = recipesAsync.valueOrNull!
                        .firstWhere((r) => r.id == _selectedRecipeId);
                    _submitRecipe(recipe);
                  },
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
              final cross = width >= 700 ? 4 : 2;

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
                children: [
                  // ─── Tab selector moderno ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.input),
                    ),
                    child: Row(
                      children: [
                        _ModeTab(
                          label: 'Produto Avulso',
                          icon: Icons.inventory_2_rounded,
                          selected: _mode == _OutputMode.products,
                          onTap: () =>
                              setState(() => _mode = _OutputMode.products),
                        ),
                        _ModeTab(
                          label: 'Receita Ativa',
                          icon: Icons.menu_book_rounded,
                          selected: _mode == _OutputMode.recipes,
                          onTap: () =>
                              setState(() => _mode = _OutputMode.recipes),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // ─── Busca + filtro ───────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainer,
                            borderRadius:
                                BorderRadius.circular(AppRadius.input),
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.4)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _search = v),
                            style: AppTypography.bodyMedium
                                .copyWith(color: onSurface),
                            decoration: InputDecoration(
                              hintText: 'Buscar produto ou receita...',
                              hintStyle: AppTypography.bodySmall
                                  .copyWith(color: onSurfaceVariant),
                              prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: AppColors.neutral500),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            AppColors.brandPrimary600,
                            AppColors.secondaryBlue600
                          ]),
                          borderRadius:
                              BorderRadius.circular(AppRadius.input),
                        ),
                        child: IconButton(
                          onPressed: () => _openFilterModal(
                            categoryKeys: categories,
                            categoryLabelMap: categoryLabelMap,
                          ),
                          icon: const Icon(Icons.tune_rounded,
                              color: Colors.white, size: 18),
                          tooltip: 'Filtros',
                        ),
                      ),
                    ],
                  ),
                  // Chips de filtros ativos
                  if (_categoryKey != null || _reasonCode != MovementReasonCode.uso.name)
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        if (_categoryKey != null)
                          Chip(
                            label: Text(
                                categoryLabelMap[_categoryKey] ??
                                    _categoryKey!),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () =>
                                setState(() => _categoryKey = null),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (_reasonCode != MovementReasonCode.uso.name)
                          Chip(
                            label: Text(
                                _reasonLabels[_reasonCode] ??
                                    'Uso/Distribuição'),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => setState(() =>
                                _reasonCode = MovementReasonCode.uso.name),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_mode == _OutputMode.products) ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredProducts.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 0.80,
                      ),
                      itemBuilder: (_, i) {
                        final p = filteredProducts[i];
                        final available = _availableForProduct(p.id, batches);
                        final qty = _selectedQtyByProduct[p.id] ?? 0;

                        // Detecta proximidade de validade
                        final nearExpiry = batches.any((b) =>
                            b.productId == p.id &&
                            b.status == BatchStatus.disponivel &&
                            b.expiryDate != null &&
                            b.expiryDate!
                                    .difference(DateTime.now())
                                    .inDays <=
                                30);
                        final expiredBatch = batches.any((b) =>
                            b.productId == p.id &&
                            b.status == BatchStatus.disponivel &&
                            b.expiryDate != null &&
                            b.expiryDate!.isBefore(DateTime.now()));

                        final borderColor = qty > 0
                            ? AppColors.brandPrimary600
                            : expiredBatch
                                ? AppColors.danger600
                                : nearExpiry
                                    ? AppColors.warning600
                                    : Theme.of(context)
                                        .dividerColor
                                        .withValues(alpha: 0.35);
                        final bgColor = expiredBatch
                            ? AppColors.danger600.withValues(alpha: 0.06)
                            : nearExpiry
                                ? AppColors.warning600.withValues(alpha: 0.06)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerLow;

                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color: borderColor,
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
                              if (expiredBatch)
                                Text('VENCIDO',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.danger600,
                                        fontWeight: FontWeight.w800))
                              else if (nearExpiry)
                                Text('VENCE EM BREVE',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.warning600,
                                        fontWeight: FontWeight.w700)),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
                                crossAxisCount: width >= 700 ? 4 : 2,
                                mainAxisSpacing: AppSpacing.sm,
                                crossAxisSpacing: AppSpacing.sm,
                                childAspectRatio: 1.1,
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

// ─── FAB de confirmação ────────────────────────────────────────────────────

class _ConfirmFab extends StatelessWidget {
  final bool isLoading;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const _ConfirmFab(
      {required this.isLoading,
      required this.label,
      required this.icon,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: onPressed == null || isLoading
                ? null
                : const LinearGradient(colors: [
                    AppColors.brandPrimary600,
                    AppColors.secondaryBlue600
                  ]),
            color:
                onPressed == null || isLoading ? AppColors.neutral500 : null,
            borderRadius: BorderRadius.circular(AppRadius.button),
            boxShadow: onPressed == null
                ? []
                : [
                    BoxShadow(
                        color: AppColors.brandPrimary600
                            .withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
          ),
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Icon(icon, size: 20, color: Colors.white),
            label: Text(
              label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Tab selector moderno ─────────────────────────────────────────────────

class _ModeTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeTab(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(colors: [
                    AppColors.brandPrimary600,
                    AppColors.secondaryBlue600
                  ])
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
