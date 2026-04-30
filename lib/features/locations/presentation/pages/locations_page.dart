import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../controllers/locations_provider.dart';

class LocationsPage extends ConsumerWidget {
  const LocationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final locations = ref.watch(activeLocationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ModernProfileAppBar(
        title: 'Secoes e prateleiras',
        subtitle: 'Estruture as localizacoes do estoque',
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        showBackButton: true,
      ),
      body: SafeArea(
        child: locations.when(
          data: (items) {
            if (items.isEmpty) {
              return CasaEmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'Nenhuma localizacao cadastrada',
                description:
                    'Cadastre secoes e prateleiras para padronizar o armazenamento.',
                ctaLabel: 'Cadastrar localizacao',
                onCta: () => _showLocationForm(context, ref),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final loc = items[i];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary100,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: AppColors.brandPrimary600,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.label,
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.neutral900,
                              ),
                            ),
                            Text(
                              'Seção ${loc.section} • Prateleira ${loc.shelf}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.neutral500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final confirm = await CasaDialogConfirmacao.show(
                            context: context,
                            title: 'Desativar localizacao',
                            message:
                                'Essa localizacao nao sera mais exibida para novos lotes. Deseja continuar?',
                            confirmLabel: 'Desativar',
                            isDanger: true,
                          );
                          if (confirm != true) return;
                          await ref
                              .read(locationsNotifierProvider.notifier)
                              .deactivateLocation(loc.id);
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger600,
                        ),
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
            title: 'Erro ao carregar localizacoes',
            description: e.toString(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLocationForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova localizacao'),
      ),
    );
  }

  void _showLocationForm(BuildContext context, WidgetRef ref) {
    final sectionCtrl = TextEditingController();
    final shelfCtrl = TextEditingController();
    final levelCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nova localizacao', style: AppTypography.headingLarge),
                const SizedBox(height: AppSpacing.md),
                CasaTextField(
                  label: 'Seção *',
                  hint: 'Ex: A, B, C',
                  controller: sectionCtrl,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Informe a seção' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                CasaTextField(
                  label: 'Prateleira *',
                  hint: 'Ex: 1, 2, 3',
                  controller: shelfCtrl,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Informe a prateleira'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                CasaTextField(
                  label: 'Nível (opcional)',
                  hint: 'Ex: 1 ou superior',
                  controller: levelCtrl,
                ),
                const SizedBox(height: AppSpacing.md),
                CasaTextField(
                  label: 'Sala/Depósito (opcional)',
                  hint: 'Ex: Depósito A',
                  controller: roomCtrl,
                ),
                const SizedBox(height: AppSpacing.xl),
                CasaButton(
                  label: 'Salvar localizacao',
                  icon: Icons.save_rounded,
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    await ref.read(locationsNotifierProvider.notifier).createLocation(
                          section: sectionCtrl.text,
                          shelf: shelfCtrl.text,
                          level: levelCtrl.text,
                          room: roomCtrl.text,
                        );

                    final state = ref.read(locationsNotifierProvider);
                    if (!context.mounted) return;
                    state.when(
                      data: (_) {
                        Navigator.pop(context);
                        showCasaSnackbar(
                          context,
                          message: 'Localizacao cadastrada com sucesso.',
                          isSuccess: true,
                        );
                      },
                      error: (e, _) => showCasaSnackbar(
                        context,
                        message: e.toString().replaceFirst('Exception: ', ''),
                        isError: true,
                      ),
                      loading: () {},
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
