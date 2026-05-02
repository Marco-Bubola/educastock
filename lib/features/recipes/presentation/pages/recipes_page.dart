import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../controllers/recipes_provider.dart';

class RecipesPage extends ConsumerStatefulWidget {
  const RecipesPage({super.key});

  @override
  ConsumerState<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends ConsumerState<RecipesPage> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recipesNotifierProvider.notifier).ensureSeed();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateRecipeSheet() {
    context.push(AppRoutes.recipeCreate);
  }

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipesProvider);
    final actionState = ref.watch(recipesNotifierProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: const ModernProfileAppBar(
        title: 'Receitas de Saída',
        subtitle: 'Modelos ativos para baixa rápida',
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
            final filtered = recipes.where((r) {
              final q = _search.trim().toLowerCase();
              if (q.isEmpty) return true;
              return r.name.toLowerCase().contains(q) ||
                  (r.description?.toLowerCase().contains(q) ?? false);
            }).toList();

            if (filtered.isEmpty) {
              return CasaEmptyState(
                icon: Icons.menu_book_outlined,
                title: 'Nenhuma receita encontrada',
                description: 'Crie ou pesquise receitas para execução rápida.',
                ctaLabel: 'Criar receita',
                onCta: _openCreateRecipeSheet,
              );
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                CasaTextField(
                  label: 'Buscar receita',
                  controller: _searchController,
                  hint: 'Nome ou descrição',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
                ),
                const SizedBox(height: AppSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cross = constraints.maxWidth >= 980
                        ? 4
                        : constraints.maxWidth >= 700
                            ? 3
                            : 2;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cross,
                        mainAxisSpacing: AppSpacing.sm,
                        crossAxisSpacing: AppSpacing.sm,
                        childAspectRatio: 1.05,
                      ),
                      itemBuilder: (_, i) {
                        final r = filtered[i];
                        final totalQty = r.items.fold<int>(0, (acc, item) => acc + item.quantity);
                        return Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color: r.isPredefined
                                  ? AppColors.brandPrimary100
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
                                  if (r.isPredefined)
                                    const Icon(Icons.bolt_rounded, size: 16, color: AppColors.brandPrimary600),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${r.items.length} itens • qtd total $totalQty',
                                style: AppTypography.bodySmall.copyWith(color: onSurfaceVariant),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(
                                  r.description ?? 'Sem descrição',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall.copyWith(color: onSurfaceVariant),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: CasaButton(
                                      label: 'Executar',
                                      icon: Icons.play_arrow_rounded,
                                      isLoading: actionState.isLoading,
                                      onPressed: actionState.isLoading
                                          ? null
                                          : () async {
                                              try {
                                                await ref.read(recipesNotifierProvider.notifier).executeRecipe(r);
                                                if (!context.mounted) return;
                                                showCasaSnackbar(
                                                  context,
                                                  message: 'Receita executada com sucesso!',
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
                                  const SizedBox(width: AppSpacing.xs),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    tooltip: 'Desativar receita',
                                    onPressed: actionState.isLoading
                                        ? null
                                        : () async {
                                            await ref
                                                .read(recipesNotifierProvider.notifier)
                                                .deactivateRecipe(r.id);
                                          },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
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
