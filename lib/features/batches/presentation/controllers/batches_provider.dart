import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/batches_remote_datasource.dart';
import '../../domain/entities/batch.dart';

final batchesDatasourceProvider = Provider<BatchesRemoteDatasource>(
  (_) => BatchesRemoteDatasource(),
);

final batchesByProductProvider =
    StreamProvider.family<List<Batch>, String>((ref, productId) {
  return ref
      .watch(batchesDatasourceProvider)
      .watchBatchesByProduct(productId);
});

final allAvailableBatchesProvider = StreamProvider<List<Batch>>((ref) {
  return ref.watch(batchesDatasourceProvider).watchAllAvailableBatches();
});

final expiringBatchesProvider =
    FutureProvider.family<List<Batch>, int>((ref, days) {
  return ref
      .watch(batchesDatasourceProvider)
      .getBatchesExpiringInDays(days);
});

class BatchFormNotifier extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncValue.data(null);

  Future<void> saveBatch(Batch batch, {File? imageFile}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(batchesDatasourceProvider);
      return ds.saveBatch(batch, imageFile: imageFile);
    });
  }
}

final batchFormProvider =
    NotifierProvider<BatchFormNotifier, AsyncValue<String?>>(
        () => BatchFormNotifier());

/// Conta quantos lotes ativos estão na localização indicada (pelo label).
/// Útil para validar capacidade de prateleira/nível.
final batchCountByLocationProvider =
    Provider.family<int, String>((ref, locationLabel) {
  return ref.watch(allAvailableBatchesProvider).when(
        data: (batches) =>
            batches.where((b) => b.shelfLocation == locationLabel).length,
        loading: () => 0,
        error: (_, __) => 0,
      );
});
