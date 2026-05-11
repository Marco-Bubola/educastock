import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../settings/presentation/controllers/system_settings_provider.dart';
import '../controllers/alerts_provider.dart';

class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  final _keyAlertCard = GlobalKey();
  final _keyAlertList = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
  }

  Future<void> _runCheck() async {
    final config = ref.read(alertsConfigProvider).valueOrNull;
    if (config == null || !config.expiryEnabled) return;
    try {
      await ref.read(alertsNotifierProvider.notifier).checkAlerts(
            config.criticalDays,
            config.warningDays,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = ref.watch(currentUserProvider);
    final alertsAsync = ref.watch(activeAlertsProvider);
    final alertsConfig = ref.watch(alertsConfigProvider);

    if (alertsConfig.valueOrNull?.expiryEnabled == false) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: ModernProfileAppBar(
          title: 'Alertas',
          subtitle: 'Alertas desativados',
          profileName: user?.name,
          onProfileTap: () => context.push(AppRoutes.settings),
          actions: [
            buildHelpButton(
              context: context,
              onPressed: () => showCasaTutorial(
                context: context,
                steps: [
                  TutorialStep(
                    key: _keyAlertCard,
                    title: 'Alertas de Vencimento',
                    description: 'Os alertas mostram produtos próximos do vencimento ou já vencidos. Ative os alertas em Configurações para começar o monitoramento automático.',
                    icon: Icons.notification_important_rounded,
                    align: ContentAlign.bottom,
                    hints: const [
                      'Vá em Configurações → Alertas para ativar',
                      'Defina quantos dias antes do vencimento você quer ser avisado',
                      'Alertas aparecem também na tela inicial do app',
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        body: const SafeArea(
          child: CasaEmptyState(
            icon: Icons.notifications_off_outlined,
            title: 'Alertas desativados',
            description: 'Ative em Configurações → Alertas para monitorar prazos.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ModernProfileAppBar(
        title: 'Alertas de Validade',
        subtitle: alertsAsync.when(
          data: (list) => '${list.length} alerta(s) ativo(s)',
          loading: () => 'Carregando...',
          error: (_, __) => 'Erro ao carregar',
        ),
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyAlertCard,
                  title: 'Card de Alerta',
                  description: 'Cada card mostra um produto com validade próxima ou vencida. A cor indica a urgência: vermelho = crítico, amarelo = atenção.',
                  icon: Icons.notification_important_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🔴 Vermelho: vence em até 7 dias ou já venceu — ação imediata!',
                    '🟡 Amarelo: vence em até 30 dias — monitore e distribua',
                    'Toque no card para ir direto ao produto e lote',
                    'Distribua primeiro os itens com validade mais próxima',
                  ],
                ),
                TutorialStep(
                  key: _keyAlertList,
                  title: 'Lista de Alertas',
                  description: 'Todos os produtos que precisam de atenção estão listados aqui em ordem de urgência. Resolva os vermelhos primeiro para evitar desperdício e garantir segurança alimentar.',
                  icon: Icons.list_alt_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'A lista atualiza automaticamente conforme o estoque muda',
                    'Produtos vencidos: registre descarte em "Saída" → Vencimento',
                    'Dica: distribua por FEFO (First Expiry, First Out)',
                    'Toque em um alerta para ver os lotes específicos do produto',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: alertsAsync.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 5,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const CasaCardSkeleton(),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar alertas',
            description: e.toString(),
          ),
          data: (alerts) {
            if (alerts.isEmpty) {
              return const CasaEmptyState(
                icon: Icons.check_circle_outline_rounded,
                title: 'Nenhum alerta ativo',
                description: 'Tudo em dia! Nenhum produto com validade próxima.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              itemCount: alerts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) {
                final card = _AlertCard(alert: alerts[i], cs: cs);
                if (i == 0) {
                  return KeyedSubtree(key: _keyAlertCard, child: card);
                }
                if (i == 1) {
                  return KeyedSubtree(key: _keyAlertList, child: card);
                }
                return card;
              },
            );
          },
        ),
      ),
    );
  }
}

// ─── Alert card ───────────────────────────────────────────────────────────

class _AlertCard extends ConsumerWidget {
  final StockAlert alert;
  final ColorScheme cs;

  const _AlertCard({required this.alert, required this.cs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    final color = switch (alert.level) {
      AlertLevel.critical => AppColors.danger600,
      AlertLevel.warning => AppColors.warning600,
      AlertLevel.info => AppColors.brandPrimary600,
    };

    final icon = switch (alert.level) {
      AlertLevel.critical => Icons.warning_amber_rounded,
      AlertLevel.warning => Icons.schedule_rounded,
      AlertLevel.info => Icons.info_outline_rounded,
    };

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.message,
                  style: AppTypography.labelMedium.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fmt.format(alert.createdAt),
                  style: AppTypography.bodySmall
                      .copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Resolver',
            icon: Icon(Icons.check_circle_outline_rounded,
                color: AppColors.success600, size: 22),
            onPressed: () async {
              try {
                await ref
                    .read(alertsNotifierProvider.notifier)
                    .resolve(alert.id);
                if (!context.mounted) return;
                showCasaSnackbar(context,
                    message: 'Alerta resolvido!', isSuccess: true);
              } catch (_) {
                if (!context.mounted) return;
                showCasaSnackbar(context,
                    message: 'Erro ao resolver alerta.', isError: true);
              }
            },
          ),
        ],
      ),
    );
  }
}


