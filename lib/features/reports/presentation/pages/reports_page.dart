import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/observability/analytics_service.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../batches/presentation/controllers/batches_provider.dart';
import '../../../batches/domain/entities/batch.dart';
import '../../../../core/router/app_router.dart';
import 'package:go_router/go_router.dart';
import '../../../ml/presentation/controllers/risk_classifier_provider.dart';
import '../../../ml/domain/entities/risk_prediction.dart';
import '../../../ml/presentation/widgets/risk_widgets.dart';

// ─── Helpers de exportação ────────────────────────────────────────────────

Future<void> _exportCsv({
  required BuildContext context,
  required List<Batch> allBatches,
  required List<Batch> expiring30,
}) async {
  final buffer = StringBuffer();
  buffer.writeln('Produto,Quantidade,Validade,Dias para vencer,Origem,Status');
  final fmt = DateFormat('dd/MM/yyyy');
  for (final b in allBatches) {
    final validade =
        b.expiryDate != null ? fmt.format(b.expiryDate!) : 'Sem validade';
    final dias = b.noExpiry ? 'Sem val.' : '${b.daysToExpiry}';
    buffer.writeln([
      '"${b.productName.replaceAll('"', '""')}"',
      '${b.quantity}',
      '"$validade"',
      dias,
      '"${b.origin.replaceAll('"', '""')}"',
    ].join(','));
  }
  buffer.writeln('');
  buffer.writeln('Total de lotes,${allBatches.length}');
  buffer.writeln('Vencendo em 30 dias,${expiring30.length}');

  final dir = await getTemporaryDirectory();
  final file = File(
      '${dir.path}/relatorio_${DateTime.now().millisecondsSinceEpoch}.csv');
  await file.writeAsString(buffer.toString());
  await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')],
      text: 'Relatório EducastStock (CSV)');
  if (!context.mounted) return;
  showCasaSnackbar(context,
      message: 'Relatório CSV gerado!', isSuccess: true);
}

