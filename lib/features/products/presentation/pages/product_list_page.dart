import 'package:file_picker/file_picker.dart';
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

IconData _categoryIcon(ProductCategory cat) => switch (cat) {
  ProductCategory.alimento       => Icons.restaurant_rounded,
  ProductCategory.bebida         => Icons.local_drink_rounded,
  ProductCategory.limpeza        => Icons.cleaning_services_rounded,
  ProductCategory.higienePessoal => Icons.soap_rounded,
  ProductCategory.escolar        => Icons.auto_stories_rounded,
  ProductCategory.roupas         => Icons.checkroom_rounded,
  ProductCategory.outro          => Icons.category_rounded,
};

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

  List<Product> _applyFilters(
      List<Product> products, Map<String, int> stockMap) {
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

    int primarySort(Product a, Product b) {
      switch (_sortMode) {
        case _SortMode.name:
          return a.name.compareTo(b.name);
        case _SortMode.category:
          final byCat = a.category.name.compareTo(b.category.name);
          return byCat != 0 ? byCat : a.name.compareTo(b.name);
        case _SortMode.perishable:
          final byPer =
              (b.isPerishable ? 1 : 0).compareTo(a.isPerishable ? 1 : 0);
          return byPer != 0 ? byPer : a.name.compareTo(b.name);
      }
    }

    // Inativos (sem estoque) sempre por último, mas mantendo a ordem interna
    // de cada grupo conforme o sort selecionado.
    result.sort((a, b) {
      final aInactive = (stockMap[a.id] ?? 0) <= 0;
      final bInactive = (stockMap[b.id] ?? 0) <= 0;
      if (aInactive != bInactive) return aInactive ? 1 : -1;
      return primarySort(a, b);
    });
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
    final stockMap = ref.watch(productAvailableQtyMapProvider);
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
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            onPressed: () => _showCsvImportSheet(context),
            tooltip: 'Importar CSV',
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
                  final filtered = _applyFilters(products, stockMap);
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
                      childAspectRatio: 0.72,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final p = filtered[i];
                      final catLabel = categoryLabelMap[p.category.name] ??
                          defaultCategoryLabel(p.category);
                      final inactive = (stockMap[p.id] ?? 0) <= 0;
                      final card = _ProductGridCard(
                        product: p,
                        catLabel: catLabel,
                        index: i,
                        inactive: inactive,
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
                    childAspectRatio: 0.72,
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

  void _showCsvImportSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CsvImportSheet(parentRef: ref),
    );
  }
}

// ─── CSV Import Bottom Sheet ──────────────────────────────────────────────────

class _CsvImportSheet extends ConsumerStatefulWidget {
  final WidgetRef parentRef;
  const _CsvImportSheet({required this.parentRef});

  @override
  ConsumerState<_CsvImportSheet> createState() => _CsvImportSheetState();
}

class _CsvImportSheetState extends ConsumerState<_CsvImportSheet> {
  String? _fileName;
  String? _csvContent;
  bool _picking = false;

