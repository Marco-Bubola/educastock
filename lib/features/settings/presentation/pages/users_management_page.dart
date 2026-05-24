import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../controllers/system_settings_provider.dart';

final _keyUserCard = GlobalKey();

class UsersManagementPage extends ConsumerWidget {
  const UsersManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final usersState = ref.watch(usersManagementProvider);

    if (currentUser == null || !currentUser.canManageUsers) {
      return Scaffold(
        body: Column(children: [
        ModernProfileAppBar(
          title: 'Gerenciar usuárias',
          subtitle: 'Acesso restrito',
          showBackButton: true,
          actions: [
            buildHelpButton(
              context: context,
              onPressed: () => showCasaTutorial(
                context: context,
                steps: [
                  TutorialStep(
                    key: _keyUserCard,
                    title: 'Cartão de Usuário',
                    description: 'Cada cartão representa um usuário cadastrado no sistema. Veja nome, e-mail, função (admin ou colaborador) e status de atividade de cada membro da equipe.',
                    icon: Icons.badge_rounded,
                    align: ContentAlign.bottom,
                    hints: const [
                      '🟢 Ativo: usuário com acesso habilitado',
                      '⚫ Inativo: acesso desabilitado temporariamente',
                      'Toque no cartão para editar permissões ou desativar',
                      'Admins têm acesso completo — cuidado ao promover',
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const Expanded(child: Center(
          child: Text('Acesso restrito a administradoras.'),
        )),
        ]),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Gerenciar usuarias',
        subtitle: 'Controle de perfis e acessos',
        profileName: currentUser.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyUserCard,
                  title: 'Cartão de Usuário',
                  description: 'Cada cartão representa um usuário cadastrado no sistema. Veja nome, e-mail, função (admin ou colaborador) e status de atividade de cada membro da equipe.',
                  icon: Icons.badge_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🟢 Ativo: usuário com acesso habilitado',
                    '⚫ Inativo: acesso desabilitado temporariamente',
                    'Toque no cartão para editar permissões ou desativar',
                    'Admins têm acesso completo — cuidado ao promover',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: usersState.when(
          data: (users) => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: users.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) {
              final user = users[i];
              final cs = Theme.of(context).colorScheme;
              final card = Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: user.isActive
                              ? AppColors.brandPrimary600.withValues(alpha: 0.15)
                              : cs.surfaceContainer,
                          child: Text(
                            user.name.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: user.isActive
                                  ? AppColors.brandPrimary600
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name,
                                  style: AppTypography.labelLarge.copyWith(
                                      color: cs.onSurface)),
                              Text(user.email,
                                  style: AppTypography.bodySmall.copyWith(
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: user.isActive
                                ? AppColors.success600.withValues(alpha: 0.12)
                                : AppColors.danger600.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            user.isActive ? 'Ativa' : 'Inativa',
                            style: AppTypography.labelSmall.copyWith(
                              color: user.isActive
                                  ? AppColors.success600
                                  : AppColors.danger600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<UserRole>(
                      initialValue: user.role,
                      decoration: const InputDecoration(
                        labelText: 'Perfil de acesso',
                        prefixIcon: Icon(Icons.verified_user_outlined, size: 20),
                      ),
                      items: UserRole.values
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(_roleLabel(r)),
                            ),
                          )
                          .toList(),
                      onChanged: (newRole) async {
                        if (newRole == null) return;
                        await ref
                            .read(userManagementNotifierProvider.notifier)
                            .updateRole(userId: user.id, role: newRole);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Permitir login desta usuaria',
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                        Switch(
                          value: user.isActive,
                          onChanged: (v) async {
                            await ref
                                .read(userManagementNotifierProvider.notifier)
                                .setActive(userId: user.id, isActive: v);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
              if (i == 0) {
                return KeyedSubtree(key: _keyUserCard, child: card);
              }
              return card;
            },
          ),
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const CasaCardSkeleton(),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar usuarias',
            description: e.toString(),
          ),
        ),
      ),
      ]),
    );
  }

  static String _roleLabel(UserRole role) => switch (role) {
        UserRole.admin => 'Administrador',
        UserRole.estoquista => 'Estoquista',
        UserRole.voluntario => 'Voluntario autorizado',
        UserRole.consulta => 'Consulta',
      };
}
