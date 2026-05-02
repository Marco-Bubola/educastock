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
                    child: _SearchField(
                      controller: _searchCtrl,
                      onChanged: (v) =>
                          setState(() => _query = v.toLowerCase()),
                      isDark: isDark,
                      cs: cs,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _FilterButton(
                    active: _activeFilterCount > 0,
                    badge: _activeFilterCount,
                    onTap: () =>
                        _openFilterModal(availableCategories, categoryLabelMap),
                    cs: cs,
                    isDark: isDark,
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
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.xs, AppSpacing.lg, AppSpacing.xxxl),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final catLabel = categoryLabelMap[p.category.name] ??
                          defaultCategoryLabel(p.category);
                      return _ProductGridCard(
                        product: p,
                        catLabel: catLabel,
                        index: i,
                        onTap: () => context.push('/products/${p.id}'),
                      );
                    },
                  );
                },
                loading: () => GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.75,
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

// ─── Card do grid ─────────────────────────────────────────────────────────

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

  Color _accent() {
    const colors = [
      AppColors.brandPrimary600,
      AppColors.secondaryBlue600,
      AppColors.success600,
      AppColors.warning600,
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
      AppColors.danger600,
      Color(0xFFDB2777),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final accent = _accent();
    final dateFmt = DateFormat('dd/MM/yy');

    // Lotes mais próximos ao vencimento
    final nearBatches = ref.watch(batchesByProductProvider(product.id)).whenOrNull(
          data: (batches) {
            final withExpiry = batches
                .where((b) => !b.noExpiry)
                .toList()
              ..sort((a, b) => a.daysToExpiry.compareTo(b.daysToExpiry));
            return withExpiry.take(2).toList();
          },
        ) ??
        [];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 200 + index * 20),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
          opacity: v,
          child: Transform.scale(scale: 0.85 + 0.15 * v, child: child)),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Cabeçalho colorido com ícone
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.72)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.card)),
                  ),
                  child: Center(
                    child: product.imageUrl != null &&
                            product.imageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.card)),
                            child: Image.network(product.imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 56),
                          )
                        : const Icon(Icons.inventory_2_rounded,
                            color: Colors.white, size: 26),
                  ),
                ),
                // ─── Informações
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: AppTypography.labelSmall.copyWith(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          catLabel,
                          style: AppTypography.labelSmall.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (product.isPerishable) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.warning600.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: const Text(
                              'Perecível',
                              style: TextStyle(
                                  fontSize: 8,
                                  color: AppColors.warning600,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                        // ─── Lotes mais próximos ao vencimento
                        if (nearBatches.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Divider(
                              height: 1,
                              thickness: 0.5,
                              color: cs.outlineVariant
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 4),
                          ...nearBatches.map((b) {
                            final statusColor = b.isExpired
                                ? AppColors.danger600
                                : b.daysToExpiry <= 7
                                    ? AppColors.danger600
                                    : b.daysToExpiry <= 30
                                        ? AppColors.warning600
                                        : AppColors.success600;
                            final dateStr = b.expiryDate != null
                                ? dateFmt.format(b.expiryDate!)
                                : '—';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.event_rounded,
                                      size: 10, color: statusColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: statusColor,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '(${b.daysToExpiry}d)',
                                    style: TextStyle(
                                        fontSize: 8,
                                        color: statusColor
                                            .withValues(alpha: 0.75)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
