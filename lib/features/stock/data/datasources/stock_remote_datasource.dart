import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/stock_movement.dart';

class StockRemoteDatasource {
  final FirebaseFirestore _db;

  StockRemoteDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _movements =>
      _db.collection('stock_movements');
  CollectionReference<Map<String, dynamic>> get _auditLogs =>
      _db.collection('audit_logs');

  Future<void> registerMovement({
    required StockMovement movement,
    required String batchId,
    required int previousQuantity,
    required int newQuantity,
    required bool shouldUpdateStatus,
  }) async {
    await _db.runTransaction((tx) async {
      final movRef = _movements.doc();
      tx.set(movRef, movement.toMap());

      final batchRef = _db.collection('batches').doc(batchId);
      tx.update(batchRef, {
        'quantity': newQuantity,
        if (shouldUpdateStatus) 'status': 'distribuido',
      });

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

  Stream<List<StockMovement>> watchMovements({int limit = 200}) {
    return _movements
        .orderBy('performedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StockMovement.fromMap(d.data(), d.id))
            .toList());
  }

  Stream<List<StockMovement>> watchMovementsByProduct(String productId) {
    return _movements
        .where('productId', isEqualTo: productId)
        .orderBy('performedAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StockMovement.fromMap(d.data(), d.id))
            .toList());
  }

  Future<List<StockMovement>> getMovementsByPeriod({
    required DateTime from,
    required DateTime to,
    String? productId,
  }) async {
    Query<Map<String, dynamic>> query = _movements
        .where('performedAt', isGreaterThanOrEqualTo: from.toIso8601String())
        .where('performedAt', isLessThanOrEqualTo: to.toIso8601String())
        .orderBy('performedAt', descending: true);

    if (productId != null) {
      query = query.where('productId', isEqualTo: productId);
    }

    final snap = await query.get();
    return snap.docs
        .map((d) => StockMovement.fromMap(d.data(), d.id))
        .toList();
  }

  Stream<List<Map<String, dynamic>>> watchAuditLogs({int limit = 50}) {
    return _auditLogs
        .orderBy('performedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }
}
