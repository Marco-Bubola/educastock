import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design_system/design_system.dart';
import '../controllers/risk_classifier_provider.dart';
import '../widgets/risk_widgets.dart';
import '../../domain/entities/risk_prediction.dart';

final _keyCriticalSection = GlobalKey();
final _keyLegend = GlobalKey();
final _keyMlSource = GlobalKey();
final _keyRiskBadges = GlobalKey();

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
      body: Column(children: [
      ModernProfileAppBar(
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
                  key: _keyMlSource,
                  title: 'Origem da Classificação',
                  description: 'O ícone no canto superior direito indica como a IA está classificando os riscos: chip "TFLite" significa modelo neural treinado rodando no celular (alta precisão); chip "Regras" significa fallback heurístico baseado em regras simples (sempre disponível).',
                  icon: Icons.memory_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🧠 TFLite: modelo neural ML on-device — preferido',
                    '📏 Regras: fallback heurístico (sem ML)',
                    'O modelo TFLite é mais preciso mas precisa download',
                    'Trocar entre modos em Configurações → ML',
                  ],
                ),
                TutorialStep(
                  key: _keyRiskBadges,
                  title: 'Contadores por Nível de Risco',
                  description: 'Os 3 badges coloridos mostram quantos lotes estão em cada faixa de risco no momento. Toque em um badge para filtrar a lista abaixo apenas com lotes daquele nível. Essencial para priorizar ações do dia.',
                  icon: Icons.label_important_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    '🔴 Alto = quantos lotes em risco urgente',
                    '🟡 Médio = quantos lotes em atenção',
                    '🟢 Baixo = quantos lotes em situação normal',
                    'Soma dos 3 = total de lotes ativos analisados',
                  ],
                ),
                TutorialStep(
                  key: _keyCriticalSection,
                  title: 'Lotes Críticos da IA',
                  description: 'Lista de lotes que a IA classificou como ALTO risco — provavelmente vão vencer antes de serem distribuídos no ritmo atual de consumo. Cada card mostra produto, lote, quantidade, probabilidade de desperdício e ação recomendada.',
                  icon: Icons.psychology_rounded,
                  align: ContentAlign.bottom,
                  hints: const [
                    'Probabilidade é em % (90% = quase certeza de desperdício)',
                    'Toque no card para ver detalhes e histórico do lote',
                    'Distribua URGENTE ou registre descarte preventivo',
                    'A IA aprende com cada saída registrada',
                  ],
                ),
                TutorialStep(
                  key: _keyLegend,
                  title: 'Critérios da Classificação',
                  description: 'A legenda explica COMO a IA decide cada nível. Os critérios consideram dias até vencimento, velocidade média de consumo do produto, quantidade restante no lote e sazonalidade do histórico.',
                  icon: Icons.legend_toggle_rounded,
                  align: ContentAlign.top,
                  hints: const [
                    'Modelo treinado com seu histórico real de saídas',
                    'Quanto mais dados de movimentação, mais preciso',
                    'Combine com Previsão Prophet para visão completa',
                    'Re-treine mensalmente para manter precisão',
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
                key: _keyMlSource,
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
      Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          children: [
            // --- TFLite badge ---
            sourceAsync.maybeWhen(
              data: (src) => src == 'tflite'
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.brandPrimary600.withOpacity(0.12),
                              AppColors.secondaryBlue600.withOpacity(0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                              color: AppColors.brandPrimary600
                                  .withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.memory_rounded,
                                color: AppColors.brandPrimary600, size: 18),
                            const SizedBox(width: AppSpacing.sm),
                            Text('TFLite ativo',
                                style: AppTypography.labelMedium.copyWith(
                                    color: AppColors.brandPrimary600,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: AppSpacing.xs),
                            Text('— inferência on-device',
                                style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.brandPrimary600
                                        .withOpacity(0.7))),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success600.withOpacity(0.15),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text('On-device',
                                  style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.success600)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),

            // --- Resumo dos contadores ---
            const CasaSectionHeader(title: 'Resumo de Risco'),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: KeyedSubtree(
                key: _keyRiskBadges,
                child: countsAsync.when(
                  data: (counts) => RiskSummaryRow(counts: counts),
                  loading: () => const _ThreeSkeletons(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
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
      ]),
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
