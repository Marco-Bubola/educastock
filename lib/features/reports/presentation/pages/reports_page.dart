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
            final expired =
                batches.where((b) => b.isExpired).length;

            // Distribuição por origem (doacao, compra, parceiro, transferencia)
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

            // Distribuição por validade (buckets: vencido, 0-7, 8-30, 31-90, >90, sem val)
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

            // Insights automáticos
            final insights = _buildInsights(
              batches: batches,
              exp7: exp7List.length,
              exp30: exp30List.length,
              expired: expired,
              totalItems: totalItems,
            );

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
                  isDark: isDark,
                  cs: cs,
                ),
                const SizedBox(height: AppSpacing.xl),

                // ─── Gráfico de barras: Validade
                CasaSectionHeader(title: 'Distribuição por Prazo'),
                const SizedBox(height: AppSpacing.sm),
                _ExpiryBarChart(
                    buckets: expiryBuckets, isDark: isDark, cs: cs),
                const SizedBox(height: AppSpacing.xl),

                // ─── Gráfico de pizza: Origem
                if (originCount.isNotEmpty) ...[
                  CasaSectionHeader(title: 'Lotes por Origem'),
                  const SizedBox(height: AppSpacing.sm),
                  _CategoryPieChart(
                    catCount: originCount,
                    labelMap: originLabels,
                    isDark: isDark,
                    cs: cs,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ─── Insights inteligentes
                if (insights.isNotEmpty) ...[
                  CasaSectionHeader(title: 'Insights do Estoque'),
                  const SizedBox(height: AppSpacing.sm),
                  _InsightsPanel(
                      insights: insights, isDark: isDark, cs: cs),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // ─── Lista de próximos a vencer
                CasaSectionHeader(
                    title: 'Próximos a Vencer',
                    count: exp30List.length),
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
}

// ─── Grid de resumo ───────────────────────────────────────────────────────

class _SummaryGrid extends StatelessWidget {
  final int totalBatches;
  final int totalItems;
  final double totalValue;
  final int expired;
  final int criticals;
  final int warnings;
  final bool isDark;
  final ColorScheme cs;
  const _SummaryGrid(
      {required this.totalBatches,
      required this.totalItems,
      required this.totalValue,
      required this.expired,
      required this.criticals,
      required this.warnings,
      required this.isDark,
      required this.cs});

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat.currency(
        locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0);
    final cards = [
      _SummaryDef('Lotes', '$totalBatches', Icons.layers_rounded,
          AppColors.brandPrimary600),
      _SummaryDef('Itens', '$totalItems', Icons.widgets_outlined,
          AppColors.secondaryBlue600),
      _SummaryDef('Valor est.', currFmt.format(totalValue),
          Icons.attach_money_rounded, AppColors.success600),
      _SummaryDef('Vencidos', '$expired', Icons.cancel_outlined,
          expired > 0 ? AppColors.danger600 : AppColors.success600),
      _SummaryDef('Críticos', '$criticals', Icons.warning_rounded,
          criticals > 0 ? AppColors.danger600 : AppColors.success600),
      _SummaryDef('Atenção', '$warnings', Icons.schedule_rounded,
          warnings > 0 ? AppColors.warning600 : AppColors.success600),
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
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: buckets[e.value]!.toDouble(),
            color: _bucketColor(e.value),
            width: 22,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxVal * 1.2,
              color: cs.surfaceContainer,
            ),
          ),
        ],
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      height: 200,
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
          maxY: maxVal * 1.2,
          gridData: FlGridData(
            show: true,
            horizontalInterval: maxVal == 0 ? 1 : maxVal / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.3),
              strokeWidth: 1,
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
        duration: const Duration(milliseconds: 500),
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

  // Concentração de estoque
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
  final bool isDark;
  final ColorScheme cs;
  const _InsightsPanel(
      {required this.insights, required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: insights.map((insight) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border(
              left: BorderSide(color: insight.color, width: 3),
              top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.35)),
              right: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.35)),
              bottom: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.35)),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: insight.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child:
                    Icon(insight.icon, color: insight.color, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: AppTypography.labelLarge.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      insight.description,
                      style: AppTypography.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Lista de próximos a vencer ───────────────────────────────────────────

class _ExpiryList extends StatelessWidget {
  final List<Batch> batches;
  final ColorScheme cs;
  final bool isDark;
  const _ExpiryList(
      {required this.batches, required this.cs, required this.isDark});

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
        children: batches.take(15).toList().asMap().entries.map((e) {
          final b = e.value;
          final days = b.noExpiry ? 9999 : b.daysToExpiry;
          final urgentColor =
              days <= 7 ? AppColors.danger600 : AppColors.warning600;
          return Column(
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
                        '${days}d',
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
