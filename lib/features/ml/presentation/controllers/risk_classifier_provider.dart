import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/risk_prediction.dart';
import '../../domain/repositories/risk_classifier_repository.dart';
import '../../data/repositories/rule_based_risk_classifier.dart';
import '../../data/repositories/classifier_factory.dart';
import '../../../../features/batches/presentation/controllers/batches_provider.dart';

// ---------------------------------------------------------------------------
// Instância do classificador (singleton no ciclo de vida do app)
// ---------------------------------------------------------------------------

/// Inicializa o classificador correto via factory com conditional imports.
/// Web → RuleBasedRiskClassifier; Native → TFLite com fallback rule-based.
final riskClassifierProvider = FutureProvider<RiskClassifierRepository>((ref) async {
  return buildClassifier();
});

// ---------------------------------------------------------------------------
// Predições em batch (todos os lotes disponíveis)
// ---------------------------------------------------------------------------

/// Estado atual de todas as predições de risco.
final batchRiskPredictionsProvider =
    FutureProvider<List<RiskPrediction>>((ref) async {
  final classifierAsync = ref.watch(riskClassifierProvider);
  final allBatchesAsync = ref.watch(allAvailableBatchesProvider);

  final classifier = await classifierAsync.when(
    data: (c) async => c,
    loading: () async {
      await Future.delayed(const Duration(milliseconds: 200));
      return RuleBasedRiskClassifier() as RiskClassifierRepository;
    },
    error: (_, __) async => RuleBasedRiskClassifier() as RiskClassifierRepository,
  );

  final batches = allBatchesAsync.valueOrNull ?? const [];
  if (batches.isEmpty) return const [];

  return classifier.classifyAll(batches);
});

/// Predição de risco para um único lote por ID.
final batchRiskProvider = FutureProvider.family<RiskPrediction?, String>(
  (ref, batchId) async {
    final predictions = await ref.watch(batchRiskPredictionsProvider.future);
    try {
      return predictions.firstWhere((p) => p.batchId == batchId);
    } catch (_) {
      return null;
    }
  },
);

/// Contadores por nível de risco.
final riskCountsProvider = FutureProvider<Map<RiskLevel, int>>((ref) async {
  final predictions = await ref.watch(batchRiskPredictionsProvider.future);
  final counts = <RiskLevel, int>{
    RiskLevel.verde: 0,
    RiskLevel.amarelo: 0,
    RiskLevel.vermelho: 0,
  };
  for (final p in predictions) {
    counts[p.level] = (counts[p.level] ?? 0) + 1;
  }
  return counts;
});

/// Lotes classificados como vermelho em ordem de risco decrescente.
final criticalBatchPredictionsProvider =
    FutureProvider<List<RiskPrediction>>((ref) async {
  final predictions = await ref.watch(batchRiskPredictionsProvider.future);
  final critical = predictions
      .where((p) => p.level == RiskLevel.vermelho)
      .toList()
    ..sort((a, b) => b.confidence.compareTo(a.confidence));
  return critical;
});

/// Fonte atual do classificador ("tflite" ou "rule_based").
final classifierSourceProvider = FutureProvider<String>((ref) async {
  final predictions = await ref.watch(batchRiskPredictionsProvider.future);
  if (predictions.isEmpty) return 'rule_based';
  return predictions.first.source;
});
