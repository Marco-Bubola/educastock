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
import '../../../batches/presentation/controllers/batches_provider.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  Future<void> _exportExcelCsv({
    required BuildContext context,
    required List<dynamic> allBatches,
    required List<dynamic> expiring30,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('Produto,Quantidade,Validade,Dias para vencer,Origem,Status');

    final fmt = DateFormat('dd/MM/yyyy');
    for (final b in allBatches) {
      final validade = b.expiryDate != null ? fmt.format(b.expiryDate as DateTime) : 'Sem validade';
      final dias = b.expiryDate != null ? '${b.daysToExpiry}' : '-';
      final linha = [
        '"${(b.productName as String).replaceAll('"', '""')}"',
        '${b.quantity}',
        '"$validade"',
        dias,
        '"${(b.origin as String).replaceAll('"', '""')}"',
        '"${(b.status.name as String).replaceAll('"', '""')}"',
      ].join(',');
      buffer.writeln(linha);
    }

    buffer.writeln('');
    buffer.writeln('Resumo,Valor');
    buffer.writeln('Total de lotes,${allBatches.length}');
    buffer.writeln('Lotes vencendo em 30 dias,${expiring30.length}');

    final tempDir = await getTemporaryDirectory();
    final fileName = 'relatorio_educastock_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([
      XFile(file.path, mimeType: 'text/csv'),
    ], text: 'Relatório EducaStock (CSV compatível com Excel)');

    if (!context.mounted) return;
    showCasaSnackbar(
      context,
      message: 'Relatório CSV gerado e compartilhado.',
      isSuccess: true,
    );
  }

  Future<void> _exportPdf({
    required List<dynamic> allBatches,
    required List<dynamic> expiring7,
    required List<dynamic> expiring30,
  }) async {
    final doc = pw.Document();
    final generatedAt = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final totalItems = allBatches.fold<int>(0, (sum, b) => sum + (b.quantity as int));

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Relatorio EducaStock', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Gerado em: $generatedAt'),
          pw.SizedBox(height: 16),
          pw.Bullet(text: 'Lotes disponiveis: ${allBatches.length}'),
          pw.Bullet(text: 'Itens totais em estoque: $totalItems'),
          pw.Bullet(text: 'Criticos (<=7 dias): ${expiring7.length}'),
          pw.Bullet(text: 'Atencao (<=30 dias): ${expiring30.length}'),
          pw.SizedBox(height: 16),
          pw.Text('Top lotes proximos do vencimento', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Produto', 'Validade', 'Dias'],
            data: expiring30.take(15).map((b) {
              final date = b.expiryDate != null
                  ? DateFormat('dd/MM/yyyy').format(b.expiryDate as DateTime)
                  : 'Sem validade';
              return [b.productName as String, date, '${b.daysToExpiry}'];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBatches = ref.watch(allAvailableBatchesProvider);
    final expiring7 = ref.watch(expiringBatchesProvider(7));
    final expiring30 = ref.watch(expiringBatchesProvider(30));

    final allBatchesList = allBatches.valueOrNull ?? const [];
    final expiring7List = expiring7.valueOrNull ?? const [];
    final expiring30List = expiring30.valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ModernProfileAppBar(
        title: 'Relatórios',
        subtitle: 'Visão geral do estoque',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              await _exportPdf(
                allBatches: allBatchesList,
                expiring7: expiring7List,
                expiring30: expiring30List,
              );
              await ref.read(analyticsServiceProvider).logReportExport(
                    format: 'pdf',
                    reportType: 'inventory_overview',
                  );
            },
            tooltip: 'Exportar PDF',
          ),
          IconButton(
            icon: const Icon(Icons.table_view_outlined),
            onPressed: () async {
              await _exportExcelCsv(
                context: context,
                allBatches: allBatchesList,
                expiring30: expiring30List,
              );
              await ref.read(analyticsServiceProvider).logReportExport(
                    format: 'csv',
                    reportType: 'inventory_overview',
                  );
            },
            tooltip: 'Exportar Excel (CSV)',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            const CasaSectionHeader(title: 'Visão Geral do Estoque'),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.3,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  allBatches.when(
                    data: (b) => CasaInfoCard(
                      title: 'Lotes Disponíveis',
                      value: '${b.length}',
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.brandPrimary600,
                    ),
                    loading: () => const CasaCardSkeleton(),
                    error: (_, __) => const CasaInfoCard(
                        title: 'Lotes', value: '-',
                        icon: Icons.inventory_2_outlined),
                  ),
                  expiring7.when(
                    data: (b) => CasaInfoCard(
                      title: 'Críticos (≤7d)',
                      value: '${b.length}',
                      icon: Icons.warning_rounded,
                      iconColor: AppColors.danger600,
                    ),
                    loading: () => const CasaCardSkeleton(),
                    error: (_, __) => const CasaInfoCard(
                        title: 'Críticos', value: '-',
                        icon: Icons.warning_rounded,
                        iconColor: AppColors.danger600),
                  ),
                  expiring30.when(
                    data: (b) => CasaInfoCard(
                      title: 'Atenção (≤30d)',
                      value: '${b.length}',
                      icon: Icons.schedule_rounded,
                      iconColor: AppColors.warning600,
                    ),
                    loading: () => const CasaCardSkeleton(),
                    error: (_, __) => const CasaInfoCard(
                        title: 'Atenção', value: '-',
                        icon: Icons.schedule_rounded,
                        iconColor: AppColors.warning600),
                  ),
                  allBatches.when(
                    data: (b) {
                      final total = b.fold<int>(0, (sum, bt) => sum + bt.quantity);
                      return CasaInfoCard(
                        title: 'Total de Itens',
                        value: '$total',
                        icon: Icons.widgets_outlined,
                        iconColor: AppColors.secondaryBlue600,
                      );
                    },
                    loading: () => const CasaCardSkeleton(),
                    error: (_, __) => const CasaInfoCard(
                        title: 'Itens', value: '-',
                        icon: Icons.widgets_outlined),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
            const CasaSectionHeader(title: 'Próximas a Vencer'),
            const SizedBox(height: AppSpacing.sm),
            expiring30.when(
              data: (batches) {
                if (batches.isEmpty) {
                  return const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: CasaEmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Nenhum item vencendo em 30 dias',
                    ),
                  );
                }
                final fmt = DateFormat('dd/MM/yyyy');
                return Column(
                  children: batches
                      .take(10)
                      .map(
                        (b) => Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0,
                              AppSpacing.lg, AppSpacing.sm),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.productName,
                                        style: AppTypography.labelLarge
                                            .copyWith(
                                                color: AppColors.neutral900),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        b.expiryDate != null
                                            ? fmt.format(b.expiryDate!)
                                            : 'Sem validade',
                                        style: AppTypography.bodySmall
                                            .copyWith(
                                                color: AppColors.neutral500),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${b.daysToExpiry}d',
                                  style: AppTypography.numberSmall.copyWith(
                                    color: b.daysToExpiry <= 7
                                        ? AppColors.danger600
                                        : AppColors.warning600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
