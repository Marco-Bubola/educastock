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
  final _keyNameField = GlobalKey();
  final _keyIngredientsSection = GlobalKey();

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

    final bg = isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFF9FAFB) : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final pillBg = isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9);

    final selectedCount = _selectedQty.values.where((v) => v > 0).length;
    final totalQty = _selectedQty.values.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: bg,
      appBar: ModernProfileAppBar(
        title: 'Nova Receita',
        subtitle: 'Monte um modelo de distribuição',
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyNameField,
                  title: 'Nome da Receita',
                  description: 'Informe um nome descritivo para a receita, como "Almoço Infantil Padrão" ou "Kit Higiene Básico". O nome ajuda a identificar rapidamente qual modelo usar na distribuição.',
                  icon: Icons.restaurant_menu_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Use nomes que a equipe reconhece facilmente',
                    'Inclua a quantidade de porções no nome quando relevante',
                    'Ex: "Lanche Escolar 30 crianças"',
                  ],
                ),
                TutorialStep(
                  key: _keyIngredientsSection,
                  title: 'Ingredientes da Receita',
                  description: 'Adicione cada produto e sua quantidade necessária para uma execução da receita. Ao executar a receita, todas as quantidades serão deduzidas automaticamente do estoque.',
                  icon: Icons.list_alt_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Adicione todos os ingredientes antes de salvar',
                    'A quantidade é por execução da receita',
                    'O sistema verifica estoque disponível antes de cada execução',
                    'Produtos sem estoque suficiente bloqueiam a execução',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: productsAsync.when(
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

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // ─── Info card ────────────────────────────────────────
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: isDark ? 0.3 : 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(Icons.menu_book_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Monte sua receita',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                                  Text(
                                    'Defina nome e selecione produtos',
                                    style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.75),
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Text('$selectedCount',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18)),
                                    Text('itens',
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                            fontSize: 10)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ─── Nome + Descrição ─────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INFORMAÇÕES DA RECEITA',
                                style: TextStyle(
                                    color: textSub,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8)),
                            const SizedBox(height: 10),
                            Container(
                              key: _keyNameField,
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor),
                              ),
                              child: TextField(
                                controller: _nameCtrl,
                                style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: 'Nome da receita (ex: Kit Lanche)',
                                  hintStyle:
                                      TextStyle(color: textSub, fontSize: 14),
                                  prefixIcon: Icon(Icons.label_rounded,
                                      color: const Color(0xFF7C3AED), size: 20),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor),
                              ),
                              child: TextField(
                                controller: _descCtrl,
                                maxLines: 2,
                                style:
                                    TextStyle(color: textPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Descrição (opcional)',
                                  hintStyle:
                                      TextStyle(color: textSub, fontSize: 14),
                                  prefixIcon: Padding(
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: Icon(Icons.notes_rounded,
                                        color: textSub, size: 20),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── Busca de produtos ────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('PRODUTOS',
                                style: TextStyle(
                                    color: textSub,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8)),
                            const SizedBox(height: 10),
                            Container(
                              key: _keyIngredientsSection,
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor),
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (v) =>
                                    setState(() => _search = v),
                                style:
                                    TextStyle(color: textPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Buscar produto por nome ou marca…',
                                  hintStyle:
                                      TextStyle(color: textSub, fontSize: 14),
                                  prefixIcon: Icon(Icons.search_rounded,
                                      color: textSub, size: 20),
                                  suffixIcon: _search.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(Icons.close_rounded,
                                              color: textSub, size: 18),
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            setState(() => _search = '');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 13),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Category filter chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _CatChip(
                                    label: 'Todos',
                                    selected: _categoryFilter == null,
                                    isDark: isDark,
                                    pillBg: pillBg,
                                    borderColor: borderColor,
                                    onTap: () => setState(
                                        () => _categoryFilter = null),
                                  ),
                                  const SizedBox(width: 8),
                                  ...categories.map((key) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: _CatChip(
                                          label: labelMap[key] ?? key,
                                          selected: _categoryFilter == key,
                                          isDark: isDark,
                                          pillBg: pillBg,
                                          borderColor: borderColor,
                                          onTap: () => setState(
                                              () => _categoryFilter = key),
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── Grid de produtos ─────────────────────────────────
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      sliver: filtered.isEmpty
                          ? SliverToBoxAdapter(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.search_off_rounded,
                                          size: 48, color: textSub),
                                      const SizedBox(height: 10),
                                      Text('Nenhum produto encontrado',
                                          style: TextStyle(
                                              color: textSub, fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.72,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final p = filtered[i];
                                  final qty = _selectedQty[p.id] ?? 0;
                                  final selected = qty > 0;

                                  return _ProductCard(
                                    product: p,
                                    qty: qty,
                                    selected: selected,
                                    isDark: isDark,
                                    cardBg: cardBg,
                                    borderColor: borderColor,
                                    textPrimary: textPrimary,
                                    textSub: textSub,
                                    onDecrement: qty > 0
                                        ? () => setState(() {
                                              final next = qty - 1;
                                              if (next <= 0) {
                                                _selectedQty.remove(p.id);
                                              } else {
                                                _selectedQty[p.id] = next;
                                              }
                                            })
                                        : null,
                                    onIncrement: () => setState(
                                        () => _selectedQty[p.id] = qty + 1),
                                  );
                                },
                                childCount: filtered.length,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              // ─── Bottom save bar ──────────────────────────────────────
              Container(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(top: BorderSide(color: borderColor)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (selectedCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF7C3AED)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$totalQty',
                                style: const TextStyle(
                                    color: Color(0xFF7C3AED),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18)),
                            Text('unid.',
                                style: TextStyle(
                                    color: const Color(0xFF7C3AED)
                                        .withValues(alpha: 0.75),
                                    fontSize: 10)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed:
                              _saving ? null : () => _save(products),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            _saving ? 'Salvando…' : 'Salvar receita',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Erro: $e',
                style: const TextStyle(color: Color(0xFFDC2626)))),
      ),
    );
  }
}

// ─── Category filter chip ──────────────────────────────────────────────────

class _CatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final Color pillBg;
  final Color borderColor;
  final VoidCallback onTap;

  const _CatChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.pillBg,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7C3AED) : pillBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? const Color(0xFF7C3AED) : borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : (isDark
                    ? const Color(0xFFD1D5DB)
                    : const Color(0xFF374151)),
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ─── Product card ──────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final int qty;
  final bool selected;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textSub;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  const _ProductCard({
    required this.product,
    required this.qty,
    required this.selected,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textSub,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF7C3AED);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? (isDark
                ? const Color(0xFF1A1033)
                : const Color(0xFFF5F3FF))
            : cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? accentColor : borderColor,
          width: selected ? 2 : 1,
        ),
        boxShadow: selected && !isDark
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          // Image / icon area
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: product.imageUrl != null &&
                      product.imageUrl!.isNotEmpty
                  ? Image.network(
                      product.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _PlaceholderIcon(isDark: isDark),
                    )
                  : _PlaceholderIcon(isDark: isDark),
            ),
          ),
          // Info + controls
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: Column(
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                // Qty controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _QtyBtn(
                      icon: Icons.remove_rounded,
                      onTap: onDecrement,
                      isDark: isDark,
                      active: qty > 0,
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '$qty',
                          style: TextStyle(
                            color: selected ? accentColor : textSub,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    _QtyBtn(
                      icon: Icons.add_rounded,
                      onTap: onIncrement,
                      isDark: isDark,
                      active: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  final bool isDark;
  const _PlaceholderIcon({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark
          ? const Color(0xFF1F2937)
          : const Color(0xFFEDE9FE),
      child: const Center(
        child: Icon(Icons.inventory_2_outlined,
            size: 28, color: Color(0xFF7C3AED)),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;
  final bool active;

  const _QtyBtn({
    required this.icon,
    required this.onTap,
    required this.isDark,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: active && onTap != null
              ? const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.25 : 0.1)
              : (isDark
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 14,
          color: active && onTap != null
              ? const Color(0xFF7C3AED)
              : (isDark
                  ? const Color(0xFF4B5563)
                  : const Color(0xFFD1D5DB)),
        ),
      ),
    );
  }
}
