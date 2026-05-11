import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../controllers/risk_classifier_provider.dart';
import '../widgets/risk_widgets.dart';
import '../../domain/entities/risk_prediction.dart';

final _keyCriticalSection = GlobalKey();
final _keyLegend = GlobalKey();

class MlInsightsPage extends ConsumerWidget {
  const MlInsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predictionsAsync = ref.watch(batchRiskPredictionsProvider);
    final countsAsync = ref.watch(riskCountsProvider);
    final criticalAsync = ref.watch(criticalBatchPredictionsProvider);
    final sourceAsync = ref.watch(classifierSourceProvider);

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: ModernProfileAppBar(
        title: 'Análise de Risco ML',
        subtitle: 'Classificação inteligente de lotes',
        showBackButton: true,
        actions: [
          buildHelpButton(
            context: context,
            onPressed: () => showCasaTutorial(
              context: context,
              steps: [
                TutorialStep(
                  key: _keyCriticalSection,
                  title: 'Análise de Risco com IA',
                  description: 'O sistema de inteligência artificial analisa os lotes do estoque e classifica o risco de vencimento de cada produto. Priorize a distribuição dos itens de maior risco.',
                  icon: Icons.psychology_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🔴 Risco Alto: distribuição urgente necessária',
                    '🟡 Risco Médio: atenção nos próximos dias',
                    '🟢 Risco Baixo: situação controlada',
                    'A IA aprende com o histórico de movimentações',
                  ],
                ),
                TutorialStep(
                  key: _keyLegend,
                  title: 'Legenda de Risco',
                  description: 'A legenda explica os critérios de classificação de risco utilizados pelo modelo de IA. Clique em cada categoria para filtrar os produtos por nível de risco.',
                  icon: Icons.legend_toggle_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'O modelo usa dias para vencer, velocidade de consumo e histórico',
                    'Atualize regularmente para manter as previsões precisas',
                    'Use junto com os Relatórios para tomada de decisão',
                  ],
                ),
              ],
            ),
          ),
          sourceAsync.maybeWhen(
            data: (src) => Tooltip(
              message: src == 'tflite'
                  ? 'Modelo TFLite on-device'
                  : 'Classificação por regras',
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Icon(
                  src == 'tflite' ? Icons.memory_rounded : Icons.rule_rounded,
                  color: src == 'tflite'
                      ? AppColors.brandPrimary600
                      : AppColors.neutral500,
                  size: 20,
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            // --- Resumo dos contadores ---
            const CasaSectionHeader(title: 'Resumo de Risco'),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: countsAsync.when(
                data: (counts) => RiskSummaryRow(counts: counts),
                loading: () => const _ThreeSkeletons(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // --- Críticos prioritários ---
            const CasaSectionHeader(title: 'Críticos (Vermelho)'),
            const SizedBox(height: AppSpacing.sm),
            criticalAsync.when(
              data: (critical) {
                if (critical.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: CasaEmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Nenhum lote crítico',
                    ),
                  );
                }
                return KeyedSubtree(
                  key: _keyCriticalSection,
                  child: _PredictionList(predictions: critical),
                );
              },
              loading: () => const _LoadingList(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: AppSpacing.xl),

            // --- Todos os lotes classificados ---
            const CasaSectionHeader(title: 'Todos os Lotes'),
            const SizedBox(height: AppSpacing.sm),
            predictionsAsync.when(
              data: (all) {
                if (all.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: CasaEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Nenhum lote disponível',
                    ),
                  );
                }
                // Ordena: vermelho → amarelo → verde
                final sorted = [...all]..sort(_sortByRisk);
                return _PredictionList(predictions: sorted);
              },
              loading: () => const _LoadingList(),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text('Erro: $e', style: AppTypography.bodySmall),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // --- Legenda ---
            KeyedSubtree(
              key: _keyLegend,
              child: const _Legend(),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
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

// ---------------------------------------------------------------------------
// Helpers de UI internos
// ---------------------------------------------------------------------------

class _PredictionList extends StatelessWidget {
  final List<RiskPrediction> predictions;
  const _PredictionList({required this.predictions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: predictions
          .take(50)
          .map(
            (p) => Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: RiskInsightCard(prediction: p),
            ),
          )
          .toList(),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (_) => const Padding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          child: CasaCardSkeleton(),
        ),
      ),
    );
  }
}

class _ThreeSkeletons extends StatelessWidget {
  const _ThreeSkeletons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (_) => const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: CasaCardSkeleton(),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como funciona a classificação',
              style: AppTypography.labelLarge
                  .copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...RiskLevel.values.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RiskBadge(level: l),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l.description,
                        style: AppTypography.bodySmall
                            .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
