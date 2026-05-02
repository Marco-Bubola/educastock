import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/controllers/products_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../../domain/entities/stock_recipe.dart';
import '../controllers/recipes_provider.dart';

class RecipeCreatePage extends ConsumerStatefulWidget {
  const RecipeCreatePage({super.key});

  @override
  ConsumerState<RecipeCreatePage> createState() => _RecipeCreatePageState();
}

class _RecipeCreatePageState extends ConsumerState<RecipeCreatePage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final Map<String, int> _selectedQty = {};
  String _search = '';
  String? _categoryFilter;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(List<Product> products) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showCasaSnackbar(context, message: 'Informe o nome da receita.', isError: true);
      return;
    }

    final items = <RecipeItem>[];
    for (final e in _selectedQty.entries) {
      if (e.value <= 0) continue;
      final p = products.firstWhere((x) => x.id == e.key);
      items.add(RecipeItem(productId: p.id, productName: p.name, quantity: e.value));
    }

    if (items.isEmpty) {
      showCasaSnackbar(context, message: 'Selecione produtos com quantidade.', isError: true);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _saving = true);
    await ref.read(recipesNotifierProvider.notifier).saveRecipe(
          StockRecipe(
            id: '',
            name: name,
            description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            items: items,
            createdAt: DateTime.now(),
            createdBy: user.id,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    showCasaSnackbar(context, message: 'Receita criada com sucesso!', isSuccess: true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final labelMap = ref.watch(categoryLabelMapProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).colorScheme.surface : AppColors.background,
      appBar: const ModernProfileAppBar(
        title: 'Nova Receita',
        subtitle: 'Monte com produtos em cards',
        showBackButton: true,
      ),
      body: SafeArea(
        child: productsAsync.when(
          data: (products) {
            final categories = products.map((p) => p.category.name).toSet().toList()..sort();
            final filtered = products.where((p) {
              final q = _search.trim().toLowerCase();
              final searchOk = q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  (p.brand?.toLowerCase().contains(q) ?? false);
              final categoryOk = _categoryFilter == null || p.category.name == _categoryFilter;
              return searchOk && categoryOk;
            }).toList();

            final width = MediaQuery.of(context).size.width;
            final cross = width >= 1000
                ? 4
              : width >= 760
                ? 3
                    : width >= 560
                        ? 3
                        : 2;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                CasaTextField(
                  label: 'Nome da receita *',
                  controller: _nameCtrl,
                  hint: 'Ex: Kit Lanche',
                ),
                const SizedBox(height: AppSpacing.sm),
                CasaTextField(
                  label: 'Descrição',
                  controller: _descCtrl,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.md),
                CasaTextField(
                  label: 'Buscar produtos',
                  controller: _searchCtrl,
                  hint: 'Nome ou marca',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: const Text('Todas categorias'),
                      selected: _categoryFilter == null,
                      onSelected: (_) => setState(() => _categoryFilter = null),
                    ),
                    ...categories.map(
                      (key) => ChoiceChip(
                        label: Text(labelMap[key] ?? key),
                        selected: _categoryFilter == key,
                        onSelected: (_) => setState(() => _categoryFilter = key),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Selecione produtos e quantidades',
                  style: AppTypography.labelLarge.copyWith(color: onSurface),
                ),
                const SizedBox(height: AppSpacing.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.8,
                  ),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final qty = _selectedQty[p.id] ?? 0;

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                            : AppColors.surface,
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
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelSmall.copyWith(
                              color: onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
                                onPressed: qty > 0
                                    ? () => setState(() {
                                          final next = qty - 1;
                                          if (next <= 0) {
                                            _selectedQty.remove(p.id);
                                          } else {
                                            _selectedQty[p.id] = next;
                                          }
                                        })
                                    : null,
                              ),
                              Expanded(
                                child: Text(
                                  '$qty',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.labelMedium.copyWith(color: onSurfaceVariant),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                                onPressed: () => setState(() {
                                  _selectedQty[p.id] = qty + 1;
                                }),
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
                  label: 'Salvar receita',
                  icon: Icons.save_rounded,
                  isLoading: _saving,
                  onPressed: _saving ? null : () => _save(products),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
        ),
      ),
    );
  }
}
