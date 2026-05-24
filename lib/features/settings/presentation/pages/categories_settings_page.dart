import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../controllers/system_settings_provider.dart';

final _keyCategorySummary = GlobalKey();
final _keyCategoryList = GlobalKey();

class CategoriesSettingsPage extends ConsumerWidget {
  const CategoriesSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    ref.watch(categorySettingsNotifierProvider);
    final user = ref.watch(currentUserProvider);
    final categories = ref.watch(categorySettingsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Categorias',
        subtitle: 'Controle de categorias de produtos',
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyCategorySummary,
                  title: 'Resumo por Categoria',
                  description: 'Visão geral das categorias existentes com total de produtos em cada uma. Use para entender a composição do estoque e identificar categorias com baixo volume.',
                  icon: Icons.donut_small_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'O número mostra total de produtos (não lotes)',
                    'Toque para filtrar o estoque por categoria',
                    'Crie categorias específicas para sua realidade',
                  ],
                ),
                TutorialStep(
                  key: _keyCategoryList,
                  title: 'Lista de Categorias',
                  description: 'Gerencie as categorias de produtos disponíveis no sistema. Adicione, edite ou remova categorias conforme a necessidade da sua instituição.',
                  icon: Icons.category_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Categorias são compartilhadas com todos os usuários',
                    'Evite muitas categorias — mantenha organizado',
                    'Categorias padrão: Alimento, Higiene, Material Escolar',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: categories.when(
          data: (items) {
            final active = items.where((i) => i.isActive).length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              children: [
                // ─── Resumo
                Container(
                  key: _keyCategorySummary,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.brandPrimary600,
                        AppColors.secondaryBlue600
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.brandPrimary600.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: const Icon(Icons.category_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$active de ${items.length} ativas',
                            style: AppTypography.headingSmall
                                .copyWith(color: Colors.white),
                          ),
                          Text(
                            'Categorias disponíveis no cadastro',
                            style: AppTypography.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ─── Lista
                ...items.asMap().entries.map((entry) {
                  final item = entry.value;
                  final idx = entry.key;
                  return Padding(
                    key: idx == 0 ? _keyCategoryList : null,
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border(
                          left: BorderSide(
                            color: item.isActive
                                ? AppColors.brandPrimary600
                                : cs.outlineVariant,
                            width: 3,
                          ),
                          top: BorderSide(
                              color: cs.outlineVariant
                                  .withValues(alpha: 0.35)),
                          right: BorderSide(
                              color: cs.outlineVariant
                                  .withValues(alpha: 0.35)),
                          bottom: BorderSide(
                              color: cs.outlineVariant
                                  .withValues(alpha: 0.35)),
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: item.isActive
                                  ? AppColors.brandPrimary600
                                      .withValues(alpha: 0.1)
                                  : cs.surfaceContainer,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.small),
                            ),
                            child: Icon(
                              Icons.category_outlined,
                              color: item.isActive
                                  ? AppColors.brandPrimary600
                                  : cs.onSurfaceVariant,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: AppTypography.labelLarge.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  item.isActive ? 'Visível no cadastro' : 'Oculta',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: item.isActive
                                        ? AppColors.success600
                                        : cs.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: item.isActive,
                            onChanged: (v) async {
                              await ref
                                  .read(categorySettingsNotifierProvider
                                      .notifier)
                                  .setCategoryActive(
                                      key: item.key, isActive: v);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
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
            title: 'Erro ao carregar categorias',
            description: e.toString(),
          ),
        ),
      ),
      ]),
    );
  }
}