  Future<void> _pickFile() async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          setState(() {
            _fileName = file.name;
            _csvContent = String.fromCharCodes(bytes);
          });
        }
      }
    } finally {
      setState(() => _picking = false);
    }
  }

  Future<void> _doImport() async {
    if (_csvContent == null) return;
    final user = ref.read(currentUserProvider);
    final notifier = ref.read(csvImportProvider.notifier);
    final count =
        await notifier.importFromCsvString(_csvContent!, user?.id ?? 'system');
    if (!mounted) return;
    if (count > 0) {
      Navigator.of(context).pop();
      showCasaSnackbar(
        context,
        message: '$count produto(s) importado(s) com sucesso!',
        isError: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final importState = ref.watch(csvImportProvider);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary600.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: const Icon(Icons.upload_file_rounded,
                      color: AppColors.brandPrimary600, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Importar Produtos via CSV',
                          style: AppTypography.headingSmall.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700)),
                      Text(
                        'Formato: nome, categoria, código_barras, perecível',
                        style: AppTypography.bodySmall
                            .copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Instructions card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.secondaryBlue600.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                    color: AppColors.secondaryBlue600.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📋 Formato esperado do CSV:',
                      style: AppTypography.labelMedium
                          .copyWith(color: AppColors.secondaryBlue600)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'nome,categoria,codigo_barras,perecivel\n'
                    'Arroz Integral,alimento,7891234567890,sim\n'
                    'Detergente Liq.,limpeza,,nao\n\n'
                    'Categorias: alimento, bebida, limpeza,\n'
                    'higiene, escolar, roupas, outro',
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // File picker
            InkWell(
              onTap: _picking ? null : _pickFile,
              borderRadius: BorderRadius.circular(AppRadius.card),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: _csvContent != null
                        ? AppColors.success600
                        : cs.outlineVariant,
                    width: _csvContent != null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _csvContent != null
                          ? Icons.check_circle_rounded
                          : Icons.attach_file_rounded,
                      color: _csvContent != null
                          ? AppColors.success600
                          : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _picking
                            ? 'Selecionando arquivo...'
                            : _fileName ?? 'Toque para selecionar arquivo CSV',
                        style: AppTypography.bodyMedium.copyWith(
                          color: _csvContent != null
                              ? AppColors.success600
                              : cs.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_csvContent != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () =>
                            setState(() {
                              _fileName = null;
                              _csvContent = null;
                            }),
                        color: cs.onSurfaceVariant,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Progress / error
            if (importState.loading)
              Column(
                children: [
                  LinearProgressIndicator(
                    backgroundColor: cs.surfaceContainerHigh,
                    color: AppColors.brandPrimary600,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Importando produtos...',
                    style: AppTypography.bodySmall
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            if (importState.error != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.danger600.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_rounded,
                        color: AppColors.danger600, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(importState.error!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.danger600)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_csvContent == null || importState.loading)
                    ? null
                    : _doImport,
                icon: importState.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(importState.loading
                    ? 'Importando...'
                    : 'Importar Produtos'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

  int get _activeCount =>
      (_filterPerishable ? 1 : 0) +
      (_filterNonPerishable ? 1 : 0) +
      (_filterCategory != null ? 1 : 0) +
      (_sortMode != _SortMode.name ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = _activeCount;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────────────────
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),

          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.fromLTRB(20, 10, 12, 0),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D5FA8), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.30),
                        blurRadius: 8, offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.tune_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Filtros',
                          style: AppTypography.headingSmall.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w800)),
                      if (count > 0)
                        Text(
                          '$count filtro${count > 1 ? 's' : ''} ativo${count > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.brandPrimary600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterPerishable   = false;
                      _filterNonPerishable = false;
                      _filterCategory     = null;
                      _sortMode           = _SortMode.name;
                    });
                    widget.onClearAll();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger600,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Limpar',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Divider(
              color: cs.outlineVariant.withValues(alpha: 0.40),
              height: 1),

          // ── Corpo scrollable ──────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Seção: Tipo
                  _FilterSectionLabel(label: 'TIPO DE PRODUTO'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeToggleCard(
                          icon: Icons.schedule_rounded,
                          label: 'Perecível',
                          sublabel: 'Com validade',
                          selected: _filterPerishable,
                          color: AppColors.warning600,
                          isDark: isDark,
                          cs: cs,
                          onTap: () {
                            setState(() =>
                                _filterPerishable = !_filterPerishable);
                            widget.onTogglePerishable();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TypeToggleCard(
                          icon: Icons.shield_rounded,
                          label: 'Permanente',
                          sublabel: 'Sem validade',
                          selected: _filterNonPerishable,
                          color: AppColors.success600,
                          isDark: isDark,
                          cs: cs,
                          onTap: () {
                            setState(() =>
                                _filterNonPerishable = !_filterNonPerishable);
                            widget.onToggleNonPerishable();
                          },
                        ),
                      ),
                    ],
                  ),

                  // Seção: Categoria
                  if (widget.categories.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _FilterSectionLabel(label: 'CATEGORIA'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.categories.map((cat) {
                        final label =
                            widget.categoryLabelMap[cat] ?? cat;
                        final catEnum = ProductCategory.values.firstWhere(
                          (c) => c.name == cat,
                          orElse: () => ProductCategory.outro,
                        );
                        return _CategoryFilterChip(
                          icon: _categoryIcon(catEnum),
                          label: label,
                          selected: _filterCategory == cat,
                          isDark: isDark,
                          cs: cs,
                          onTap: () {
                            final next =
                                _filterCategory == cat ? null : cat;
                            setState(() => _filterCategory = next);
                            widget.onCategoryChanged(next);
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  // Seção: Ordenar
                  const SizedBox(height: 22),
                  _FilterSectionLabel(label: 'ORDENAR POR'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? cs.surfaceContainerHighest
                          : cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              cs.outlineVariant.withValues(alpha: 0.30)),
                    ),
                    child: Column(
                      children: [
                        _SortOptionItem(
                          icon: Icons.sort_by_alpha_rounded,
                          label: 'Nome (A → Z)',
                          selected: _sortMode == _SortMode.name,
                          isFirst: true, isLast: false,
                          cs: cs,
                          onTap: () {
                            setState(
                                () => _sortMode = _SortMode.name);
                            widget.onSortChanged(_SortMode.name);
                          },
                        ),
                        Divider(
                            height: 1,
                            indent: 50,
                            color: cs.outlineVariant
                                .withValues(alpha: 0.25)),
                        _SortOptionItem(
                          icon: Icons.category_rounded,
                          label: 'Categoria',
                          selected: _sortMode == _SortMode.category,
                          isFirst: false, isLast: false,
                          cs: cs,
                          onTap: () {
                            setState(() =>
                                _sortMode = _SortMode.category);
                            widget.onSortChanged(
                                _SortMode.category);
                          },
                        ),
                        Divider(
                            height: 1,
                            indent: 50,
                            color: cs.outlineVariant
                                .withValues(alpha: 0.25)),
                        _SortOptionItem(
                          icon: Icons.schedule_rounded,
                          label: 'Perecíveis primeiro',
                          selected:
                              _sortMode == _SortMode.perishable,
                          isFirst: false, isLast: true,
                          cs: cs,
                          onTap: () {
                            setState(() =>
                                _sortMode = _SortMode.perishable);
                            widget.onSortChanged(
                                _SortMode.perishable);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Botão aplicar com gradiente ───────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF1D5FA8),
                            Color(0xFF2563EB),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB)
                                .withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.of(context).pop(),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  count > 0
                                      ? 'Aplicar $count filtro${count > 1 ? 's' : ''}'
                                      : 'Ver todos os produtos',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

// ─── Widgets auxiliares do modal de filtro ────────────────────────────────

class _FilterSectionLabel extends StatelessWidget {
  final String label;
  const _FilterSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 3, height: 13,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w800,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TypeToggleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool selected;
  final Color color;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _TypeToggleCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.color,
    required this.isDark,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? 0.14 : 0.08)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.50)
                : cs.outlineVariant.withValues(alpha: 0.30),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.18)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon,
                      size: 17,
                      color: selected ? color : cs.onSurfaceVariant),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: selected ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? color
                          : cs.outlineVariant.withValues(alpha: 0.40),
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 11, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? color : cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 10.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _CategoryFilterChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.secondaryBlue600;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: isDark ? 0.16 : 0.09)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.50)
                : cs.outlineVariant.withValues(alpha: 0.30),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color:
                    selected ? color : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: selected ? color : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortOptionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _SortOptionItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.brandPrimary600;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(14) : Radius.zero,
        bottom: isLast ? const Radius.circular(14) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.12)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon,
                  size: 17,
                  color: selected ? color : cs.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: selected ? color : cs.onSurface,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? color
                      : cs.outlineVariant.withValues(alpha: 0.40),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card do grid (3 por linha) ───────────────────────────────────────────

class _ProductGridCard extends ConsumerWidget {
  final Product product;
  final String catLabel;
  final int index;
  final bool inactive;
  final VoidCallback onTap;

  const _ProductGridCard({
    required this.product,
    required this.catLabel,
    required this.index,
    required this.onTap,
    this.inactive = false,
  });

  static const _paletteRed    = [Color(0xFFDC2626), Color(0xFFB91C1C)];
  static const _paletteYellow = [Color(0xFFD97706), Color(0xFFB45309)];
  static const _paletteGreen  = [Color(0xFF059669), Color(0xFF047857)];
  static const _paletteBlue   = [Color(0xFF2563EB), Color(0xFF1D4ED8)];
  static const _paletteGray   = [Color(0xFF6B7280), Color(0xFF4B5563)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFmt = DateFormat('dd/MM');

    final batches = ref
        .watch(batchesByProductProvider(product.id))
        .whenOrNull(data: (b) => b) ?? const [];

    final totalQty = batches.fold<int>(0, (s, b) => s + b.quantity);

    final nearestBatch = batches.where((b) => !b.noExpiry).toList()
      ..sort((a, b) => a.daysToExpiry.compareTo(b.daysToExpiry));
    final batchData = nearestBatch.firstOrNull;

    // Status de validade
    Color expiryColor;
    IconData expiryIcon;
    String? expiryBadge; // rótulo curto para o badge do header
    List<Color> palette;

    if (!product.isPerishable || batchData == null) {
      expiryColor = const Color(0xFF60A5FA);
      expiryIcon  = Icons.all_inclusive_rounded;
      expiryBadge = null;
      palette     = _paletteBlue;
    } else if (batchData.isExpired) {
      expiryColor = const Color(0xFFF87171);
      expiryIcon  = Icons.cancel_rounded;
      expiryBadge = 'VENCIDO';
      palette     = _paletteRed;
    } else if (batchData.daysToExpiry <= 7) {
      expiryColor = const Color(0xFFFCA5A5);
      expiryIcon  = Icons.warning_amber_rounded;
      expiryBadge = batchData.expiryDate != null
          ? '${dateFmt.format(batchData.expiryDate!)}·${batchData.daysToExpiry}d'
          : 'CRÍTICO';
      palette = _paletteRed;
    } else if (batchData.daysToExpiry <= 30) {
      expiryColor = const Color(0xFFFDE68A);
      expiryIcon  = Icons.schedule_rounded;
      expiryBadge = batchData.expiryDate != null
          ? '${dateFmt.format(batchData.expiryDate!)}·${batchData.daysToExpiry}d'
          : 'ATENÇÃO';
      palette = _paletteYellow;
    } else {
      expiryColor = const Color(0xFF6EE7B7);
      expiryIcon  = Icons.check_circle_rounded;
      expiryBadge = null; // seguro: não polui o header
      palette     = _paletteGreen;
    }

    // Produto sem estoque (inativo) sobrescreve toda a coloração com cinza
    // e exibe badge "INATIVO".
    if (inactive) {
      palette = _paletteGray;
      expiryColor = const Color(0xFF9CA3AF);
      expiryIcon = Icons.do_not_disturb_on_outlined;
      expiryBadge = 'INATIVO';
    }

    final accent      = palette[0];
    final accentDark  = palette[1];
    final cardBg      = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderColor = accent.withValues(alpha: isDark ? 0.35 : 0.20);

    final entryFade = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 180 + index * 8),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v * (inactive ? 0.62 : 1),
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.20 : 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header compacto com gradiente e ícone de categoria ───
              Stack(
                children: [
                  Container(
                    height: 62,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accentDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(13)),
                    ),
                    child: Stack(
                      children: [
                        // Círculo decorativo
                        Positioned(
                          right: -10, top: -10,
                          child: Container(
                            width: 44, height: 44,
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
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(13)),
                                  child: Image.network(
                                    product.imageUrl!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 62,
                                  ),
                                )
                              : Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.30),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Icon(
                                    _categoryIcon(product.category),
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Badge de validade (topo-direito do header)
                  if (expiryBadge != null)
                    Positioned(
                      top: 5, right: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.52),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: expiryColor.withValues(alpha: 0.60),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(expiryIcon, size: 7, color: expiryColor),
                            const SizedBox(width: 2),
                            Text(
                              expiryBadge.split('·').first.trim(),
                              style: TextStyle(
                                fontSize: 7.5,
                                color: expiryColor,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Badge "∞" para não perecível
                  if (!product.isPerishable)
                    Positioned(
                      top: 5, right: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          '∞',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // ─── Corpo compacto ───────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(7, 7, 7, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome do produto
                      Text(
                        product.name,
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                          height: 1.20,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const Spacer(),

                      // Linha: quantidade + categoria
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Qty pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(
                                  alpha: isDark ? 0.22 : 0.11),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.layers_rounded,
                                    size: 9, color: accent),
                                const SizedBox(width: 2),
                                Text(
                                  '$totalQty',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 1),
                                Text(
                                  product.unit,
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: accent.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Categoria
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                    alpha: isDark ? 0.12 : 0.07),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: accent.withValues(
                                      alpha: isDark ? 0.20 : 0.14),
                                  width: 0.7,
                                ),
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
                          ),
                        ],
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

    // Quando inativo, aplica dessaturação grayscale por cima do card todo.
    if (!inactive) return entryFade;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]),
      child: entryFade,
    );
  }
}