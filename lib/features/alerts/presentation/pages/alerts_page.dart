import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final _keyFilters = GlobalKey();

  AlertLevel? _filter; // null = todos

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
        body: Column(children: [
        ModernProfileAppBar(
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
                    description:
                        'Os alertas mostram produtos próximos do vencimento ou já vencidos. Ative os alertas em Configurações para começar o monitoramento automático.',
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
        const Expanded(child: CasaEmptyState(
            icon: Icons.notifications_off_outlined,
            title: 'Alertas desativados',
            description: 'Ative em Configurações → Alertas para monitorar prazos.',
          )),
        ]),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: Column(children: [
      ModernProfileAppBar(
        title: 'Notificações',
        subtitle: alertsAsync.when(
          data: (list) => list.isEmpty
              ? 'Tudo em dia'
              : '${list.length} ${list.length == 1 ? 'alerta ativo' : 'alertas ativos'}',
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
                  description: 'Cada cartão alerta sobre um produto com validade próxima ou vencida. Mostra: ícone de urgência, nome do produto, mensagem (quantos dias para vencer), horário de geração e botão para resolver. A cor indica criticidade.',
                  icon: Icons.notification_important_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🔴 Vermelho (crítico): vence em até 7 dias',
                    '🟡 Amarelo (atenção): vence em até 30 dias',
                    '🔵 Azul (info): alertas manuais customizados',
                    '✓ Botão check verde resolve o alerta',
                  ],
                ),
                TutorialStep(
                  key: _keyFilters,
                  title: 'Filtros por Urgência',
                  description: 'Os chips coloridos no topo são filtros rápidos por nível de urgência. Cada chip mostra a contagem da categoria. Toque para filtrar; toque novamente para limpar. Combine com "Resolver Todos" para limpeza em massa.',
                  icon: Icons.filter_alt_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '👆 1 toque: ativa o filtro',
                    '👆 2 toques: limpa o filtro',
                    '🧹 "Resolver Todos" limpa a lista filtrada',
                    '🔢 Número no chip = quantos alertas naquela categoria',
                  ],
                ),
                TutorialStep(
                  key: _keyAlertList,
                  title: 'Lista Priorizada',
                  description: 'Todos os alertas ativos em ordem de urgência (mais críticos primeiro). Use gestos para resolver rapidamente: arraste para direita = resolver; arraste para esquerda = excluir. Toque longo abre menu de ações extras.',
                  icon: Icons.list_alt_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '👉 Arrastar para direita = resolver alerta',
                    '👈 Arrastar para esquerda = excluir',
                    '👇 Toque longo = mais ações (adiar, abrir produto)',
                    '📊 Lista atualiza automaticamente quando estoque muda',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      Expanded(child: alertsAsync.when(
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
              return _EmptyAllClear(cs: cs);
            }

            final filtered = _filter == null
                ? alerts
                : alerts.where((a) => a.level == _filter).toList();

            final counts = _SeverityCounts.from(alerts);

            return CustomScrollView(
              slivers: [
                // ── Banner de stats ─────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                    child: _StatsBanner(counts: counts, cs: cs),
                  ),
                ),

                // ── Filtros + ação em massa ─────────────────────
                SliverToBoxAdapter(
                  child: KeyedSubtree(
                    key: _keyFilters,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.md),
                      child: _FiltersRow(
                        current: _filter,
                        counts: counts,
                        onChanged: (lvl) =>
                            setState(() => _filter = _filter == lvl ? null : lvl),
                        onResolveAll: filtered.isEmpty
                            ? null
                            : () => _confirmResolveAll(filtered),
                      ),
                    ),
                  ),
                ),

                // ── Lista ────────────────────────────────────────
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyForFilter(level: _filter, cs: cs),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxxl),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) {
                        final card = _ModernAlertCard(
                          alert: filtered[i],
                          cs: cs,
                          onOpenActions: () => _showActionsSheet(filtered[i]),
                        );
                        if (i == 0) {
                          return KeyedSubtree(key: _keyAlertCard, child: card);
                        }
                        if (i == 1) {
                          return KeyedSubtree(key: _keyAlertList, child: card);
                        }
                        return card;
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateAlertSheet(context),
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('Alerta manual'),
        tooltip: 'Criar alerta manual',
      ),
    );
  }

  // ─── Ações ──────────────────────────────────────────────────────────────

  Future<void> _confirmResolveAll(List<StockAlert> list) async {
    final ok = await CasaDialogConfirmacao.show(
      context: context,
      title: 'Resolver ${list.length} ${list.length == 1 ? "alerta" : "alertas"}?',
      message:
          'Todos os alertas visíveis serão marcados como resolvidos. Você pode reativá-los criando novos.',
      confirmLabel: 'Resolver todos',
      cancelLabel: 'Cancelar',
    );
    if (ok != true || !mounted) return;
    try {
      HapticFeedback.mediumImpact();
      await ref
          .read(alertsNotifierProvider.notifier)
          .resolveAll(list.map((a) => a.id));
      if (!mounted) return;
      showCasaSnackbar(context,
          message: '${list.length} alertas resolvidos!', isSuccess: true);
    } catch (_) {
      if (!mounted) return;
      showCasaSnackbar(context,
          message: 'Erro ao resolver alertas.', isError: true);
    }
  }

  Future<void> _showActionsSheet(StockAlert alert) async {
    final cs = Theme.of(context).colorScheme;
    final color = _colorForLevel(alert.level);

    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          color.withValues(alpha: 0.9),
                          color.withValues(alpha: 0.55),
                        ]),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Icon(_iconForLevel(alert.level),
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(alert.productName,
                              style: AppTypography.labelMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(
                            _relativeTime(alert.createdAt),
                            style: AppTypography.bodySmall.copyWith(
                                color: cs.onSurfaceVariant, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
              // Actions
              if (!alert.isManual)
                _SheetAction(
                  icon: Icons.inventory_2_rounded,
                  label: 'Ver produto',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/products/${alert.productId}');
                  },
                ),
              _SheetAction(
                icon: Icons.check_circle_outline_rounded,
                label: 'Resolver',
                color: AppColors.success600,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _resolveAlert(alert);
                },
              ),
              _SheetAction(
                icon: Icons.snooze_rounded,
                label: 'Adiar...',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _showSnoozeSheet(alert);
                },
              ),
              _SheetAction(
                icon: Icons.delete_outline_rounded,
                label: 'Excluir',
                color: AppColors.danger600,
                onTap: () async {
                  Navigator.pop(ctx);
                  await _deleteAlert(alert);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSnoozeSheet(StockAlert alert) async {
    final cs = Theme.of(context).colorScheme;
    final options = [
      ('1 hora', const Duration(hours: 1)),
      ('4 horas', const Duration(hours: 4)),
      ('Amanhã', const Duration(days: 1)),
      ('Próxima semana', const Duration(days: 7)),
    ];

    final picked = await showModalBottomSheet<Duration>(
      context: context,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.snooze_rounded,
                        color: AppColors.brandPrimary600),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Adiar alerta', style: AppTypography.headingSmall),
                  ],
                ),
              ),
              for (final (label, dur) in options)
                _SheetAction(
                  icon: Icons.timer_outlined,
                  label: label,
                  onTap: () => Navigator.pop(ctx, dur),
                ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );

    if (picked == null || !mounted) return;
    try {
      await ref.read(alertsNotifierProvider.notifier).snooze(alert.id, picked);
      if (!mounted) return;
      showCasaSnackbar(context, message: 'Alerta adiado.', isSuccess: true);
    } catch (_) {
      if (!mounted) return;
      showCasaSnackbar(context,
          message: 'Erro ao adiar alerta.', isError: true);
    }
  }

  Future<void> _resolveAlert(StockAlert alert) async {
    try {
      HapticFeedback.lightImpact();
      await ref.read(alertsNotifierProvider.notifier).resolve(alert.id);
      if (!mounted) return;
      showCasaSnackbar(context,
          message: 'Alerta resolvido!', isSuccess: true);
    } catch (_) {
      if (!mounted) return;
      showCasaSnackbar(context,
          message: 'Erro ao resolver alerta.', isError: true);
    }
  }

  Future<void> _deleteAlert(StockAlert alert) async {
    final ok = await CasaDialogConfirmacao.show(
      context: context,
      title: 'Excluir alerta?',
      message: 'Esta ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
      isDanger: true,
    );
    if (ok != true || !mounted) return;
    try {
      HapticFeedback.mediumImpact();
      await ref.read(alertsNotifierProvider.notifier).delete(alert.id);
      if (!mounted) return;
      showCasaSnackbar(context,
          message: 'Alerta excluído.', isSuccess: true);
    } catch (_) {
      if (!mounted) return;
      showCasaSnackbar(context,
          message: 'Erro ao excluir alerta.', isError: true);
    }
  }

  // ─── Criação manual ─────────────────────────────────────────────────────

  Future<void> _showCreateAlertSheet(BuildContext context) async {
    final nameController = TextEditingController();
    final msgController = TextEditingController();
    AlertLevel selectedLevel = AlertLevel.warning;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.modal)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: const Icon(Icons.add_alert_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text('Criar Alerta Manual',
                        style: AppTypography.headingSmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Produto / Descrição',
                    style: AppTypography.labelMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Ex: Arroz, Feijão…',
                    prefixIcon: const Icon(Icons.inventory_2_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Nível de urgência',
                    style: AppTypography.labelMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: AlertLevel.values.map((lvl) {
                    final color = _colorForLevel(lvl);
                    final label = switch (lvl) {
                      AlertLevel.critical => '🔴 Crítico',
                      AlertLevel.warning => '🟡 Atenção',
                      AlertLevel.info => '🔵 Info',
                    };
                    return ChoiceChip(
                      label: Text(label),
                      selected: selectedLevel == lvl,
                      selectedColor: color.withValues(alpha: 0.18),
                      onSelected: (_) => setModal(() => selectedLevel = lvl),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Mensagem',
                    style: AppTypography.labelMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: msgController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Descreva o motivo do alerta…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add_alert_rounded, size: 18),
                        label: const Text('Criar alerta'),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          final msg = msgController.text.trim();
                          if (name.isEmpty || msg.isEmpty) {
                            showCasaSnackbar(ctx,
                                message: 'Preencha todos os campos.',
                                isError: true);
                            return;
                          }
                          Navigator.pop(ctx);
                          try {
                            await ref
                                .read(alertsNotifierProvider.notifier)
                                .createManualAlert(
                                  productName: name,
                                  level: selectedLevel,
                                  message: msg,
                                );
                            if (!context.mounted) return;
                            showCasaSnackbar(context,
                                message: 'Alerta criado com sucesso!',
                                isSuccess: true);
                          } catch (e) {
                            if (!context.mounted) return;
                            showCasaSnackbar(context,
                                message: 'Erro ao criar alerta.',
                                isError: true);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    nameController.dispose();
    msgController.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers visuais
// ═══════════════════════════════════════════════════════════════════════════

Color _colorForLevel(AlertLevel lvl) => switch (lvl) {
      AlertLevel.critical => AppColors.danger600,
      AlertLevel.warning => AppColors.warning600,
      AlertLevel.info => AppColors.brandPrimary600,
    };

IconData _iconForLevel(AlertLevel lvl) => switch (lvl) {
      AlertLevel.critical => Icons.warning_amber_rounded,
      AlertLevel.warning => Icons.schedule_rounded,
      AlertLevel.info => Icons.info_outline_rounded,
    };

String _labelForLevel(AlertLevel lvl) => switch (lvl) {
      AlertLevel.critical => 'Críticos',
      AlertLevel.warning => 'Atenção',
      AlertLevel.info => 'Info',
    };

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return 'há $m min';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return 'há $h ${h == 1 ? "hora" : "horas"}';
  }
  if (diff.inDays < 7) {
    final d = diff.inDays;
    return 'há $d ${d == 1 ? "dia" : "dias"}';
  }
  if (diff.inDays < 30) {
    final w = (diff.inDays / 7).floor();
    return 'há $w ${w == 1 ? "semana" : "semanas"}';
  }
  final months = (diff.inDays / 30).floor();
  return 'há $months ${months == 1 ? "mês" : "meses"}';
}

// ═══════════════════════════════════════════════════════════════════════════
// Stats banner
// ═══════════════════════════════════════════════════════════════════════════

class _SeverityCounts {
  final int critical;
  final int warning;
  final int info;
  const _SeverityCounts(this.critical, this.warning, this.info);

  int get total => critical + warning + info;

  factory _SeverityCounts.from(List<StockAlert> list) {
    var c = 0, w = 0, i = 0;
    for (final a in list) {
      switch (a.level) {
        case AlertLevel.critical:
          c++;
        case AlertLevel.warning:
          w++;
        case AlertLevel.info:
          i++;
      }
    }
    return _SeverityCounts(c, w, i);
  }

  int countFor(AlertLevel lvl) => switch (lvl) {
        AlertLevel.critical => critical,
        AlertLevel.warning => warning,
        AlertLevel.info => info,
      };
}

class _StatsBanner extends StatelessWidget {
  final _SeverityCounts counts;
  final ColorScheme cs;
  const _StatsBanner({required this.counts, required this.cs});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppColors.brandPrimary800.withValues(alpha: 0.5),
                  AppColors.brandPrimary600.withValues(alpha: 0.25),
                ]
              : [
                  AppColors.brandPrimary600.withValues(alpha: 0.08),
                  AppColors.secondarySky500.withValues(alpha: 0.05),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.modal),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Expanded(
              child: _StatTile(
                  label: 'Críticos',
                  count: counts.critical,
                  color: AppColors.danger600,
                  icon: Icons.warning_amber_rounded,
                  cs: cs)),
          Container(
              width: 1,
              height: 42,
              color: cs.outlineVariant.withValues(alpha: 0.35)),
          Expanded(
              child: _StatTile(
                  label: 'Atenção',
                  count: counts.warning,
                  color: AppColors.warning600,
                  icon: Icons.schedule_rounded,
                  cs: cs)),
          Container(
              width: 1,
              height: 42,
              color: cs.outlineVariant.withValues(alpha: 0.35)),
          Expanded(
              child: _StatTile(
                  label: 'Info',
                  count: counts.info,
                  color: AppColors.brandPrimary600,
                  icon: Icons.info_outline_rounded,
                  cs: cs)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final ColorScheme cs;

  const _StatTile({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: AppTypography.headingMedium.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: cs.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Filtros + ação em massa
// ═══════════════════════════════════════════════════════════════════════════

class _FiltersRow extends StatelessWidget {
  final AlertLevel? current;
  final _SeverityCounts counts;
  final ValueChanged<AlertLevel> onChanged;
  final VoidCallback? onResolveAll;

  const _FiltersRow({
    required this.current,
    required this.counts,
    required this.onChanged,
    required this.onResolveAll,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final lvl in AlertLevel.values) ...[
                    _FilterChip(
                      label: _labelForLevel(lvl),
                      count: counts.countFor(lvl),
                      color: _colorForLevel(lvl),
                      selected: current == lvl,
                      onTap: () => onChanged(lvl),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              ),
            ),
          ),
          if (onResolveAll != null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: TextButton.icon(
                onPressed: onResolveAll,
                icon: const Icon(Icons.done_all_rounded, size: 16),
                label: const Text('Resolver todos'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.success600,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  textStyle: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : cs.outlineVariant.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: selected ? color : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withValues(alpha: 0.25)
                      : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$count',
                  style: AppTypography.labelSmall.copyWith(
                    color: selected ? color : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Card moderno
// ═══════════════════════════════════════════════════════════════════════════

class _ModernAlertCard extends ConsumerWidget {
  final StockAlert alert;
  final ColorScheme cs;
  final VoidCallback onOpenActions;

  const _ModernAlertCard({
    required this.alert,
    required this.cs,
    required this.onOpenActions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorForLevel(alert.level);
    final icon = _iconForLevel(alert.level);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey('alert-${alert.id}'),
      // Direita: resolver (verde)
      background: _SwipeBg(
        align: Alignment.centerLeft,
        color: AppColors.success600,
        icon: Icons.check_circle_rounded,
        label: 'Resolver',
      ),
      // Esquerda: excluir (vermelho)
      secondaryBackground: _SwipeBg(
        align: Alignment.centerRight,
        color: AppColors.danger600,
        icon: Icons.delete_forever_rounded,
        label: 'Excluir',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          HapticFeedback.lightImpact();
          try {
            await ref
                .read(alertsNotifierProvider.notifier)
                .resolve(alert.id);
            if (context.mounted) {
              showCasaSnackbar(context,
                  message: 'Alerta resolvido!', isSuccess: true);
            }
            return true;
          } catch (_) {
            if (context.mounted) {
              showCasaSnackbar(context,
                  message: 'Erro ao resolver.', isError: true);
            }
            return false;
          }
        } else {
          final ok = await CasaDialogConfirmacao.show(
            context: context,
            title: 'Excluir alerta?',
            message: 'Esta ação não pode ser desfeita.',
            confirmLabel: 'Excluir',
            isDanger: true,
          );
          if (ok != true) return false;
          try {
            HapticFeedback.mediumImpact();
            await ref
                .read(alertsNotifierProvider.notifier)
                .delete(alert.id);
            if (context.mounted) {
              showCasaSnackbar(context,
                  message: 'Alerta excluído.', isSuccess: true);
            }
            return true;
          } catch (_) {
            if (context.mounted) {
              showCasaSnackbar(context,
                  message: 'Erro ao excluir.', isError: true);
            }
            return false;
          }
        }
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.modal),
          onTap: alert.isManual
              ? onOpenActions
              : () {
                  HapticFeedback.selectionClick();
                  context.push('/products/${alert.productId}');
                },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onOpenActions();
          },
          child: Ink(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.modal),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.35 : 0.22),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Barra vertical de cor (gradiente)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.55)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.modal),
                        bottomLeft: Radius.circular(AppRadius.modal),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(AppSpacing.md + 4, AppSpacing.md, 4, AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ícone em badge gradiente
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.95),
                              color.withValues(alpha: 0.55),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppRadius.small),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Conteúdo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    alert.productName,
                                    style: AppTypography.labelMedium.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _LevelPill(level: alert.level, color: color),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alert.message,
                              style: AppTypography.bodySmall.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 12,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  _relativeTime(alert.createdAt),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                                if (!alert.isManual) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: cs.onSurfaceVariant
                                          .withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Icon(Icons.touch_app_outlined,
                                      size: 12,
                                      color: cs.onSurfaceVariant
                                          .withValues(alpha: 0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Ver produto',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Menu (3 pontos)
                      IconButton(
                        tooltip: 'Mais ações',
                        icon: Icon(Icons.more_vert_rounded,
                            color: cs.onSurfaceVariant),
                        onPressed: onOpenActions,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  final AlertLevel level;
  final Color color;
  const _LevelPill({required this.level, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = switch (level) {
      AlertLevel.critical => 'CRÍTICO',
      AlertLevel.warning => 'ATENÇÃO',
      AlertLevel.info => 'INFO',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final Alignment align;
  final Color color;
  final IconData icon;
  final String label;

  const _SwipeBg({
    required this.align,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.85), color],
          begin: align == Alignment.centerLeft
              ? Alignment.centerLeft
              : Alignment.centerRight,
          end: align == Alignment.centerLeft
              ? Alignment.centerRight
              : Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(AppRadius.modal),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      alignment: align,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sheet action item
// ═══════════════════════════════════════════════════════════════════════════

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: c, size: 22),
            const SizedBox(width: AppSpacing.md),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: c,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Empty states
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyAllClear extends StatelessWidget {
  final ColorScheme cs;
  const _EmptyAllClear({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.success600.withValues(alpha: 0.18),
                    AppColors.success600.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  size: 48, color: AppColors.success600),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Tudo em dia!',
              style: AppTypography.headingMedium.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Nenhum produto com validade próxima.\nVocê está no controle.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyForFilter extends StatelessWidget {
  final AlertLevel? level;
  final ColorScheme cs;
  const _EmptyForFilter({required this.level, required this.cs});

  @override
  Widget build(BuildContext context) {
    final color = level == null
        ? AppColors.success600
        : _colorForLevel(level!);
    final label =
        level == null ? 'tudo em dia' : 'nenhum em ${_labelForLevel(level!).toLowerCase()}';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_rounded,
                size: 48, color: color.withValues(alpha: 0.65)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sem alertas — $label',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
