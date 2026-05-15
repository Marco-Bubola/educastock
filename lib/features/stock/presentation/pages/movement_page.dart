import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import 'output_view_page.dart';

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
  final _keyConfirmFab = GlobalKey();
  final _keySearchBar = GlobalKey();
  final _keyModeTabs = GlobalKey();
  final _keyProductGrid = GlobalKey();
  final _keyRecipeGrid = GlobalKey();

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

  Future<void> _openSummary(List<Product> products) async {
    if (_selectedQtyByProduct.isEmpty ||
        _selectedQtyByProduct.values.every((v) => v <= 0)) {
      showCasaSnackbar(context,
          message: 'Selecione ao menos um produto com quantidade.',
          isError: true);
      return;
    }
    final items = _selectedQtyByProduct.entries
        .where((e) => e.value > 0)
        .map((e) {
      final p = products.firstWhere((p) => p.id == e.key,
          orElse: () => Product(
                id: e.key,
                name: e.key,
                category: ProductCategory.outro,
                unit: 'un',
                isPerishable: false,
                createdAt: DateTime.now(),
                createdBy: '',
              ));
      return _SummaryItem(product: p, qty: e.value);
    }).toList();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SummarySheet(
        items: items,
        reasonLabel: _reasonLabels[_reasonCode] ?? 'Uso/Distribuição',
      ),
    );
    if (confirmed == true) {
      await _submitProducts(products);
    }
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
      final result = await ref.read(stockDatasourceProvider).registerBulkOutputFefo(
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
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OutputViewPage(output: result),
      ));
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
      context.go('/dashboard');
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
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () {
              final steps = <TutorialStep>[
                TutorialStep(
                  key: _keySearchBar,
                  title: 'Buscar Produto para Saída',
                  description:
                      'Digite o nome do produto ou receita que deseja distribuir. O sistema mostrará os itens disponíveis em estoque com suas quantidades e validades.',
                  icon: Icons.search_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Busca em tempo real enquanto você digita',
                    'Lotes com borda vermelha já estão vencidos',
                    '🟡 Amarelo = vence em até 30 dias — distribua primeiro!',
                    'Quantidade disponível aparece abaixo de cada produto',
                  ],
                ),
                TutorialStep(
                  key: _keyModeTabs,
                  title: 'Escolha o tipo de saída',
                  description:
                      'Use essas abas para alternar entre produto avulso e receita. Em receitas, você seleciona um modelo pronto e o sistema distribui todos os itens da receita.',
                  icon: Icons.swap_horiz_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Produto Avulso: selecione itens individualmente',
                    'Receita Ativa: escolhe um kit completo de distribuição',
                    'A aba selecionada fica destacada em azul',
                  ],
                ),
                if (_mode == _OutputMode.products)
                  TutorialStep(
                    key: _keyProductGrid,
                    title: 'Selecionar produtos e quantidades',
                    description:
                        'Cada card mostra o produto, validade e a quantidade disponível. Use os botões + e - para ajustar a quantidade que será distribuída.',
                    icon: Icons.inventory_2_rounded,
                    align: ContentAlign.top,
                    hints: const [
                      '🔴 Vermelho: produto vencido — não distribuir',
                      '🟡 Amarelo: vence em até 30 dias — prioridade',
                      '🟢 Verde: validade ok — distribuição normal',
                      'A quantidade escolhida aparece no canto do card',
                    ],
                  )
                else
                  TutorialStep(
                    key: _keyRecipeGrid,
                    title: 'Selecionar uma receita ativa',
                    description:
                        'Escolha um modelo de distribuição pronto. Ao selecionar, o sistema calcula automaticamente todas as quantidades necessárias.',
                    icon: Icons.menu_book_rounded,
                    align: ContentAlign.top,
                    hints: const [
                      'Toque no card para selecionar a receita',
                      'Confira a descrição e os ingredientes',
                      'Você pode voltar para Produto Avulso a qualquer momento',
                    ],
                  ),
                if (_mode == _OutputMode.products ||
                    (_mode == _OutputMode.recipes &&
                        _selectedRecipeId != null))
                  TutorialStep(
                    key: _keyConfirmFab,
                    title: 'Confirmar Distribuição',
                    description:
                        'Após selecionar as quantidades (ou escolher uma receita ativa), toque aqui para confirmar a saída. O sistema registra automaticamente quem distribuiu, quando e para qual finalidade.',
                    icon: Icons.send_rounded,
                    align: ContentAlign.top,
                    hints: const [
                      'Revise os itens e quantidades antes de confirmar',
                      'A saída deduz automaticamente do estoque disponível',
                      'O histórico de saídas fica registrado em "Histórico"',
                      'Não é possível desfazer uma saída confirmada',
                    ],
                  ),
              ];
              showCasaTutorial(
                context: context,
                steps: steps,
              );
            },
          ),
        ],
      ),
      floatingActionButton: _mode == _OutputMode.products
          ? KeyedSubtree(
              key: _keyConfirmFab,
              child: _ConfirmFab(
                isLoading: _isLoading,
                label: 'Confirmar Distribuição',
                icon: Icons.outbound_rounded,
                onPressed: () => _openSummary(productsAsync.valueOrNull ?? []),
              ),
            )
          : recipesAsync.valueOrNull?.any((r) => r.id == _selectedRecipeId) == true
              ? KeyedSubtree(
                  key: _keyConfirmFab,
                  child: _ConfirmFab(
                    isLoading: _isLoading,
                    label: 'Executar Receita',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () {
                      final recipe = recipesAsync.valueOrNull!
                          .firstWhere((r) => r.id == _selectedRecipeId);
                      _submitRecipe(recipe);
                    },
                  ),
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

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 100),
                children: [
                  // ─── Tab selector moderno ─────────────────────────
                  Container(
                    key: _keyModeTabs,
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
                    key: _keySearchBar,
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
                    KeyedSubtree(
                      key: _keyProductGrid,
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredProducts.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.72,
                        ),
                        itemBuilder: (_, i) {
                          final p = filteredProducts[i];
                          final available = _availableForProduct(p.id, batches);
                          final qty = _selectedQtyByProduct[p.id] ?? 0;
                          final isDark = Theme.of(context).brightness == Brightness.dark;

                          final nearExpiry = batches.any((b) =>
                              b.productId == p.id &&
                              b.status == BatchStatus.disponivel &&
                              b.expiryDate != null &&
                              b.expiryDate!.difference(DateTime.now()).inDays <= 30);
                          final expiredBatch = batches.any((b) =>
                              b.productId == p.id &&
                              b.status == BatchStatus.disponivel &&
                              b.expiryDate != null &&
                              b.expiryDate!.isBefore(DateTime.now()));

                          return _ProductOutputCard(
                            product: p,
                            available: available,
                            qty: qty,
                            isDark: isDark,
                            index: i,
                            nearExpiry: nearExpiry,
                            expiredBatch: expiredBatch,
                            onDecrement: qty > 0
                                ? () => setState(() {
                                      final next = qty - 1;
                                      if (next <= 0) {
                                        _selectedQtyByProduct.remove(p.id);
                                      } else {
                                        _selectedQtyByProduct[p.id] = next;
                                      }
                                    })
                                : null,
                            onIncrement: available > qty
                                ? () => setState(
                                      () => _selectedQtyByProduct[p.id] = qty + 1,
                                    )
                                : null,
                          );
                        },
                      ),
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
                            KeyedSubtree(
                              key: _keyRecipeGrid,
                              child: GridView.builder(
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

// ─── Card de produto para saída ────────────────────────────────────────────

class _ProductOutputCard extends StatelessWidget {
  final Product product;
  final int available;
  final int qty;
  final bool isDark;
  final int index;
  final bool nearExpiry;
  final bool expiredBatch;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _ProductOutputCard({
    required this.product,
    required this.available,
    required this.qty,
    required this.isDark,
    required this.index,
    required this.nearExpiry,
    required this.expiredBatch,
    required this.onDecrement,
    required this.onIncrement,
  });

  static const _paletteRed    = [Color(0xFFDC2626), Color(0xFFB91C1C)];
  static const _paletteYellow = [Color(0xFFD97706), Color(0xFFB45309)];
  static const _paletteGreen  = [Color(0xFF059669), Color(0xFF047857)];

  @override
  Widget build(BuildContext context) {
    // Cores de alerta conforme status de validade
    final List<Color> palette;
    if (expiredBatch) {
      palette = _paletteRed;
    } else if (nearExpiry) {
      palette = _paletteYellow;
    } else {
      palette = _paletteGreen;
    }
    final accent = palette[0];
    final selected = qty > 0;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final onCard = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827);
    final subColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? const Color(0xFF2563EB)
              : accent.withValues(alpha: isDark ? 0.25 : 0.18),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? const Color(0xFF2563EB).withValues(alpha: 0.18)
                : accent.withValues(alpha: isDark ? 0.08 : 0.06),
            blurRadius: selected ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header colorido ────────────────────────────────────────
          Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: palette,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                // Badge de quantidade se > 0
                if (selected)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: product.imageUrl != null &&
                          product.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(11)),
                          child: Image.network(product.imageUrl!,
                              width: double.infinity,
                              height: 52,
                              fit: BoxFit.cover),
                        )
                      : Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.inventory_2_rounded,
                              color: Colors.white, size: 16),
                        ),
                ),
              ],
            ),
          ),

          // ── Faixa status validade ─────────────────────────────────
          if (expiredBatch || nearExpiry)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
                border: Border(
                  bottom: BorderSide(
                      color: accent.withValues(alpha: isDark ? 0.2 : 0.12)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    expiredBatch
                        ? Icons.cancel_rounded
                        : Icons.schedule_rounded,
                    size: 8,
                    color: accent,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    expiredBatch ? 'VENCIDO' : 'VENCE EM BREVE',
                    style: TextStyle(
                      fontSize: 8,
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),

          // ── Info + contador ───────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(7, 5, 7, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onCard,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Disp: $available ${product.unit}',
                    style: TextStyle(
                      fontSize: 9,
                      color: subColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Contador
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.1 : 0.06),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: accent.withValues(
                              alpha: isDark ? 0.2 : 0.14)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: onDecrement,
                            child: Icon(
                              Icons.remove_rounded,
                              size: 14,
                              color: onDecrement != null
                                  ? accent
                                  : accent.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        Text(
                          '$qty',
                          style: TextStyle(
                            color: selected ? accent : subColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: onIncrement,
                            child: Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: onIncrement != null
                                  ? accent
                                  : accent.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dados para o resumo ───────────────────────────────────────────────────

class _SummaryItem {
  final Product product;
  final int qty;
  const _SummaryItem({required this.product, required this.qty});
}

// ─── Tela de resumo (bottom sheet) ────────────────────────────────────────

class _SummarySheet extends StatelessWidget {
  final List<_SummaryItem> items;
  final String reasonLabel;
  const _SummarySheet({required this.items, required this.reasonLabel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final onBg = isDark ? const Color(0xFFE5E7EB) : const Color(0xFF0F172A);
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final totalItems = items.fold<int>(0, (s, e) => s + e.qty);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: isDark
              ? Border.all(
                  color: const Color(0xFF1F2937).withValues(alpha: 0.6))
              : null,
        ),
        child: Column(
          children: [
            // ── Handle ────────────────────────────────────────────
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: sub.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.outbound_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumo da Distribuição',
                          style: TextStyle(
                            color: onBg,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '$reasonLabel  ·  ${items.length} produto${items.length != 1 ? 's' : ''}  ·  $totalItems ${totalItems != 1 ? 'unidades' : 'unidade'}',
                          style: TextStyle(
                              color: sub, fontSize: 11, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: sub.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: sub),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Divisor ───────────────────────────────────────────
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: sub.withValues(alpha: isDark ? 0.12 : 0.08),
            ),
            const SizedBox(height: 10),

            // ── Lista de itens ────────────────────────────────────
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final item = items[i];
                  return Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sub.withValues(alpha: isDark ? 0.12 : 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.15 : 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB)
                                .withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: isDark ? 0.25 : 0.15)),
                          ),
                          child: item.product.imageUrl != null &&
                                  item.product.imageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(7),
                                  child: Image.network(item.product.imageUrl!,
                                      fit: BoxFit.cover),
                                )
                              : const Icon(Icons.inventory_2_rounded,
                                  color: Color(0xFF2563EB), size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: TextStyle(
                                  color: onBg,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                item.product.category.name,
                                style:
                                    TextStyle(color: sub, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Quantidade
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB)
                                .withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: isDark ? 0.3 : 0.2)),
                          ),
                          child: Text(
                            '${item.qty} ${item.product.unit}',
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Botões ────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  MediaQuery.of(context).padding.bottom + 16),
              child: Column(
                children: [
                  // Aviso
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB)
                          .withValues(alpha: isDark ? 0.1 : 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2563EB)
                            .withValues(alpha: isDark ? 0.2 : 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'O sistema aplicará a regra FEFO — os lotes mais próximos do vencimento sairão primeiro.',
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF93C5FD)
                                    : const Color(0xFF1D4ED8),
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(false),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1F2937)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              'Voltar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: sub,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(true),
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2563EB),
                                  Color(0xFF1D4ED8)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.outbound_rounded,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Confirmar Saída',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
