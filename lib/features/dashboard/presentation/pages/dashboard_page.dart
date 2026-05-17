import 'package:fl_chart/fl_chart.dart';
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
import '../../../reports/presentation/controllers/reports_provider.dart';

final _keyDashQuickActions = GlobalKey();
final _keyDashExpiring = GlobalKey();
final _keyDashHeader = GlobalKey();
final _keyDashMlRisk = GlobalKey();
final _keyDashKpis = GlobalKey();

class DashboardPage extends ConsumerWidget {
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
              kpiKey: _keyDashKpis,
              onSettingsTap: () => context.push(AppRoutes.settings),
              onLotesTap: () => context.go(AppRoutes.productList),
              onAlertsTap: () => context.go(AppRoutes.alerts),
              onHelpTap: () => showCasaTutorial(
                context: context,
                steps: [
                  TutorialStep(
                    key: _keyDashKpis,
                    title: 'Indicadores do Estoque',
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
                    verticalOffset: -18,
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
                    align: ContentAlign.top,
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
            const _DashboardChartsSection(),

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
  final GlobalKey kpiKey;
  final VoidCallback onSettingsTap;
  final VoidCallback onLotesTap;
  final VoidCallback onAlertsTap;
  final VoidCallback onHelpTap;

  const _DashboardHeader({
    required this.user,
    required this.allBatches,
    required this.expiringCritical,
    required this.expiringWarning,
    required this.kpiKey,
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
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 360;
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

    final avatarSize = isCompact ? 38.0 : 44.0;

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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(width: 10),
                  // ── Botões de ação: dicas + sino + dark/light + avatar ─────────────
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      buildHelpButton(
                        context: context,
                        onPressed: onHelpTap,
                      ),
                      CasaAlertsBellButton(
                        alertCount: alertCount,
                        onDarkBg: true,
                      ),
                      const CasaThemeToggleButton(),
                      // Avatar + settings
                      GestureDetector(
                        onTap: onSettingsTap,
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
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
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: isCompact ? 16 : 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
              KeyedSubtree(
                key: kpiKey,
                child: Row(
                  children: [
                    Expanded(
                      child: _HeaderKpiCard(
                        icon: Icons.inventory_2_rounded,
                        value: lotesCount,
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

// ---------------------------------------------------------------------------
// Seção de Gráficos do Dashboard
// ---------------------------------------------------------------------------

class _DashboardChartsSection extends ConsumerStatefulWidget {
  const _DashboardChartsSection();

  @override
  ConsumerState<_DashboardChartsSection> createState() =>
      _DashboardChartsSectionState();
}

class _DashboardChartsSectionState
    extends ConsumerState<_DashboardChartsSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CasaSectionHeader(
          title: 'Visão Gráfica',
          action: 'Ver relatórios',
          onAction: () => context.push(AppRoutes.reports),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0F2444),
                        Color(0xFF1D5FA8)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card - 2),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  tabs: const [
                    Tab(text: 'Categorias'),
                    Tab(text: 'Movimentos'),
                    Tab(text: 'Urgência'),
                  ],
                ),
                SizedBox(
                  height: 240,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _CategoryPieChart(isDark: isDark),
                      _MovementsLineChart(isDark: isDark),
                      _UrgencyBarChart(isDark: isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Pie chart: distribution by category ────────────────────────────────────

class _CategoryPieChart extends ConsumerWidget {
  final bool isDark;
  const _CategoryPieChart({required this.isDark});

  static const _colors = [
    Color(0xFF1D5FA8),
    Color(0xFF059669),
    Color(0xFFDC2626),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryAsync = ref.watch(stockByCategoryProvider);
    return categoryAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const Center(
          child: Icon(Icons.bar_chart_rounded, size: 40)),
      data: (categories) {
        if (categories.isEmpty) {
          return const Center(child: Text('Sem dados'));
        }
        final total = categories.fold<int>(0, (s, c) => s + c.totalItems);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 36,
                    sections: List.generate(
                      categories.length,
                      (i) {
                        final cat = categories[i];
                        final color = _colors[i % _colors.length];
                        final pct = total > 0
                            ? (cat.totalItems / total * 100)
                                .toStringAsFixed(0)
                            : '0';
                        return PieChartSectionData(
                          color: color,
                          value: cat.totalItems.toDouble(),
                          title: '$pct%',
                          radius: 48,
                          titleStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    categories.length > 5 ? 5 : categories.length,
                    (i) {
                      final cat = categories[i];
                      final color = _colors[i % _colors.length];
                      return Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                cat.category,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Line chart: movements last 30 days ─────────────────────────────────────

class _MovementsLineChart extends ConsumerWidget {
  final bool isDark;
  const _MovementsLineChart({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final range = DateTimeRange(
      start: now.subtract(const Duration(days: 29)),
      end: now,
    );
    final movAsync = ref.watch(movementsReportProvider(range));
    return movAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const Center(
          child: Icon(Icons.show_chart_rounded, size: 40)),
      data: (movements) {
        final entriesPerDay = <int, int>{};
        final exitsPerDay = <int, int>{};
        for (final m in movements) {
          final dayKey = m.performedAt.difference(range.start).inDays;
          if (dayKey < 0 || dayKey > 29) continue;
          if (m.type.name == 'entrada') {
            entriesPerDay[dayKey] = (entriesPerDay[dayKey] ?? 0) + m.quantity;
          } else if (m.type.name == 'saida' || m.type.name == 'descarte') {
            exitsPerDay[dayKey] = (exitsPerDay[dayKey] ?? 0) + m.quantity;
          }
        }

        List<FlSpot> entrySpots = [];
        List<FlSpot> exitSpots = [];
        for (int d = 0; d <= 29; d += 5) {
          entrySpots.add(FlSpot(d.toDouble(),
              (entriesPerDay[d] ?? 0).toDouble()));
          exitSpots.add(
              FlSpot(d.toDouble(), (exitsPerDay[d] ?? 0).toDouble()));
        }
        entrySpots.add(FlSpot(29, (entriesPerDay[29] ?? 0).toDouble()));
        exitSpots.add(FlSpot(29, (exitsPerDay[29] ?? 0).toDouble()));

        final allVals = [
          ...entrySpots.map((s) => s.y),
          ...exitSpots.map((s) => s.y),
        ];
        final maxY =
            allVals.isEmpty ? 10.0 : (allVals.reduce((a, b) => a > b ? a : b) + 2);

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(
                      color: AppColors.success600, label: 'Entradas'),
                  const SizedBox(width: 16),
                  _LegendDot(color: AppColors.danger600, label: 'Saídas'),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 29,
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.3),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true, reservedSize: 28)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (val, _) {
                            final day = range.start
                                .add(Duration(days: val.toInt()));
                            if (val % 10 != 0 && val != 29) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              '${day.day}/${day.month}',
                              style: const TextStyle(fontSize: 9),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: entrySpots,
                        isCurved: true,
                        color: AppColors.success600,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color:
                              AppColors.success600.withValues(alpha: 0.08),
                        ),
                      ),
                      LineChartBarData(
                        spots: exitSpots,
                        isCurved: true,
                        color: AppColors.danger600,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color:
                              AppColors.danger600.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Bar chart: batches by urgency ──────────────────────────────────────────

class _UrgencyBarChart extends ConsumerWidget {
  final bool isDark;
  const _UrgencyBarChart({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allAvailableBatchesProvider);
    final crit7 = ref.watch(expiringBatchesProvider(7));
    final warn30 = ref.watch(expiringBatchesProvider(30));

    return allAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const Center(
          child: Icon(Icons.bar_chart_rounded, size: 40)),
      data: (all) {
        final critCount =
            crit7.maybeWhen(data: (l) => l.length, orElse: () => 0);
        final warnCount = warn30.maybeWhen(
            data: (warnList) {
              final critList = crit7.valueOrNull ?? [];
              return warnList
                  .where((b) => !critList.any((c) => c.id == b.id))
                  .length;
            },
            orElse: () => 0);
        final okCount =
            all.where((b) => b.noExpiry || b.daysToExpiry > 30).length;

        final maxY =
            [critCount, warnCount, okCount].reduce((a, b) => a > b ? a : b);
        final yMax = (maxY + 2).toDouble();

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: yMax,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: true, reservedSize: 28)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, _) {
                      const labels = ['Crítico', 'Atenção', 'OK'];
                      final i = val.toInt();
                      if (i < 0 || i >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(labels[i],
                          style: const TextStyle(fontSize: 11));
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.3),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [
                  BarChartRodData(
                    toY: critCount.toDouble(),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC53030), Color(0xFFE53E3E)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 36,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                  )
                ]),
                BarChartGroupData(x: 1, barRods: [
                  BarChartRodData(
                    toY: warnCount.toDouble(),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB7791F), Color(0xFFD69E2E)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 36,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                  )
                ]),
                BarChartGroupData(x: 2, barRods: [
                  BarChartRodData(
                    toY: okCount.toDouble(),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF276749), Color(0xFF38A169)],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 36,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                  )
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Legend dot helper ───────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
