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
