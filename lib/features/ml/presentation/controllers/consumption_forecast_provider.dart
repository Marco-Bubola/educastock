import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/consumption_forecast.dart';
import '../../data/repositories/consumption_forecast_firestore_repository.dart';

// ---------------------------------------------------------------------------
// Repositório (singleton)
// ---------------------------------------------------------------------------

final consumptionForecastRepositoryProvider =
    Provider<ConsumptionForecastFirestoreRepository>(
  (_) => ConsumptionForecastFirestoreRepository(),
);

// ---------------------------------------------------------------------------
// Stream de todas as previsões
// ---------------------------------------------------------------------------

/// Lista completa de previsões, ordenada por maior sugestão de reposição.
final consumptionForecastsProvider =
    StreamProvider<List<ConsumptionForecast>>((ref) {
  final repo = ref.watch(consumptionForecastRepositoryProvider);
  return repo.watchForecasts();
});

// ---------------------------------------------------------------------------
// Derivados
// ---------------------------------------------------------------------------

/// Apenas produtos que precisam de reposição (suggestedReplenishment > 0),
/// limitado aos 5 mais urgentes para o dashboard.
final topReplenishmentForecastsProvider =
    Provider<AsyncValue<List<ConsumptionForecast>>>((ref) {
  return ref.watch(consumptionForecastsProvider).whenData(
        (list) => list
            .where((f) => f.needsReplenishment)
            .take(5)
            .toList(),
      );
});

/// Previsão de um único produto por ID.
final forecastForProductProvider =
    FutureProvider.family<ConsumptionForecast?, String>((ref, productId) async {
  final repo = ref.watch(consumptionForecastRepositoryProvider);
  return repo.getForecastForProduct(productId);
});

/// Indica se existe ao menos uma previsão disponível.
final hasForecastDataProvider = Provider<bool>((ref) {
  return ref
      .watch(consumptionForecastsProvider)
      .maybeWhen(data: (list) => list.isNotEmpty, orElse: () => false);
});

/// Contagem de produtos que precisam de reposição.
final replenishmentCountProvider = Provider<int>((ref) {
  return ref.watch(consumptionForecastsProvider).maybeWhen(
        data: (list) => list.where((f) => f.needsReplenishment).length,
        orElse: () => 0,
      );
});
