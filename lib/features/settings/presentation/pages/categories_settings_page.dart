import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../controllers/system_settings_provider.dart';

class CategoriesSettingsPage extends ConsumerWidget {
  const CategoriesSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(categorySettingsNotifierProvider);
    final user = ref.watch(currentUserProvider);
    final categories = ref.watch(categorySettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ModernProfileAppBar(
        title: 'Categorias',
        subtitle: 'Controle de categorias de produtos',
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        showBackButton: true,
      ),
      body: SafeArea(
        child: categories.when(
          data: (items) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final item = items[i];
              return Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.category_outlined,
                        color: AppColors.brandPrimary600),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        item.label,
                        style: AppTypography.labelLarge,
                      ),
                    ),
                    Switch(
                      value: item.isActive,
                      onChanged: (v) async {
                        await ref
                            .read(categorySettingsNotifierProvider.notifier)
                            .setCategoryActive(key: item.key, isActive: v);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
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
    );
  }
}
