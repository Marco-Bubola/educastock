import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../../domain/entities/product.dart';
import '../controllers/products_provider.dart';

// ─── Filtros ───────────────────────────────────────────────────────────────

enum _SortMode { name, category, perishable }

class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _filterPerishable = false;
  bool _filterNonPerishable = false;
  String? _filterCategory;
  _SortMode _sortMode = _SortMode.name;
  final _keySearch = GlobalKey();
  final _keyFilterBtn = GlobalKey();
  final _keyProductCard = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openFilterModal(
      List<String> categories, Map<String, String> categoryLabelMap) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterModal(
        filterPerishable: _filterPerishable,
        filterNonPerishable: _filterNonPerishable,
        filterCategory: _filterCategory,
        sortMode: _sortMode,
        categories: categories,
        categoryLabelMap: categoryLabelMap,
        onTogglePerishable: () =>
            setState(() => _filterPerishable = !_filterPerishable),
        onToggleNonPerishable: () =>
            setState(() => _filterNonPerishable = !_filterNonPerishable),
        onCategoryChanged: (v) => setState(() => _filterCategory = v),
        onSortChanged: (v) => setState(() => _sortMode = v),
        onClearAll: () => setState(() {
          _filterPerishable = false;
          _filterNonPerishable = false;
          _filterCategory = null;
          _sortMode = _SortMode.name;
        }),
      ),
    );
  }

  void _showManualBarcodeInput() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.modal)),
            ),
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                Text('Código de barras manual',
                    style: AppTypography.headingSmall.copyWith(
                        color: cs.onSurface, fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                    'Digite o código para verificar se o produto já existe.',
                    style: AppTypography.bodySmall
                        .copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Ex: 7891234567890',
                    prefixIcon: const Icon(Icons.qr_code_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input)),
                    labelText: 'Código de barras',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final barcode = ctrl.text.trim();
                      if (barcode.isEmpty) return;
                      Navigator.of(ctx).pop();
                      context.push(
                          '${AppRoutes.productReview}?barcode=$barcode');
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brandPrimary600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.button)),
                    ),
                    child: const Text('Buscar produto'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Product> _applyFilters(List<Product> products) {
    var result = products.where((p) {
      final q = _query.trim().toLowerCase();
      if (q.isNotEmpty) {
        if (!p.name.toLowerCase().contains(q) &&
            !(p.brand?.toLowerCase().contains(q) ?? false) &&
            !(p.barcode?.contains(q) ?? false)) {
          return false;
        }
      }
      if (_filterPerishable && !p.isPerishable) return false;
      if (_filterNonPerishable && p.isPerishable) return false;
      if (_filterCategory != null && p.category.name != _filterCategory) {
        return false;
      }
      return true;
    }).toList();

    switch (_sortMode) {
      case _SortMode.name:
        result.sort((a, b) => a.name.compareTo(b.name));
      case _SortMode.category:
        result.sort((a, b) => a.category.name.compareTo(b.category.name));
      case _SortMode.perishable:
        result.sort((a, b) =>
            (b.isPerishable ? 1 : 0).compareTo(a.isPerishable ? 1 : 0));
    }
    return result;
  }

  int get _activeFilterCount {
    int c = 0;
    if (_filterPerishable) c++;
    if (_filterNonPerishable) c++;
    if (_filterCategory != null) c++;
    if (_sortMode != _SortMode.name) c++;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productsAsync = ref.watch(productsProvider);
    final user = ref.watch(currentUserProvider);
    final categoryLabelMap = ref.watch(categoryLabelMapProvider);
    final availableCategories = productsAsync.valueOrNull
            ?.map((p) => p.category.name)
            .toSet()
            .toList() ??
        [];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ModernProfileAppBar(
        title: 'Estoque',
        subtitle: 'Catálogo de produtos',
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keySearch,
                  title: 'Busca de Produtos',
                  description: 'Digite o nome ou parte do nome do produto para encontrá-lo instantaneamente no catálogo. A busca é feita em tempo real enquanto você digita.',
                  icon: Icons.search_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Busca por nome parcial: "feij" encontra "Feijão Carioca"',
                    'Combine busca com filtros para resultados precisos',
                    'A busca ignora maiúsculas e minúsculas',
                  ],
                ),
                TutorialStep(
                  key: _keyFilterBtn,
                  title: 'Filtros Avançados',
                  description: 'Filtre os produtos por categoria (Alimento, Higiene, etc.), perecibilidade ou ordene por nome. O badge azul indica quantos filtros estão ativos.',
                  icon: Icons.tune_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Filtre por "Perecíveis" para ver produtos com validade',
                    'Ordene A→Z para localizar rapidamente no estoque físico',
                    'Combine filtros para relatórios específicos de auditoria',
                  ],
                ),
                TutorialStep(
                  key: _keyProductCard,
                  title: 'Cartão de Produto',
                  description: 'Cada cartão mostra o produto com sua quantidade total em estoque, categoria e status de validade. A borda colorida indica a situação do produto.',
                  icon: Icons.inventory_2_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🟢 Verde = produto com validade segura (>30 dias)',
                    '🟡 Amarelo = atenção! Vence em até 30 dias',
                    '🔴 Vermelho = crítico! Vence em até 7 dias ou já venceu',
                    'Toque no cartão para ver todos os lotes e detalhes completos',
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.outbound_rounded),
            onPressed: () => context.push('${AppRoutes.movement}?batchId='),
            tooltip: 'Registrar saída',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Barra de busca e filtro
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Row(
                children: [
                  Expanded(
                    child: KeyedSubtree(
                      key: _keySearch,
                      child: _SearchField(
                        controller: _searchCtrl,
                        onChanged: (v) =>
                            setState(() => _query = v.toLowerCase()),
                        isDark: isDark,
                        cs: cs,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  KeyedSubtree(
                    key: _keyFilterBtn,
                    child: _FilterButton(
                      active: _activeFilterCount > 0,
                      badge: _activeFilterCount,
                      onTap: () =>
                          _openFilterModal(availableCategories, categoryLabelMap),
                      cs: cs,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // ─── Grade de produtos
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  final filtered = _applyFilters(products);
                  if (filtered.isEmpty) {
                    return CasaEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: _query.isEmpty && _activeFilterCount == 0
                          ? 'Nenhum produto cadastrado'
                          : 'Nenhum resultado',
                      description: _query.isEmpty && _activeFilterCount == 0
                          ? 'Escaneie um código de barras para começar.'
                          : 'Tente ajustar os filtros.',
                      ctaLabel: _query.isEmpty && _activeFilterCount == 0
                          ? 'Escanear produto'
                          : null,
                      onCta: _query.isEmpty && _activeFilterCount == 0
                          ? () => context.push(AppRoutes.scanner)
                          : null,
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                        AppSpacing.xs, AppSpacing.md, AppSpacing.xxxl),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.70,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final catLabel = categoryLabelMap[p.category.name] ??
                          defaultCategoryLabel(p.category);
                      final card = _ProductGridCard(
                        product: p,
                        catLabel: catLabel,
                        index: i,
                        onTap: () => context.push('/products/${p.id}'),
                      );
                      if (i == 0) {
                        return KeyedSubtree(
                          key: _keyProductCard,
                          child: card,
                        );
                      }
                      return card;
                    },
                  );
                },
                loading: () => GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: AppSpacing.xs,
                    crossAxisSpacing: AppSpacing.xs,
                    childAspectRatio: 0.70,
                  ),
                  itemCount: 8,
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'manual_entry_fab',
            onPressed: _showManualBarcodeInput,
            backgroundColor: cs.surfaceContainerHigh,
            foregroundColor: AppColors.brandPrimary600,
            elevation: 4,
            tooltip: 'Cadastro manual',
            child: const Icon(Icons.keyboard_rounded, size: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          CasaFabScan(
            onPressed: () => context.push(AppRoutes.scanner),
          ),
        ],
      ),
    );
  }
}

