import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../auth/presentation/utils/auth_error_mapper.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool loading = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Trocar senha'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CasaTextField(
                      label: 'Senha atual',
                      controller: currentController,
                      obscureText: obscureCurrent,
                      suffixIcon: IconButton(
                        onPressed: () => setStateDialog(
                          () => obscureCurrent = !obscureCurrent,
                        ),
                        icon: Icon(
                          obscureCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CasaTextField(
                      label: 'Nova senha',
                      controller: newController,
                      obscureText: obscureNew,
                      suffixIcon: IconButton(
                        onPressed: () => setStateDialog(
                          () => obscureNew = !obscureNew,
                        ),
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CasaTextField(
                      label: 'Confirmar nova senha',
                      controller: confirmController,
                      obscureText: obscureConfirm,
                      suffixIcon: IconButton(
                        onPressed: () => setStateDialog(
                          () => obscureConfirm = !obscureConfirm,
                        ),
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final current = currentController.text;
                          final next = newController.text;
                          final confirm = confirmController.text;

                          if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
                            showCasaSnackbar(
                              context,
                              message: 'Preencha todos os campos.',
                              isError: true,
                            );
                            return;
                          }
                          if (next.length < 6) {
                            showCasaSnackbar(
                              context,
                              message: 'Nova senha deve ter pelo menos 6 caracteres.',
                              isError: true,
                            );
                            return;
                          }
                          if (next != confirm) {
                            showCasaSnackbar(
                              context,
                              message: 'As senhas nao conferem.',
                              isError: true,
                            );
                            return;
                          }

                          setStateDialog(() => loading = true);
                          try {
                            await ref
                                .read(authNotifierProvider.notifier)
                                .changePassword(
                                  currentPassword: current,
                                  newPassword: next,
                                );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              showCasaSnackbar(
                                context,
                                message: 'Senha alterada com sucesso.',
                                isSuccess: true,
                              );
                            }
                          } catch (error) {
                            if (context.mounted) {
                              showCasaSnackbar(
                                context,
                                message: mapAuthError(
                                  error,
                                  fallback: 'Nao foi possivel trocar a senha.',
                                ),
                                isError: true,
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setStateDialog(() => loading = false);
                            }
                          }
                        },
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ModernProfileAppBar(
        title: 'Configuracoes',
        subtitle: 'Preferencias e conta',
        profileName: user?.name,
        onProfileTap: () {},
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // Perfil do usuário
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandPrimary600, AppColors.secondaryBlue600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.card),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary600.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    radius: 28,
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'U',
                      style: AppTypography.headingMedium
                          .copyWith(color: Colors.white),
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
                              .copyWith(color: Colors.white),
                        ),
                        Text(
                          user?.email ?? '',
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          _roleLabel(user?.role.name ?? ''),
                          style: AppTypography.labelSmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
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
              onTap: () => context.push(AppRoutes.usersManagement),
            ),
            _SettingsTile(
              icon: Icons.category_outlined,
              label: 'Categorias',
              onTap: () => context.push(AppRoutes.categoriesSettings),
            ),
            _SettingsTile(
              icon: Icons.location_on_outlined,
              label: 'Localizações / Prateleiras',
              onTap: () => context.push(AppRoutes.locations),
            ),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Configurações de Alertas',
              onTap: () => context.push(AppRoutes.alertsSettings),
            ),
            _SettingsTile(
              icon: Icons.approval_outlined,
              label: 'Aprovações de Ajuste',
              onTap: () => context.push(AppRoutes.adjustmentApprovals),
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
            _SettingsSwitchTile(
              icon: Icons.dark_mode_outlined,
              label: 'Tema escuro',
              value: isDark,
              onChanged: (v) async {
                await ref.read(themeModeProvider.notifier).toggleDark(v);
              },
            ),
            _SettingsTile(
              icon: Icons.password_rounded,
              label: 'Trocar senha',
              onTap: () => _showChangePasswordDialog(context, ref),
            ),
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
                  color: cs.onSurfaceVariant,
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
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Icon(icon, color: c, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyLarge.copyWith(color: c),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(icon, color: cs.onSurface, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyLarge.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
