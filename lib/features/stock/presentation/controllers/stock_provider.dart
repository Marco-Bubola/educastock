import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_movement.dart';
import '../../data/datasources/stock_remote_datasource.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';

final stockDatasourceProvider = Provider<StockRemoteDatasource>((ref) {
  return StockRemoteDatasource();
});

final stockMovementsProvider = StreamProvider<List<StockMovement>>((ref) {
  return ref.watch(stockDatasourceProvider).watchMovements();
});

final movementsByProductProvider =
    StreamProvider.family<List<StockMovement>, String>((ref, productId) {
  return ref.watch(stockDatasourceProvider).watchMovementsByProduct(productId);
});

class StockNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> registerMovement({
    required String productId,
    required String productName,
    required String batchId,
    required MovementType type,
    required int quantity,
    required int previousQuantity,
    String? reason,
    String? activity,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user == null) throw Exception('Usuario nao autenticado');
    final ds = ref.read(stockDatasourceProvider);
    final newQuantity = type == MovementType.entrada || type == MovementType.ajustePositivo
        ? previousQuantity + quantity
        : previousQuantity - quantity;
    final movement = StockMovement(
      id: '',
      productId: productId,
      productName: productName,
      batchId: batchId,
      type: type,
      quantity: quantity,
      reason: reason,
      activity: activity,
      performedBy: user.id,
      performedByName: user.name,
      performedAt: DateTime.now(),
    );
    await ds.registerMovement(
      movement: movement,
      batchId: batchId,
      previousQuantity: previousQuantity,
      newQuantity: newQuantity,
      shouldUpdateStatus: newQuantity == 0,
    );
  }
}

final stockNotifierProvider =
    AsyncNotifierProvider<StockNotifier, void>(StockNotifier.new);