Future<void> _exportPdf({
  required List<Batch> allBatches,
  required List<Batch> expiring7,
  required List<Batch> expiring30,
}) async {
  final doc = pw.Document();
  final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
  final total =
      allBatches.fold<int>(0, (s, b) => s + b.quantity);
  doc.addPage(
    pw.MultiPage(
      build: (ctx) => [
        pw.Text('Relatório EducastStock',
            style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Gerado em: $now'),
        pw.SizedBox(height: 16),
        pw.Bullet(text: 'Lotes disponíveis: ${allBatches.length}'),
        pw.Bullet(text: 'Itens em estoque: $total'),
        pw.Bullet(text: 'Críticos (≤7 dias): ${expiring7.length}'),
        pw.Bullet(text: 'Atenção (≤30 dias): ${expiring30.length}'),
        pw.SizedBox(height: 16),
        pw.Text('Próximos a vencer',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          headers: const ['Produto', 'Validade', 'Dias'],
          data: expiring30.take(15).map((b) {
            final date = b.expiryDate != null
                ? DateFormat('dd/MM/yyyy').format(b.expiryDate!)
                : '-';
            return [b.productName, date, b.noExpiry ? 'Sem val.' : '${b.daysToExpiry}'];
          }).toList(),
        ),
      ],
    ),
  );
  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

// ─── Página principal ─────────────────────────────────────────────────────

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final allBatchesAsync = ref.watch(allAvailableBatchesProvider);
    final expiring7 = ref.watch(expiringBatchesProvider(7));
    final expiring30 = ref.watch(expiringBatchesProvider(30));
    final riskCountsAsync = ref.watch(riskCountsProvider);
    final riskPredictionsAsync = ref.watch(batchRiskPredictionsProvider);
    final classifierSourceAsync = ref.watch(classifierSourceProvider);

    final allList = allBatchesAsync.valueOrNull ?? [];
    final exp7List = expiring7.valueOrNull ?? [];
    final exp30List = expiring30.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ModernProfileAppBar(
        title: 'Relatórios',
        subtitle: 'Análise e tendências do estoque',
        profileName: user?.name,
        onProfileTap: () => context.push(AppRoutes.settings),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar PDF',
            onPressed: () async {
              await _exportPdf(
                  allBatches: allList,
                  expiring7: exp7List,
                  expiring30: exp30List);
              await ref.read(analyticsServiceProvider).logReportExport(
                  format: 'pdf', reportType: 'inventory_overview');
            },
          ),
          IconButton(
            icon: const Icon(Icons.table_view_outlined),
            tooltip: 'Exportar CSV',
            onPressed: () async {
              await _exportCsv(
                  context: context,
                  allBatches: allList,
                  expiring30: exp30List);
              await ref.read(analyticsServiceProvider).logReportExport(
                  format: 'csv', reportType: 'inventory_overview');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: allBatchesAsync.when(
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: 6,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: CasaCardSkeleton(),
            ),
          ),
          error: (e, _) => CasaEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Erro ao carregar',
            description: e.toString(),
          ),
          data: (batches) {
            final totalItems =
                batches.fold<int>(0, (s, b) => s + b.quantity);
            final totalValue = batches.fold<double>(
                0, (s, b) => s + (b.unitPrice ?? 0) * b.quantity);
            final expired = batches.where((b) => b.isExpired).length;

            final Map<String, int> catCount = {};
            for (final b in batches) {
              catCount[b.productName] = (catCount[b.productName] ?? 0) + b.quantity;
            }
            final topProducts = (catCount.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(5)
                .toList();

            final Map<String, int> originCount = {};
            for (final b in batches) {
              originCount[b.origin] = (originCount[b.origin] ?? 0) + 1;
            }
            const originLabels = {
              'doacao': 'Doação',
              'compra': 'Compra',
              'parceiro': 'Parceiro',
              'transferencia': 'Transferência',
            };

            final Map<String, int> monthTrend = {};
            final now = DateTime.now();
            for (int i = 5; i >= 0; i--) {
              final d = DateTime(now.year, now.month - i);
              final key =
                  '${d.month.toString().padLeft(2, '0')}/${d.year % 100}';
              monthTrend[key] = 0;
            }
            for (final b in batches) {
              final key =
                  '${b.entryDate.month.toString().padLeft(2, '0')}/${b.entryDate.year % 100}';
              if (monthTrend.containsKey(key)) {
                monthTrend[key] = monthTrend[key]! + b.quantity;
              }
            }

            final healthScore = (100 -
                    (expired * 10) -
                    (exp7List.length * 5) -
                    (exp30List.length - exp7List.length) * 2)
                .clamp(0, 100);

            final Map<String, int> expiryBuckets = {
              'Vencido': 0,
              '0–7d': 0,
              '8–30d': 0,
              '31–90d': 0,
              '>90d': 0,
              'Sem val.': 0,
            };
            for (final b in batches) {
              final d = b.daysToExpiry;
              if (b.noExpiry) {
                expiryBuckets['Sem val.'] = expiryBuckets['Sem val.']! + 1;
              } else if (b.isExpired) {
                expiryBuckets['Vencido'] = expiryBuckets['Vencido']! + 1;
              } else if (d <= 7) {
                expiryBuckets['0–7d'] = expiryBuckets['0–7d']! + 1;
              } else if (d <= 30) {
                expiryBuckets['8–30d'] = expiryBuckets['8–30d']! + 1;
              } else if (d <= 90) {
                expiryBuckets['31–90d'] = expiryBuckets['31–90d']! + 1;
              } else {
                expiryBuckets['>90d'] = expiryBuckets['>90d']! + 1;
              }
            }

            final insights = _buildInsights(
              batches: batches,
              exp7: exp7List.length,
              exp30: exp30List.length,
              expired: expired,
              totalItems: totalItems,
            );

            final predictions = riskPredictionsAsync.valueOrNull ?? [];
            final sortedPredictions = [...predictions]..sort(_sortByRisk);
            final classifierSrc = classifierSourceAsync.valueOrNull ?? 'rule_based';

            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                  AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              children: [
                // ─── Cards de resumo
                _SummaryGrid(
                  totalBatches: batches.length,
                  totalItems: totalItems,
                  totalValue: totalValue,
                  expired: expired,
                  criticals: exp7List.length,
                  warnings: exp30List.length,
                  healthScore: healthScore,
                  isDark: isDark,
                  cs: cs,
                ),
                const SizedBox(height: AppSpacing.xl),

                // ─── Tendência mensal de entradas
                _SectionHeader(
                  title: 'Entradas Mensais',
                  subtitle: 'Últimos 6 meses',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.brandPrimary600,
                ),
                const SizedBox(height: AppSpacing.sm),
                _MonthlyTrendChart(
                    monthTrend: monthTrend, isDark: isDark, cs: cs),
                const _ChartNote(
                  text: 'Soma total de itens cadastrados em cada mês. Toque nos pontos para ver o valor exato.',
                ),
                const SizedBox(height: AppSpacing.xl),

                // ─── Gráfico de barras: Validade
                _SectionHeader(
                  title: 'Distribuição por Prazo de Validade',
                  subtitle: 'Quantos lotes estão em cada faixa de vencimento',
                  icon: Icons.schedule_rounded,
                  color: AppColors.warning600,
                ),
                const SizedBox(height: AppSpacing.sm),
                _ExpiryBarChart(
                    buckets: expiryBuckets, isDark: isDark, cs: cs),
                const _ChartNote(
                  text: 'Vermelho = vencidos ou críticos (≤7d). Laranja = atenção (8–30d). Verde = seguros (>30d). Sem val. = itens sem data de vencimento.',
                ),
                const SizedBox(height: AppSpacing.xl),

                // ─── Gráfico de pizza: Origem
                if (originCount.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Lotes por Origem',
                    subtitle: 'Proporção de cada fonte no estoque atual',
                    icon: Icons.pie_chart_rounded,
                    color: AppColors.secondaryBlue600,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _CategoryPieChart(
                    catCount: originCount,
                    labelMap: originLabels,
                    isDark: isDark,
                    cs: cs,
                  ),
                  const _ChartNote(
                    text: 'Toque em cada fatia para ver o percentual. Ajuda a entender quais são as principais fontes de entrada no estoque.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ─── Top 5 produtos por quantidade
                if (topProducts.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Top 5 Produtos em Estoque',
                    subtitle: 'Produtos com maior quantidade disponível',
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.success600,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _TopProductsChart(
                    products: topProducts,
                    totalItems: totalItems,
                    isDark: isDark,
                    cs: cs,
                  ),
                  const _ChartNote(
                    text: 'A barra mostra a proporção de cada produto em relação ao total de itens em estoque.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ─── Análise de Risco ML
                _SectionHeader(
                  title: 'Análise de Risco ML',
                  subtitle: classifierSrc == 'tflite'
                      ? 'Modelo TFLite on-device ativo'
                      : 'Classificação por regras inteligentes',
                  icon: classifierSrc == 'tflite'
                      ? Icons.memory_rounded
                      : Icons.rule_rounded,
                  color: AppColors.brandPrimary600,
                  badge: classifierSrc == 'tflite' ? 'TFLite' : 'Rules',
                ),
                const SizedBox(height: AppSpacing.sm),

                // Resumo de contadores ML
                riskCountsAsync.when(
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
                const SizedBox(height: AppSpacing.md),

                // Gráfico de donut + lista compacta de críticos
                riskPredictionsAsync.when(
                  data: (_) {
                    if (sortedPredictions.isEmpty) {
                      return const CasaEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Nenhum lote para classificar',
                      );
                    }
                    final criticals = sortedPredictions
                        .where((p) => p.level == RiskLevel.vermelho)
                        .toList();
                    final amarelos = sortedPredictions
                        .where((p) => p.level == RiskLevel.amarelo)
                        .toList();
                    final verdes = sortedPredictions
                        .where((p) => p.level == RiskLevel.verde)
                        .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Donut chart: distribuição de risco
                        _MlRiskDonutChart(
                          verdeCount: verdes.length,
                          amareloCount: amarelos.length,
                          vermelhoCount: criticals.length,
                          cs: cs,
                          isDark: isDark,
                        ),
                        const _ChartNote(
                          text: 'Visão geral da saúde do estoque por IA. Toque nas fatias para ver os percentuais de cada nível de risco.',
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Lotes críticos — top 5 apenas
                        if (criticals.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_rounded,
                                    size: 14, color: AppColors.danger600),
                                const SizedBox(width: 4),
                                Text(
                                  'Lotes Críticos (${criticals.length})',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.danger600,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                if (criticals.length > 5)
                                  Text(
                                    'exibindo os 5 mais urgentes',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          ...criticals.take(5).map((p) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs),
                                child: RiskInsightCard(prediction: p),
                              )),
                          if (criticals.length > 5)
                            Padding(
                              padding: const EdgeInsets.only(
                                  top: 2, bottom: AppSpacing.xs),
                              child: Center(
                                child: Text(
                                  '+ ${criticals.length - 5} lotes críticos adicionais',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.danger600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: AppSpacing.sm),
                        ],

                        // Resumo compacto dos demais lotes
                        if (amarelos.isNotEmpty || verdes.isNotEmpty)
                          _MlNonCriticalSummary(
                            amareloCount: amarelos.length,
                            verdeCount: verdes.length,
                            cs: cs,
                          ),
                      ],
                    );
                  },
                  loading: () => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      3,
                      (_) => const Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.xs),
                        child: CasaCardSkeleton(),
                      ),
                    ),
                  ),
                  error: (e, _) => Text('Erro ML: $e',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.danger600)),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Legenda ML
                _MlLegend(isDark: isDark, cs: cs),
                const SizedBox(height: AppSpacing.xl),

                // ─── Insights inteligentes
                _SectionHeader(
                  title: 'Insights do Estoque',
                  subtitle: 'Alertas e recomendações automáticas',
                  icon: Icons.lightbulb_rounded,
                  color: AppColors.warning600,
                ),
                const SizedBox(height: AppSpacing.sm),
                _InsightsPanel(insights: insights),
                const SizedBox(height: AppSpacing.xl),

                // ─── Tabela de próximos a vencer
                _SectionHeader(
                  title: 'Próximos a Vencer',
                  subtitle: 'Lotes vencendo nos próximos 30 dias',
                  icon: Icons.access_time_rounded,
                  color: AppColors.danger600,
                  count: exp30List.length,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (exp30List.isEmpty)
                  const CasaEmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Nenhum item vencendo em 30 dias',
                  )
                else
                  _ExpiryList(batches: exp30List, cs: cs, isDark: isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  int _sortByRisk(RiskPrediction a, RiskPrediction b) {
    const order = {
      RiskLevel.vermelho: 0,
      RiskLevel.amarelo: 1,
      RiskLevel.verde: 2,
    };
    final cmp = order[a.level]!.compareTo(order[b.level]!);
    if (cmp != 0) return cmp;
    return b.confidence.compareTo(a.confidence);
  }
}

// ─── Section Header moderno ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final String? badge;
  final int? count;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.badge,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.small),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: AppTypography.headingSmall.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (count != null && count! > 0) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  if (badge != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: color.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                            color: color,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppTypography.bodySmall
                      .copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Nota informativa de gráfico ─────────────────────────────────────────

class _ChartNote extends StatelessWidget {
  final String text;
  const _ChartNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top Produtos chart ───────────────────────────────────────────────────

class _TopProductsChart extends StatelessWidget {
  final List<MapEntry<String, int>> products;
  final int totalItems;
  final bool isDark;
  final ColorScheme cs;
  const _TopProductsChart(
      {required this.products,
      required this.totalItems,
      required this.isDark,
      required this.cs});

  static const _colors = [
    AppColors.brandPrimary600,
    AppColors.secondaryBlue600,
    AppColors.success600,
    AppColors.warning600,
    Color(0xFF7C3AED),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...products.asMap().entries.map((e) {
            final color = _colors[e.key % _colors.length];
            final pct = totalItems == 0
                ? 0.0
                : e.value.value / totalItems;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.value.key,
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${e.value.value} un.',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: AppTypography.labelSmall.copyWith(
                            color: cs.onSurfaceVariant, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor:
                          cs.outlineVariant.withValues(alpha: 0.25),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
          Divider(height: 12, color: cs.outlineVariant.withValues(alpha: 0.3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Total em estoque: ',
                style: AppTypography.bodySmall
                    .copyWith(color: cs.onSurfaceVariant, fontSize: 10),
              ),
              Text(
                '$totalItems unidades',
                style: AppTypography.labelSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Gráfico de Donut: Risco ML ───────────────────────────────────────────

class _MlRiskDonutChart extends StatefulWidget {
  final int verdeCount;
  final int amareloCount;
  final int vermelhoCount;
  final ColorScheme cs;
  final bool isDark;

  const _MlRiskDonutChart({
    required this.verdeCount,
    required this.amareloCount,
    required this.vermelhoCount,
    required this.cs,
    required this.isDark,
  });

  @override
  State<_MlRiskDonutChart> createState() => _MlRiskDonutChartState();
}

class _MlRiskDonutChartState extends State<_MlRiskDonutChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final total =
        widget.verdeCount + widget.amareloCount + widget.vermelhoCount;

    if (total == 0) return const SizedBox.shrink();

    final items = [
      (widget.vermelhoCount, AppColors.danger600, 'Crítico',
          Icons.warning_rounded),
      (widget.amareloCount, AppColors.warning600, 'Atenção',
          Icons.schedule_rounded),
      (widget.verdeCount, AppColors.success600, 'Seguro',
          Icons.check_circle_rounded),
    ];

    final sections = items.asMap().entries.map((e) {
      final isTouched = e.key == _touched;
      final count = e.value.$1;
      final color = e.value.$2;
      final pct = total == 0 ? 0.0 : count / total * 100;
      return PieChartSectionData(
        color: color,
        value: count == 0 ? 0.001 : count.toDouble(),
        title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
        radius: isTouched ? 56 : 46,
        titleStyle: const TextStyle(
            fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800),
        borderSide: isTouched
            ? BorderSide(
                color: Colors.white.withValues(alpha: 0.5), width: 2)
            : BorderSide.none,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (ev, resp) {
                        setState(() {
                          if (!ev.isInterestedForInteractions ||
                              resp == null ||
                              resp.touchedSection == null) {
                            _touched = -1;
                            return;
                          }
                          _touched =
                              resp.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                  ),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      'lotes',
                      style: TextStyle(
                        fontSize: 9,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                final pct =
                    total == 0 ? 0.0 : item.$1 / total * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(item.$4, size: 14, color: item.$2),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.$3,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '${item.$1}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: item.$2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${pct.toStringAsFixed(0)}%)',
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor:
                              cs.outlineVariant.withValues(alpha: 0.25),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(item.$2),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Resumo compacto dos lotes não-críticos ───────────────────────────────

class _MlNonCriticalSummary extends StatelessWidget {
  final int amareloCount;
  final int verdeCount;
  final ColorScheme cs;

  const _MlNonCriticalSummary({
    required this.amareloCount,
    required this.verdeCount,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.summarize_outlined,
              size: 14, color: AppColors.secondaryBlue600),
          const SizedBox(width: 8),
          Text(
            'Demais lotes: ',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
          if (amareloCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.warning600.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: AppColors.warning600.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 11, color: AppColors.warning600),
                  const SizedBox(width: 3),
                  Text(
                    '$amareloCount em atenção',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (verdeCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success600.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                    color: AppColors.success600.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 11, color: AppColors.success600),
                  const SizedBox(width: 3),
                  Text(
                    '$verdeCount seguros',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success600,
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

// ─── Legenda ML ───────────────────────────────────────────────────────────

class _MlLegend extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  const _MlLegend({required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.check_circle_rounded, AppColors.success600, 'Seguro',
          'Lote em condições normais.'),
      (Icons.schedule_rounded, AppColors.warning600, 'Atenção',
          'Vencimento se aproximando ou estoque baixo.'),
      (Icons.warning_rounded, AppColors.danger600, 'Crítico',
          'Risco iminente de perda. Priorize a distribuição.'),
    ];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Como funciona a classificação',
              style: AppTypography.labelSmall.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(item.$1, color: item.$2, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      item.$3,
                      style: TextStyle(
                          fontSize: 11,
                          color: item.$2,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.$4,
                        style: AppTypography.bodySmall.copyWith(
                            fontSize: 11,
                            color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Grid de resumo ───────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final int totalBatches;
  final int totalItems;
  final double totalValue;
  final int expired;
  final int criticals;
  final int warnings;
  final int healthScore;
  final bool isDark;
  final ColorScheme cs;
  const _SummaryGrid(
      {required this.totalBatches,
      required this.totalItems,
      required this.totalValue,
      required this.expired,
      required this.criticals,
      required this.warnings,
      required this.healthScore,
      required this.isDark,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(
        locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
    final healthColor = healthScore >= 80
        ? AppColors.success600
        : healthScore >= 50
            ? AppColors.warning600
            : AppColors.danger600;
    final cards = [
      _SummaryDef('Lotes', '$totalBatches', Icons.layers_rounded,
          AppColors.brandPrimary600),
      _SummaryDef('Itens', '$totalItems', Icons.widgets_outlined,
          AppColors.secondaryBlue600),
      _SummaryDef('Valor est.', currFmt.format(totalValue),
          Icons.attach_money_rounded, AppColors.success600),
      _SummaryDef('Saúde', '$healthScore%',
          Icons.favorite_rounded, healthColor),
      _SummaryDef('Críticos', '$criticals', Icons.warning_rounded,
          criticals > 0 ? AppColors.danger600 : AppColors.success600),
      _SummaryDef('Vencidos', '$expired', Icons.cancel_outlined,
          expired > 0 ? AppColors.danger600 : AppColors.success600),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.4,
      children: cards.map((d) => _SummaryCard(def: d, cs: cs)).toList(),
    );
  }
}

class _SummaryDef {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _SummaryDef(this.label, this.value, this.icon, this.color);
}

class _SummaryCard extends StatelessWidget {
  final _SummaryDef def;
  final ColorScheme cs;
  const _SummaryCard({required this.def, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: def.color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(def.icon, size: 14, color: def.color),
            const SizedBox(width: 4),
            Text(def.label,
                style: AppTypography.labelSmall.copyWith(
                    color: cs.onSurfaceVariant, fontSize: 10)),
          ]),
          const SizedBox(height: 4),
          Text(
            def.value,
            style: AppTypography.headingSmall.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Gráfico de linha: tendência mensal ──────────────────────────────────

class _MonthlyTrendChart extends StatelessWidget {
  final Map<String, int> monthTrend;
  final bool isDark;
  final ColorScheme cs;
  const _MonthlyTrendChart(
      {required this.monthTrend, required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) {
    final keys = monthTrend.keys.toList();
    final values = keys.map((k) => monthTrend[k]!.toDouble()).toList();
    final maxVal = values.fold(0.0, math.max);

    if (maxVal == 0) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
        child: Center(
          child: Text('Sem entradas nos últimos 6 meses',
              style: AppTypography.bodySmall
                  .copyWith(color: cs.onSurfaceVariant)),
        ),
      );
    }

    final spots = values.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      height: 210,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxVal * 1.3,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: math.max(1, maxVal / 4),
            getDrawingHorizontalLine: (v) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.25),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= keys.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      keys[idx],
                      style: TextStyle(
                          fontSize: 9,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) {
                  if (v == 0) return const SizedBox.shrink();
                  return Text(
                    v.toInt().toString(),
                    style: TextStyle(
                        fontSize: 9, color: cs.onSurfaceVariant),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => cs.surfaceContainer,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toInt()} un.',
                        TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 11),
                      ))
                  .toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.4,
              gradient: const LinearGradient(
                colors: [
                  AppColors.brandPrimary600,
                  AppColors.secondaryBlue600,
                ],
              ),
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s, pct, bar, idx) =>
                    FlDotCirclePainter(
                  radius: 4.5,
                  color: AppColors.brandPrimary600,
                  strokeColor: cs.surface,
                  strokeWidth: 2,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.brandPrimary600.withValues(alpha: 0.28),
                    AppColors.secondaryBlue600.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      ),
    );
  }
}

// ─── Gráfico de barras: validade ─────────────────────────────────────────

class _ExpiryBarChart extends StatelessWidget {
  final Map<String, int> buckets;
  final bool isDark;
  final ColorScheme cs;
  const _ExpiryBarChart(
      {required this.buckets, required this.isDark, required this.cs});

  Color _bucketColor(String key) {
    switch (key) {
      case 'Vencido':
        return AppColors.danger600;
      case '0–7d':
        return AppColors.danger600.withValues(alpha: 0.7);
      case '8–30d':
        return AppColors.warning600;
      case '31–90d':
        return AppColors.success600.withValues(alpha: 0.7);
      case '>90d':
        return AppColors.success600;
      default:
        return AppColors.brandPrimary600.withValues(alpha: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = buckets.keys.toList();
    final maxVal =
        buckets.values.fold(0, (a, b) => math.max(a, b)).toDouble();
    if (maxVal == 0) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('Sem dados')),
      );
    }

    final barGroups = keys.asMap().entries.map((e) {
      final barColor = _bucketColor(e.value);
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: buckets[e.value]!.toDouble(),
            gradient: LinearGradient(
              colors: [barColor, barColor.withValues(alpha: 0.7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            width: 24,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxVal * 1.3,
              color: cs.surfaceContainer,
            ),
          ),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      height: 230,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: BarChart(
        BarChartData(
          barGroups: barGroups,
          maxY: maxVal * 1.3,
          gridData: FlGridData(
            show: true,
            horizontalInterval: maxVal == 0 ? 1 : maxVal / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.25),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
            drawVerticalLine: false,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) {
                  final key = keys[v.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      key,
                      style: TextStyle(
                          fontSize: 9,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600),
                    ),
                  );
                },
                reservedSize: 28,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  if (v == 0) return const SizedBox.shrink();
                  return Text(
                    v.toInt().toString(),
                    style: TextStyle(
                        fontSize: 9, color: cs.onSurfaceVariant),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => cs.surfaceContainer,
              getTooltipItem: (group, gI, rod, rI) {
                return BarTooltipItem(
                  '${rod.toY.toInt()} lote${rod.toY.toInt() != 1 ? 's' : ''}',
                  TextStyle(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 11),
                );
              },
            ),
          ),
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      ),
    );
  }
}

// ─── Gráfico de pizza: categorias ────────────────────────────────────────

class _CategoryPieChart extends StatefulWidget {
  final Map<String, int> catCount;
  final Map<String, String> labelMap;
  final bool isDark;
  final ColorScheme cs;
  const _CategoryPieChart(
      {required this.catCount,
      required this.labelMap,
      required this.isDark,
      required this.cs});

  @override
  State<_CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<_CategoryPieChart> {
  int _touched = -1;

  static const _pieColors = [
    AppColors.brandPrimary600,
    AppColors.secondaryBlue600,
    AppColors.success600,
    AppColors.warning600,
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    AppColors.danger600,
    Color(0xFFDB2777),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final entries = widget.catCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0, (s, e) => s + e.value);

    final sections = entries.asMap().entries.map((e) {
      final isTouched = e.key == _touched;
      final color = _pieColors[e.key % _pieColors.length];
      final pct = total == 0 ? 0.0 : e.value.value / total * 100;
      return PieChartSectionData(
        color: color,
        value: e.value.value.toDouble(),
        title: isTouched ? '${pct.toStringAsFixed(0)}%' : '',
        radius: isTouched ? 72 : 60,
        titleStyle: const TextStyle(
            fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800),
        borderSide: isTouched
            ? BorderSide(
                color: Colors.white.withValues(alpha: 0.5), width: 2)
            : BorderSide.none,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 30,
                sectionsSpace: 2,
                pieTouchData: PieTouchData(
                  touchCallback: (ev, resp) {
                    setState(() {
                      if (!ev.isInterestedForInteractions ||
                          resp == null ||
                          resp.touchedSection == null) {
                        _touched = -1;
                        return;
                      }
                      _touched =
                          resp.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.asMap().entries.map((e) {
                final color = _pieColors[e.key % _pieColors.length];
                final label = widget.labelMap[e.value.key] ?? e.value.key;
                final pct = total == 0
                    ? 0.0
                    : e.value.value / total * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${e.value.value}',
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Insights automáticos ─────────────────────────────────────────────────

class _InsightDef {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  const _InsightDef(this.icon, this.title, this.description, this.color);
}

List<_InsightDef> _buildInsights({
  required List<Batch> batches,
  required int exp7,
  required int exp30,
  required int expired,
  required int totalItems,
}) {
  final insights = <_InsightDef>[];

  if (expired > 0) {
    insights.add(_InsightDef(
      Icons.cancel_outlined,
      'Lotes vencidos detectados',
      'Há $expired lote${expired > 1 ? 's' : ''} com validade ultrapassada. Faça a baixa imediatamente.',
      AppColors.danger600,
    ));
  }
  if (exp7 > 0) {
    insights.add(_InsightDef(
      Icons.warning_rounded,
      'Ação urgente necessária',
      '$exp7 lote${exp7 > 1 ? 's' : ''} vence${exp7 == 1 ? '' : 'm'} em até 7 dias. Priorize o uso ou descarte.',
      AppColors.danger600,
    ));
  }
  if (exp30 > exp7 + expired) {
    insights.add(_InsightDef(
      Icons.schedule_rounded,
      'Planejar consumo em breve',
      '${exp30 - exp7 - expired} lotes vencem entre 8 e 30 dias. Programe distribuição com antecedência.',
      AppColors.warning600,
    ));
  }

  if (batches.isNotEmpty) {
    final Map<String, int> prodQty = {};
    for (final b in batches) {
      prodQty[b.productName] = (prodQty[b.productName] ?? 0) + b.quantity;
    }
    final sorted = prodQty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isNotEmpty && totalItems > 0) {
      final topPct = sorted.first.value / totalItems * 100;
      if (topPct > 50) {
        insights.add(_InsightDef(
          Icons.pie_chart_outline_rounded,
          'Estoque concentrado',
          '${sorted.first.key} representa ${topPct.toStringAsFixed(0)}% do estoque total. Diversifique.',
          AppColors.secondaryBlue600,
        ));
      }
    }
  }

  if (insights.isEmpty) {
    insights.add(const _InsightDef(
      Icons.check_circle_outline_rounded,
      'Estoque saudável',
      'Nenhuma anomalia detectada. Continue monitorando as validades regularmente.',
      AppColors.success600,
    ));
  }

  return insights;
}

class _InsightsPanel extends StatelessWidget {
  final List<_InsightDef> insights;
  const _InsightsPanel({required this.insights});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: insights.map((insight) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          insight.color,
                          insight.color.withValues(alpha: 0.5)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: insight.color.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.small),
                          ),
                          child: Icon(insight.icon,
                              color: insight.color, size: 20),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                insight.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                insight.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
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
      }).toList(),
    );
  }
}

// ─── Lista de próximos a vencer (agrupada por urgência) ───────────────────

class _ExpiryList extends StatelessWidget {
  final List<Batch> batches;
  final ColorScheme cs;
  final bool isDark;
  const _ExpiryList(
      {required this.batches, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final critical =
        batches.where((b) => !b.noExpiry && b.daysToExpiry <= 7).toList();
    final warning =
        batches.where((b) => b.noExpiry || b.daysToExpiry > 7).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (critical.isNotEmpty) ...[
          _ExpiryGroupHeader(
            label: 'Crítico — vence em até 7 dias',
            color: AppColors.danger600,
            count: critical.length,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ExpirySection(batches: critical, cs: cs),
          const SizedBox(height: AppSpacing.md),
        ],
        if (warning.isNotEmpty) ...[
          _ExpiryGroupHeader(
            label: 'Atenção — vence entre 8 e 30 dias',
            color: AppColors.warning600,
            count: warning.length,
          ),
          const SizedBox(height: AppSpacing.xs),
          _ExpirySection(batches: warning, cs: cs),
        ],
      ],
    );
  }
}

class _ExpiryGroupHeader extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  const _ExpiryGroupHeader(
      {required this.label, required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpirySection extends StatelessWidget {
  final List<Batch> batches;
  final ColorScheme cs;
  const _ExpirySection({required this.batches, required this.cs});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: batches.take(15).toList().asMap().entries.map((e) {
          final b = e.value;
          final days = b.noExpiry ? 9999 : b.daysToExpiry;
          final urgentColor =
              days <= 7 ? AppColors.danger600 : AppColors.warning600;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (e.key > 0)
                Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                    indent: AppSpacing.md,
                    endIndent: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: urgentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            b.productName,
                            style: AppTypography.labelMedium
                                .copyWith(color: cs.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                b.expiryDate != null
                                    ? fmt.format(b.expiryDate!)
                                    : '-',
                                style: AppTypography.bodySmall.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 11),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text('• ${b.quantity} un.',
                                  style: AppTypography.bodySmall.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: urgentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        b.noExpiry ? 'Sem val.' : '${days}d',
                        style: TextStyle(
                          fontSize: 12,
                          color: urgentColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
