import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/stock_movement.dart';

class StockRemoteDatasource {
  final FirebaseFirestore _db;

  StockRemoteDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference get _movements => _db.collection('stock_movements');
  CollectionReference get _auditLogs => _db.collection('audit_logs');

  /// Registra movimentação e audit log em transação atômica
  Future<void> registerMovement({
    required StockMovement movement,
    required String batchId,
    required int previousQuantity,
    required int newQuantity,
    required bool shouldUpdateStatus,
  }) async {
    await _db.runTransaction((tx) async {
      // 1. Salva movimentação
      final movRef = _movements.doc();
      tx.set(movRef, movement.toMap());

      // 2. Atualiza quantidade no lote
      final batchRef = _db.collection('batches').doc(batchId);
      tx.update(batchRef, {
        'quantity': newQuantity,
        if (shouldUpdateStatus) 'status': 'distribuido',
      });

      // 3. Audit log
      final auditRef = _auditLogs.doc();
      tx.set(auditRef, {
        'collection': 'batches',
        'documentId': batchId,
        'action': movement.type.name,
        'before': movement.auditBefore,
        'after': movement.auditAfter,
        'performedBy': movement.performedBy,
        'performedByName': movement.performedByName,
        'performedAt': movement.performedAt.toIso8601String(),
      });
    });
  }

  Stream<List<StockMovement>> watchMovementsByProduct(String productId) {
    return _movements
        .where('productId', isEqualTo: productId)
        .orderBy('performedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                StockMovement.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<List<StockMovement>> getMovementsByPeriod({
    required DateTime from,
    required DateTime to,
    String? productId,
  }) async {
    var query = _movements
        .where('performedAt',
            isGreaterThanOrEqualTo: from.toIso8601String())
        .where('performedAt', isLessThanOrEqualTo: to.toIso8601String())
        .orderBy('performedAt', descending: true);

    if (productId != null) {
      query = query.where('productId', isEqualTo: productId) as Query<Object?> as CollectionReference<Object?>;
    }

    final snap = await (query as Query<Object?>).get();
    return snap.docs
        .map((d) =>
            StockMovement.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  Stream<List<Map<String, dynamic>>> watchAuditLogs({int limit = 50}) {
    return _auditLogs
        .orderBy('performedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList());
  }
}
