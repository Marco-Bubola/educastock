import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Configurações')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Perfil do usuário
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary600,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.surface.withValues(alpha: 0.2),
                    radius: 28,
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'U',
                      style: AppTypography.headingMedium
                          .copyWith(color: AppColors.surface),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Usuário',
                          style: AppTypography.headingSmall
                              .copyWith(color: AppColors.surface),
                        ),
                        Text(
                          user?.email ?? '',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.surface.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          _roleLabel(user?.role.name ?? ''),
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.brandPrimary100,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            const CasaSectionHeader(title: 'Sistema'),
            const SizedBox(height: AppSpacing.sm),
            _SettingsTile(
              icon: Icons.people_outline_rounded,
              label: 'Gerenciar Usuários',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.category_outlined,
              label: 'Categorias',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.location_on_outlined,
              label: 'Localizações / Prateleiras',
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Configurações de Alertas',
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.lg),

            const CasaSectionHeader(title: 'Dados'),
            const SizedBox(height: AppSpacing.sm),
            _SettingsTile(
              icon: Icons.history_rounded,
              label: 'Auditoria',
              onTap: () => context.push(AppRoutes.audit),
            ),
            _SettingsTile(
              icon: Icons.bar_chart_rounded,
              label: 'Relatórios',
              onTap: () => context.push(AppRoutes.reports),
            ),
            const SizedBox(height: AppSpacing.lg),

            const CasaSectionHeader(title: 'Conta'),
            const SizedBox(height: AppSpacing.sm),
            _SettingsTile(
              icon: Icons.logout_rounded,
              label: 'Sair',
              color: AppColors.danger600,
              onTap: () async {
                final confirm = await CasaDialogConfirmacao.show(
                  context: context,
                  title: 'Sair',
                  message: 'Deseja encerrar sua sessão?',
                  confirmLabel: 'Sair',
                  isDanger: true,
                );
                if (confirm == true && context.mounted) {
                  await ref.read(authNotifierProvider.notifier).signOut();
                  if (context.mounted) context.go(AppRoutes.login);
                }
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            Center(
              child: Text(
                'EducaStock v1.0.0 • ONG Casa da Criança',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.neutral500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) => switch (role) {
        'admin' => 'Administrador',
        'estoquista' => 'Estoquista',
        'voluntario' => 'Voluntário Autorizado',
        'consulta' => 'Consulta',
        _ => role,
      };
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.neutral700;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Row(
            children: [
              Icon(icon, color: c, size: 22),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyLarge.copyWith(color: c),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.neutral500, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
