import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../controllers/system_settings_provider.dart';

class AlertsSettingsPage extends ConsumerStatefulWidget {
  const AlertsSettingsPage({super.key});

  @override
  ConsumerState<AlertsSettingsPage> createState() => _AlertsSettingsPageState();
}

class _AlertsSettingsPageState extends ConsumerState<AlertsSettingsPage> {
  final _criticalCtrl = TextEditingController();
  final _warningCtrl = TextEditingController();
  bool _expiryEnabled = true;
  bool _initialized = false;

  @override
  void dispose() {
    _criticalCtrl.dispose();
    _warningCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    ref.watch(alertsConfigNotifierProvider);
    final user = ref.watch(currentUserProvider);
    final configState = ref.watch(alertsConfigProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ModernProfileAppBar(
        title: 'Configurações de Alertas',
        subtitle: 'Regras de vencimento e criticidade',
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        showBackButton: true,
      ),
      body: SafeArea(
        child: configState.when(
          data: (config) {
            if (!_initialized) {
              _criticalCtrl.text = config.criticalDays.toString();
              _warningCtrl.text = config.warningDays.toString();
              _expiryEnabled = config.expiryEnabled;
              _initialized = true;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              children: [
                // ─── Banner informativo
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.brandPrimary600.withValues(alpha: 0.08),
                        AppColors.brandPrimary600.withValues(alpha: 0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                        color: AppColors.brandPrimary600.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary100,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: const Icon(Icons.notifications_active_rounded,
                            color: AppColors.brandPrimary600, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sistema de alertas',
                                style: AppTypography.labelMedium
                                    .copyWith(color: cs.onSurface,
                                        fontWeight: FontWeight.w700)),
                            Text(
                              'Configure os prazos que ativam notificações de vencimento.',
                              style: AppTypography.bodySmall
                                  .copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // ─── Card principal
                Container(
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
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Toggle ativo/inativo
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _expiryEnabled
                                  ? AppColors.success600.withValues(alpha: 0.1)
                                  : cs.surfaceContainer,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.small),
                            ),
                            child: Icon(Icons.notifications_outlined,
                                color: _expiryEnabled
                                    ? AppColors.success600
                                    : cs.onSurfaceVariant,
                                size: 20),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Alerta por vencimento',
                                    style: AppTypography.labelLarge
                                        .copyWith(color: cs.onSurface)),
                                Text(
                                  _expiryEnabled ? 'Ativo' : 'Inativo',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: _expiryEnabled
                                        ? AppColors.success600
                                        : cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _expiryEnabled,
                            onChanged: (v) =>
                                setState(() => _expiryEnabled = v),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Divider(height: 1),
                      ),

                      // Dias crítico
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                                color: AppColors.danger600,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Prazo crítico',
                              style: AppTypography.labelMedium
                                  .copyWith(color: cs.onSurface)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      CasaTextField(
                        label: 'Dias para alerta crítico',
                        hint: 'Ex: 7',
                        controller: _criticalCtrl,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.warning_rounded,
                            size: 18, color: AppColors.danger600),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Dias atenção
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                                color: AppColors.warning600,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Prazo de atenção',
                              style: AppTypography.labelMedium
                                  .copyWith(color: cs.onSurface)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      CasaTextField(
                        label: 'Dias para alerta de atenção',
                        hint: 'Ex: 30',
                        controller: _warningCtrl,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(Icons.schedule_rounded,
                            size: 18, color: AppColors.warning600),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      CasaButton(
                        label: 'Salvar configurações',
                        icon: Icons.save_rounded,
                        onPressed: () async {
                          final critical =
                              int.tryParse(_criticalCtrl.text.trim());
                          final warning =
                              int.tryParse(_warningCtrl.text.trim());

                          if (critical == null || warning == null) {
                            showCasaSnackbar(context,
                                message: 'Preencha os dias com números válidos.',
                                isError: true);
                            return;
                          }
                          if (critical <= 0 ||
                              warning <= 0 ||
                              warning <= critical) {
                            showCasaSnackbar(context,
                                message:
                                    'Atenção deve ser maior que crítico e ambos maiores que zero.',
                                isError: true);
                            return;
                          }

                          await ref
                              .read(alertsConfigNotifierProvider.notifier)
                              .save(AlertsConfig(
                                criticalDays: critical,
                                warningDays: warning,
                                expiryEnabled: _expiryEnabled,
                              ));
                          if (!context.mounted) return;
                          showCasaSnackbar(context,
                              message: 'Configurações salvas!',
                              isSuccess: true);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ─── Preview das faixas
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.35)),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Faixas de urgência',
                          style: AppTypography.labelMedium
                              .copyWith(color: cs.onSurface)),
                      const SizedBox(height: AppSpacing.sm),
                      _UrgencyRow(
                          color: AppColors.danger600,
                          label:
                              'Crítico — 0 a ${_criticalCtrl.text.isEmpty ? '?' : _criticalCtrl.text} dias',
                          icon: Icons.warning_rounded),
                      const SizedBox(height: AppSpacing.xs),
                      _UrgencyRow(
                          color: AppColors.warning600,
                          label:
                              'Atenção — até ${_warningCtrl.text.isEmpty ? '?' : _warningCtrl.text} dias',
                          icon: Icons.schedule_rounded),
                      const SizedBox(height: AppSpacing.xs),
                      _UrgencyRow(
                          color: AppColors.success600,
                          label: 'OK — acima do prazo de atenção',
                          icon: Icons.check_circle_outline_rounded),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const CasaCardSkeleton(),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar configurações',
            description: e.toString(),
          ),
        ),
      ),
    );
  }
}

class _UrgencyRow extends StatelessWidget {
  final Color color;
  final String label;
  final IconData icon;
  const _UrgencyRow(
      {required this.color, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(label,
            style: AppTypography.bodySmall
                .copyWith(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}


class AlertsSettingsPage extends ConsumerStatefulWidget {
  const AlertsSettingsPage({super.key});

  @override
  ConsumerState<AlertsSettingsPage> createState() => _AlertsSettingsPageState();
}

class _AlertsSettingsPageState extends ConsumerState<AlertsSettingsPage> {
  final _criticalCtrl = TextEditingController();
  final _warningCtrl = TextEditingController();
  bool _expiryEnabled = true;
  bool _initialized = false;

  @override
  void dispose() {
    _criticalCtrl.dispose();
    _warningCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(alertsConfigNotifierProvider);
    final user = ref.watch(currentUserProvider);
    final configState = ref.watch(alertsConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ModernProfileAppBar(
        title: 'Configuracoes de alertas',
        subtitle: 'Regras de vencimento e criticidade',
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        showBackButton: true,
      ),
      body: SafeArea(
        child: configState.when(
          data: (config) {
            if (!_initialized) {
              _criticalCtrl.text = config.criticalDays.toString();
              _warningCtrl.text = config.warningDays.toString();
              _expiryEnabled = config.expiryEnabled;
              _initialized = true;
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Alerta por vencimento',
                              style: AppTypography.labelLarge,
                            ),
                          ),
                          Switch(
                            value: _expiryEnabled,
                            onChanged: (v) => setState(() => _expiryEnabled = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CasaTextField(
                        label: 'Dias para alerta critico',
                        hint: 'Ex: 7',
                        controller: _criticalCtrl,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      CasaTextField(
                        label: 'Dias para alerta de atencao',
                        hint: 'Ex: 30',
                        controller: _warningCtrl,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      CasaButton(
                        label: 'Salvar configuracoes',
                        icon: Icons.save_rounded,
                        onPressed: () async {
                          final critical = int.tryParse(_criticalCtrl.text.trim());
                          final warning = int.tryParse(_warningCtrl.text.trim());

                          if (critical == null || warning == null) {
                            showCasaSnackbar(
                              context,
                              message: 'Preencha os dias com numeros validos.',
                              isError: true,
                            );
                            return;
                          }

                          if (critical <= 0 || warning <= 0 || warning <= critical) {
                            showCasaSnackbar(
                              context,
                              message:
                                  'Atenção deve ser maior que crítico e ambos maiores que zero.',
                              isError: true,
                            );
                            return;
                          }

                          await ref
                              .read(alertsConfigNotifierProvider.notifier)
                              .save(
                                AlertsConfig(
                                  criticalDays: critical,
                                  warningDays: warning,
                                  expiryEnabled: _expiryEnabled,
                                ),
                              );

                          if (!context.mounted) return;
                          showCasaSnackbar(
                            context,
                            message: 'Configuracoes salvas com sucesso.',
                            isSuccess: true,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const CasaCardSkeleton(),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar configuracoes',
            description: e.toString(),
          ),
        ),
      ),
    );
  }
}