// ─── Campo de busca ───────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isDark;
  final ColorScheme cs;
  const _SearchField(
      {required this.controller,
      required this.onChanged,
      required this.isDark,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainer : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTypography.bodyMedium.copyWith(color: cs.onSurface),
        decoration: InputDecoration(
          hintText: 'Buscar produto...',
          hintStyle: AppTypography.bodyMedium
              .copyWith(color: cs.onSurfaceVariant),
          prefixIcon: Icon(Icons.search_rounded,
              color: cs.onSurfaceVariant, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded,
                      size: 16, color: cs.onSurfaceVariant),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 0),
          isDense: true,
        ),
      ),
    );
  }
}

// ─── Botão de filtro ──────────────────────────────────────────────────────

class _FilterButton extends StatelessWidget {
  final bool active;
  final int badge;
  final VoidCallback onTap;
  final ColorScheme cs;
  final bool isDark;
  const _FilterButton(
      {required this.active,
      required this.badge,
      required this.onTap,
      required this.cs,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [
                    AppColors.brandPrimary600,
                    AppColors.secondaryBlue600
                  ],
                )
              : null,
          color: active
              ? null
              : isDark
                  ? cs.surfaceContainer
                  : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active
                ? Colors.transparent
                : cs.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.brandPrimary600.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                Icons.tune_rounded,
                color: active ? Colors.white : cs.onSurfaceVariant,
                size: 20,
              ),
            ),
            if (badge > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.danger600,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Modal de filtros ────────────────────────────────────────────────────

class _FilterModal extends StatefulWidget {
  final bool filterPerishable;
  final bool filterNonPerishable;
  final String? filterCategory;
  final _SortMode sortMode;
  final List<String> categories;
  final Map<String, String> categoryLabelMap;
  final VoidCallback onTogglePerishable;
  final VoidCallback onToggleNonPerishable;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<_SortMode> onSortChanged;
  final VoidCallback onClearAll;

  const _FilterModal({
    required this.filterPerishable,
    required this.filterNonPerishable,
    required this.filterCategory,
    required this.sortMode,
    required this.categories,
    required this.categoryLabelMap,
    required this.onTogglePerishable,
    required this.onToggleNonPerishable,
    required this.onCategoryChanged,
    required this.onSortChanged,
    required this.onClearAll,
  });

  @override
  State<_FilterModal> createState() => _FilterModalState();
}

class _FilterModalState extends State<_FilterModal> {
  late bool _filterPerishable;
  late bool _filterNonPerishable;
  late String? _filterCategory;
  late _SortMode _sortMode;

  @override
  void initState() {
    super.initState();
    _filterPerishable = widget.filterPerishable;
    _filterNonPerishable = widget.filterNonPerishable;
    _filterCategory = widget.filterCategory;
    _sortMode = widget.sortMode;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          Row(
            children: [
              Text('Filtros',
                  style: AppTypography.headingSmall.copyWith(
                      color: cs.onSurface, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterPerishable = false;
                    _filterNonPerishable = false;
                    _filterCategory = null;
                    _sortMode = _SortMode.name;
                  });
                  widget.onClearAll();
                },
                child: Text('Limpar tudo',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.danger600)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Tipo',
              style: AppTypography.labelMedium.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _FilterChip(
                label: 'Perecível',
                icon: Icons.schedule_rounded,
                selected: _filterPerishable,
                color: AppColors.warning600,
                onTap: () {
                  setState(() => _filterPerishable = !_filterPerishable);
                  widget.onTogglePerishable();
                },
              ),
              _FilterChip(
                label: 'Não perecível',
                icon: Icons.shield_outlined,
                selected: _filterNonPerishable,
                color: AppColors.success600,
                onTap: () {
                  setState(
                      () => _filterNonPerishable = !_filterNonPerishable);
                  widget.onToggleNonPerishable();
                },
              ),
            ],
          ),
          if (widget.categories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Categoria',
                style: AppTypography.labelMedium.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: widget.categories.map((cat) {
                final label = widget.categoryLabelMap[cat] ?? cat;
                return _FilterChip(
                  label: label,
                  icon: Icons.category_outlined,
                  selected: _filterCategory == cat,
                  color: AppColors.secondaryBlue600,
                  onTap: () {
                    final next = _filterCategory == cat ? null : cat;
                    setState(() => _filterCategory = next);
                    widget.onCategoryChanged(next);
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text('Ordenar por',
              style: AppTypography.labelMedium.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _SortChip(
                label: 'A–Z',
                selected: _sortMode == _SortMode.name,
                onTap: () {
                  setState(() => _sortMode = _SortMode.name);
                  widget.onSortChanged(_SortMode.name);
                },
              ),
              _SortChip(
                label: 'Categoria',
                selected: _sortMode == _SortMode.category,
                onTap: () {
                  setState(() => _sortMode = _SortMode.category);
                  widget.onSortChanged(_SortMode.category);
                },
              ),
              _SortChip(
                label: 'Perecíveis primeiro',
                selected: _sortMode == _SortMode.perishable,
                onTap: () {
                  setState(() => _sortMode = _SortMode.perishable);
                  widget.onSortChanged(_SortMode.perishable);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary600,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
              child: const Text('Aplicar filtros'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: 0.15) : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.5)
                  : cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: selected ? color : cs.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: selected ? color : cs.onSurfaceVariant,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPrimary600.withValues(alpha: 0.12)
              : cs.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
              color: selected
                  ? AppColors.brandPrimary600.withValues(alpha: 0.4)
                  : cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color:
                selected ? AppColors.brandPrimary600 : cs.onSurfaceVariant,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Card do grid (4 por linha) ───────────────────────────────────────────

class _ProductGridCard extends ConsumerWidget {
  final Product product;
  final String catLabel;
  final int index;
  final VoidCallback onTap;

  const _ProductGridCard({
    required this.product,
    required this.catLabel,
    required this.index,
    required this.onTap,
  });

  // Paletas de alerta: vermelho (crítico/vencido), amarelo (atenção), verde (ok), azul (sem validade)
  static const _paletteRed    = [Color(0xFFDC2626), Color(0xFFB91C1C)];
  static const _paletteYellow = [Color(0xFFD97706), Color(0xFFB45309)];
  static const _paletteGreen  = [Color(0xFF059669), Color(0xFF047857)];
  static const _paletteBlue   = [Color(0xFF2563EB), Color(0xFF1D4ED8)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('dd/MM');

    final batchData = ref
        .watch(batchesByProductProvider(product.id))
        .whenOrNull(data: (batches) {
      final sorted = batches
          .where((b) => !b.noExpiry)
          .toList()
        ..sort((a, b) => a.daysToExpiry.compareTo(b.daysToExpiry));
      return sorted.firstOrNull;
    });

    // Status de validade — define palette e cores
    Color expiryColor;
    IconData expiryIcon;
    String? expiryLabel;
    List<Color> palette;

    if (!product.isPerishable || batchData == null) {
      expiryColor = const Color(0xFF60A5FA);
      expiryIcon = Icons.inventory_2_rounded;
      expiryLabel = null;
      palette = _paletteBlue;
    } else if (batchData.isExpired) {
      expiryColor = const Color(0xFFF87171);
      expiryIcon = Icons.cancel_rounded;
      expiryLabel = 'VENCIDO';
      palette = _paletteRed;
    } else if (batchData.daysToExpiry <= 7) {
      expiryColor = const Color(0xFFFCA5A5);
      expiryIcon = Icons.warning_amber_rounded;
      expiryLabel = batchData.expiryDate != null
          ? '${dateFmt.format(batchData.expiryDate!)} (${batchData.daysToExpiry}d)'
          : 'Crítico';
      palette = _paletteRed;
    } else if (batchData.daysToExpiry <= 30) {
      expiryColor = const Color(0xFFFDE68A);
      expiryIcon = Icons.schedule_rounded;
      expiryLabel = batchData.expiryDate != null
          ? '${dateFmt.format(batchData.expiryDate!)} (${batchData.daysToExpiry}d)'
          : 'Atenção';
      palette = _paletteYellow;
    } else {
      expiryColor = const Color(0xFF6EE7B7);
      expiryIcon = Icons.check_circle_rounded;
      expiryLabel = batchData.expiryDate != null
          ? '${dateFmt.format(batchData.expiryDate!)} (${batchData.daysToExpiry}d)'
          : null;
      palette = _paletteGreen;
    }

    final accent = palette[0];
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = accent.withValues(alpha: isDark ? 0.45 : 0.35);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 160 + index * 12),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) =>
          Opacity(opacity: v, child: Transform.scale(scale: 0.9 + 0.1 * v, child: child)),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.20 : 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header gradiente com ícone
              Container(
                height: 50,
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
                    // Círculo decorativo sutil
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Center(
                      child: product.imageUrl != null &&
                              product.imageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius:
                                  const BorderRadius.vertical(top: Radius.circular(11)),
                              child: Image.network(product.imageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 50),
                            )
                          : Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 1),
                              ),
                              child: const Icon(Icons.inventory_2_rounded,
                                  color: Colors.white, size: 16),
                            ),
                    ),
                  ],
                ),
              ),

              // ─── Faixa de status (validade) ─────────────────────────────
              if (product.isPerishable && expiryLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: expiryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                    border: Border(
                      bottom: BorderSide(
                          color: expiryColor.withValues(alpha: isDark ? 0.2 : 0.15)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(expiryIcon, size: 8, color: expiryColor),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          expiryLabel,
                          style: TextStyle(
                            fontSize: 8,
                            color: expiryColor,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── Corpo: nome + categoria ─────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFE5E7EB)
                              : const Color(0xFF111827),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      // Categoria chip mínimo
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.14 : 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          catLabel,
                          style: TextStyle(
                            fontSize: 8,
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}