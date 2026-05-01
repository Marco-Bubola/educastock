import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../products/presentation/controllers/products_provider.dart';
import '../../domain/entities/stock_recipe.dart';
import '../controllers/recipes_provider.dart';

class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recipesNotifierProvider.notifier).ensureSeed();
    });
  }

  Future<void> _openCreateRecipeSheet() async {
    final products = ref.read(productsProvider).valueOrNull ?? const [];
    if (products.isEmpty) {
      showCasaSnackbar(
        context,
        message: 'Cadastre produtos antes de criar receitas.',
        isError: true,
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final items = <_DraftItem>[const _DraftItem()];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nova Receita', style: AppTypography.headingMedium),
                    const SizedBox(height: AppSpacing.md),
                    CasaTextField(
                      label: 'Nome da receita *',
                      controller: nameCtrl,
                      hint: 'Ex: Kit Lanche Infantil',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    CasaTextField(
                      label: 'Descrição',
                      controller: descCtrl,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Itens da receita', style: AppTypography.labelLarge),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < items.length; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: items[i].productId,
                              decoration: const InputDecoration(
                                labelText: 'Produto',
                              ),
                              items: products
                                  .map((p) => DropdownMenuItem(
                                        value: p.id,
                                        child: Text(p.name),
                                      ))
                                  .toList(),
                              onChanged: (v) => setSheetState(() {
                                items[i] = items[i].copyWith(productId: v);
                              }),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            width: 110,
                            child: CasaTextField(
                              label: 'Qtd',
                              keyboardType: TextInputType.number,
                              controller: TextEditingController(
                                text: items[i].quantity.toString(),
                              ),
                              onChanged: (v) => setSheetState(() {
                                items[i] = items[i].copyWith(
                                  quantity: int.tryParse(v) ?? 1,
                                );
                              }),
                            ),
                          ),
                          IconButton(
                            onPressed: items.length > 1
                                ? () => setSheetState(() => items.removeAt(i))
                                : null,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    TextButton.icon(
                      onPressed: () => setSheetState(() {
                        items.add(const _DraftItem());
                      }),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar item'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CasaButton(
                      label: 'Salvar Receita',
                      icon: Icons.save_rounded,
                      onPressed: () async {
                        final cleanName = nameCtrl.text.trim();
                        if (cleanName.isEmpty) {
                          showCasaSnackbar(
                            context,
                            message: 'Informe o nome da receita.',
                            isError: true,
                          );
                          return;
                        }

                        final recipeItems = <RecipeItem>[];
                        for (final item in items) {
                          final productId = item.productId;
                          final qty = item.quantity;
                          if (productId == null || productId.isEmpty || qty <= 0) {
                            continue;
                          }
                          final product = products.firstWhere((p) => p.id == productId);
                          recipeItems.add(
                            RecipeItem(
                              productId: product.id,
                              productName: product.name,
                              quantity: qty,
                            ),
                          );
                        }

                        if (recipeItems.isEmpty) {
                          showCasaSnackbar(
                            context,
                            message: 'Adicione pelo menos 1 item válido.',
                            isError: true,
                          );
                          return;
                        }

                        final user = ref.read(currentUserProvider);
                        if (user == null) return;

                        await ref.read(recipesNotifierProvider.notifier).saveRecipe(
                              StockRecipe(
                                id: '',
                                name: cleanName,
                                description: descCtrl.text.trim().isEmpty
                                    ? null
                                    : descCtrl.text.trim(),
                                items: recipeItems,
                                createdAt: DateTime.now(),
                                createdBy: user.id,
                              ),
                            );

                        if (!mounted) return;
                        Navigator.pop(ctx);
                        showCasaSnackbar(
                          context,
                          message: 'Receita salva com sucesso!',
                          isSuccess: true,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    descCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
    final actionState = ref.watch(recipesNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const ModernProfileAppBar(
        title: 'Receitas de Saída',
        subtitle: 'Consumo automático por receita',
        showBackButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateRecipeSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova receita'),
      ),
      body: SafeArea(
        child: recipesAsync.when(
          data: (recipes) {
            if (recipes.isEmpty) {
              return CasaEmptyState(
                icon: Icons.menu_book_outlined,
                title: 'Nenhuma receita cadastrada',
                description: 'Crie receitas para registrar saídas em lote.',
                ctaLabel: 'Criar receita',
                onCta: _openCreateRecipeSheet,
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: recipes.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final r = recipes[i];
                final totalQty = r.items.fold<int>(0, (sum, item) => sum + item.quantity);
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                      color: r.isPredefined
                          ? AppColors.brandPrimary100
                          : AppColors.neutral100,
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
                              style: AppTypography.headingSmall
                                  .copyWith(color: AppColors.neutral900),
                            ),
                          ),
                          if (r.isPredefined)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.brandPrimary100,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                'Pré-criada',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.brandPrimary700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if ((r.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          r.description!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.neutral500),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${r.items.length} itens • Quantidade total: $totalQty',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.neutral700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...r.items.take(3).map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '• ${item.productName} (${item.quantity})',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.neutral500,
                                ),
                              ),
                            ),
                          ),
                      if (r.items.length > 3)
                        Text(
                          '+ ${r.items.length - 3} itens',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.neutral500,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: CasaButton(
                              label: 'Executar receita',
                              icon: Icons.play_arrow_rounded,
                              isLoading: actionState.isLoading,
                              onPressed: actionState.isLoading
                                  ? null
                                  : () async {
                                      try {
                                        await ref
                                            .read(recipesNotifierProvider.notifier)
                                            .executeRecipe(r);
                                        if (!context.mounted) return;
                                        showCasaSnackbar(
                                          context,
                                          message: 'Saída por receita registrada com sucesso!',
                                          isSuccess: true,
                                        );
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        showCasaSnackbar(
                                          context,
                                          message: e.toString().replaceFirst('Exception: ', ''),
                                          isError: true,
                                        );
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton(
                            onPressed: actionState.isLoading
                                ? null
                                : () async {
                                    await ref
                                        .read(recipesNotifierProvider.notifier)
                                        .deactivateRecipe(r.id);
                                  },
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: 'Desativar receita',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const CasaCardSkeleton(),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar receitas',
            description: e.toString(),
          ),
        ),
      ),
    );
  }
}

class _DraftItem {
  final String? productId;
  final int quantity;

  const _DraftItem({this.productId, this.quantity = 1});

  _DraftItem copyWith({String? productId, int? quantity}) {
    return _DraftItem(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
    );
  }
}
