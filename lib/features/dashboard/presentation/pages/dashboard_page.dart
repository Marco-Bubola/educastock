import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../ml/presentation/controllers/risk_classifier_provider.dart';
import '../../../ml/presentation/widgets/risk_widgets.dart';

final _keyDashQuickActions = GlobalKey();
final _keyDashExpiring = GlobalKey();
final _keyDashHeader = GlobalKey();
final _keyDashMlRisk = GlobalKey();

class DashboardPageextends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final expiringCritical = ref.watch(expiringBatchesProvider(7));
    final expiringWarning = ref.watch(expiringBatchesProvider(30));
    final allBatches = ref.watch(allAvailableBatchesProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ─── Header completo ─────────────────────────────────────────
            KeyedSubtree(
              key: _keyDashHeader,
              child: _DashboardHeader(
              user: user,
              allBatches: allBatches,
              expiringCritical: expiringCritical,
              expiringWarning: expiringWarning,
              onSettingsTap: () => context.push(AppRoutes.settings),
              onLotesTap: () => context.go(AppRoutes.productList),
              onAlertsTap: () => context.go(AppRoutes.alerts),
              onHelpTap: () => showCasaTutorial(
                context: context,
                steps: [
                  TutorialStep(
                    key: _keyDashHeader,
                    title: 'Visão Geral do Estoque',
                    description: 'Os três cards coloridos mostram os indicadores mais importantes: total de lotes, itens que vencem em 7 dias (crítico) e itens com atenção em 30 dias.',
                    icon: Icons.dashboard_rounded,
                    align: ContentAlign.bottom,
                    hints: const [
                      'Toque em qualquer card para ver os detalhes',
                      'Vermelho = ação imediata necessária!',
                      'O número atualiza em tempo real conforme o estoque',
                    ],
                  ),
                  TutorialStep(
                    key: _keyDashQuickActions,
                    title: 'Ações Rápidas',
                    description: 'Toque nos cartões coloridos para acessar rapidamente as principais funções: Escanear, Estoque, Saída, Receitas, Alertas e Localizações.',
                    icon: Icons.grid_view_rounded,
                    align: ContentAlign.bottom,
                    hints: const [
                      'Escanear: registre entradas pelo código de barras',
                      'Saída: distribua produtos manualmente',
                      'Receitas: distribua por modelo de distribuição',
                      'Alertas: veja todos os produtos próximos do vencimento',
                    ],
                  ),
                  TutorialStep(
                    key: _keyDashMlRisk,
                    title: 'Análise de Risco por IA',
                    description: 'O sistema usa Inteligência Artificial para prever quais produtos têm maior risco de vencer sem ser distribuídos, baseado no histórico de saídas e validade.',
                    icon: Icons.psychology_rounded,
                    align: ContentAlign.bottom,
                    hints: const [
                      '🔴 Alto risco: distribua com urgência',
                      '🟡 Médio risco: monitore de perto',
                      '🟢 Baixo risco: situação controlada',
                      'Toque em "Ver detalhes" para análise completa',
                    ],
                  ),
                  TutorialStep(
                    key: _keyDashExpiring,
                    title: 'Alertas Críticos',
                    description: 'Lista dos produtos que vencem em até 7 dias. Ação imediata necessária para evitar desperdício e garantir a segurança alimentar das crianças.',
                    icon: Icons.warning_amber_rounded,
                    align: ContentAlign.top,
                    hints: const [
                      'Distribua ou descarte produtos vencidos imediatamente',
                      'Registre o descarte em "Saída" com motivo "Vencimento"',
                      'Toque em "Ver todos" para a lista completa de alertas',
                    ],
                  ),
                ],
              ),
            ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Ações rápidas
            const CasaSectionHeader(title: 'Ações Rápidas'),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cross = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 620
                          ? 3
                          : 2;
                  return KeyedSubtree(
                    key: _keyDashQuickActions,
                    child: GridView.count(
                    crossAxisCount: cross,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1.72,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _AnimatedQuickAction(
                        delayMs: 0,
                        child: _QuickActionTile(
                          icon: Icons.qr_code_scanner_rounded,
                          label: 'Escanear',
                          subtitle: 'Entrada por código',
                          color: AppColors.brandPrimary600,
                          onTap: () => context.push(AppRoutes.scanner),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 60,
                        child: _QuickActionTile(
                          icon: Icons.list_alt_rounded,
                          label: 'Estoque',
                          subtitle: 'Produtos e lotes',
                          color: AppColors.secondaryBlue600,
                          onTap: () => context.go(AppRoutes.productList),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 120,
                        child: _QuickActionTile(
                          icon: Icons.outbound_rounded,
                          label: 'Saída',
                          subtitle: 'Baixa de estoque',
                          color: AppColors.danger600,
                          onTap: () => context.push('${AppRoutes.movement}?batchId='),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 180,
                        child: _QuickActionTile(
                          icon: Icons.menu_book_rounded,
                          label: 'Receitas',
                          subtitle: 'Saída automática',
                          color: AppColors.brandPrimary600,
                          onTap: () => context.push(AppRoutes.recipes),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 240,
                        child: _QuickActionTile(
                          icon: Icons.notifications_active_rounded,
                          label: 'Alertas',
                          subtitle: 'Prazos e riscos',
                          color: AppColors.warning600,
                          onTap: () => context.go(AppRoutes.alerts),
                        ),
                      ),
                      _AnimatedQuickAction(
                        delayMs: 300,
                        child: _QuickActionTile(
                          icon: Icons.add_location_alt_rounded,
                          label: 'Localizações',
                          subtitle: 'Estrutura física',
                          color: AppColors.secondaryBlue600,
                          onTap: () => context.push(AppRoutes.locations),
                        ),
                      ),
                    ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Análise de Risco ML
            KeyedSubtree(
              key: _keyDashMlRisk,
              child: _MlRiskSection(),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Alertas recentes
            expiringCritical.when(
              data: (batches) {
                if (batches.isEmpty) return const SizedBox.shrink();
                return Column(
                  key: _keyDashExpiring,
                  children: [
                    CasaSectionHeader(
                      title: 'Alertas Críticos',
                      count: batches.length,
                      action: 'Ver todos',
                      onAction: () => context.go(AppRoutes.alerts),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...batches.take(3).map(
                          (b) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.xs,
                            ),
                            child: _AlertBatchTile(batch: b),
                          ),
                        ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
        floatingActionButton: CasaFabScan(
          onPressed: () => context.push(AppRoutes.scanner),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard Header — Visão Geral completa
// ---------------------------------------------------------------------------

class _DashboardHeader extends ConsumerWidget {
  final dynamic user;
  final AsyncValue<List<dynamic>> allBatches;
  final AsyncValue<List<dynamic>> expiringCritical;
  final AsyncValue<List<dynamic>> expiringWarning;
  final VoidCallback onSettingsTap;
  final VoidCallback onLotesTap;
  final VoidCallback onAlertsTap;
  final VoidCallback onHelpTap;

  const _DashboardHeader({
    required this.user,
    required this.allBatches,
    required this.expiringCritical,
    required this.expiringWarning,
    required this.onSettingsTap,
    required this.onLotesTap,
    required this.onAlertsTap,
    required this.onHelpTap,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  String _formattedDate() {
    return DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(DateTime.now());
  }

  String _firstName() {
    final name = user?.name as String? ?? '';
    return name.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertCount = ref.watch(allAvailableBatchesProvider).when(
          data: (list) =>
              list.where((b) => !b.noExpiry && (b.isExpired || b.daysToExpiry <= 30)).length,
          loading: () => 0,
          error: (_, __) => 0,
        );
    final lotesCount = allBatches.maybeWhen(
        data: (l) => '${l.length}', orElse: () => '…');
    final critCount = expiringCritical.maybeWhen(
        data: (l) => '${l.length}', orElse: () => '…');
    final warnCount = expiringWarning.maybeWhen(
        data: (l) => '${l.length}', orElse: () => '…');
    final hasCritical =
        expiringCritical.maybeWhen(data: (l) => l.isNotEmpty, orElse: () => false);

    final normalizedName = user?.name?.trim() as String? ?? '';
    final initial = normalizedName.isEmpty
        ? 'U'
        : normalizedName.substring(0, 1).toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2444), Color(0xFF1A3A6B), Color(0xFF1D5FA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: saudação + avatar ────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()}, ${_firstName()} 👋',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formattedDate(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Botões de ação: sino + dark/light ─────────────
                  IconButton(
                    icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
                    tooltip: 'Dicas desta página',
                    onPressed: onHelpTap,
                  ),
                  CasaAlertsBellButton(
                    alertCount: alertCount,
                    onDarkBg: true,
                  ),
                  const SizedBox(width: 6),
                  const CasaThemeToggleButton(),
                  const SizedBox(width: 8),
                  // Avatar + settings
                  GestureDetector(
                    onTap: onSettingsTap,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Divisor ────────────────────────────────────────────────
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ── KPI cards ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _HeaderKpiCard(
                      icon: Icons.inventory_2_rounded,
,                       value: lotesCount,
                      label: 'Lotes',
                      gradientColors: const [
                        Color(0xFF1A56C4),
                        Color(0xFF2F74D0)
                      ],
                      onTap: onLotesTap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeaderKpiCard(
                      icon: Icons.warning_rounded,
                      value: critCount,
                      label: 'Vencem 7d',
                      gradientColors: const [
                        Color(0xFFC53030),
                        Color(0xFFE53E3E)
                      ],
                      badge: hasCritical ? critCount : null,
                      onTap: onAlertsTap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeaderKpiCard(
                      icon: Icons.schedule_rounded,
                      value: warnCount,
                      label: 'Atenção 30d',
                      gradientColors: const [
                        Color(0xFFB7791F),
                        Color(0xFFD69E2E)
                      ],
                      onTap: onAlertsTap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── KPI card dentro do header ─────────────────────────────────────────────

class _HeaderKpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final List<Color> gradientColors;
  final String? badge;
  final VoidCallback? onTap;

  const _HeaderKpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.gradientColors,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon,
                    color: Colors.white.withValues(alpha: 0.9), size: 22),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: const Offset(0, 1)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: gradientColors.first,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Ink(
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.16 : 0.09),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.22),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedQuickAction extends StatelessWidget {
  final int delayMs;
  final Widget child;

  const _AnimatedQuickAction({
    required this.delayMs,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (_, value, c) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

class _AlertBatchTile extends StatelessWidget {
  final dynamic batch;
  const _AlertBatchTile({required this.batch});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger600.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.danger600.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded,
              color: AppColors.danger600, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.productName as String,
                  style: AppTypography.labelLarge.copyWith(
                    color: onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Vence em ${batch.daysToExpiry} dia(s) • ${batch.quantity} ${batch.quantity == 1 ? 'un' : 'uns'}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.danger600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seção de Risco ML no dashboard
// ---------------------------------------------------------------------------

class _MlRiskSection extends ConsumerWidget {
  const _MlRiskSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(riskCountsProvider);
    final criticalAsync = ref.watch(criticalBatchPredictionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CasaSectionHeader(
          title: 'Análise de Risco ML',
          action: 'Ver detalhes',
          onAction: () => context.push(AppRoutes.mlInsights),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Contadores por nível
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: countsAsync.when(
            data: (counts) => RiskSummaryRow(counts: counts),
            loading: () => Row(
              children: List.generate(
                3,
                (_) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: CasaCardSkeleton(),
                  ),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Top críticos
        criticalAsync.when(
          data: (critical) {
            if (critical.isEmpty) return const SizedBox.shrink();
            return Column(
              children: critical.take(2).map(
                (p) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                  child: RiskInsightCard(
                    prediction: p,
                    onTap: () => context.push(AppRoutes.mlInsights),
                  ),
                ),
              ).toList(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
