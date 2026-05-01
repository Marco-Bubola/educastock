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
    CollectionReference<Map<String, dynamic>> get _adjustmentApprovals =>
      _db.collection('adjustment_approvals');

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

  Future<void> createAdjustmentApprovalRequest({
    required String productId,
    required String productName,
    required String batchId,
    required int quantity,
    required String requestedBy,
    required String requestedByName,
    required String reason,
  }) async {
    await _adjustmentApprovals.add({
      'productId': productId,
      'productName': productName,
      'batchId': batchId,
      'quantity': quantity,
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'reason': reason,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<Map<String, dynamic>>> watchPendingAdjustmentApprovals() {
    return _adjustmentApprovals
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<void> processAdjustmentApproval({
    required String requestId,
    required bool approve,
    required String approverId,
    required String approverName,
  }) async {
    await _db.runTransaction((tx) async {
      final reqRef = _adjustmentApprovals.doc(requestId);
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) return;
      final req = reqSnap.data()!;

      if (!approve) {
        tx.update(reqRef, {
          'status': 'rejected',
          'reviewedBy': approverId,
          'reviewedByName': approverName,
          'reviewedAt': DateTime.now().toIso8601String(),
        });
        return;
      }

      final batchId = req['batchId'] as String;
      final quantity = (req['quantity'] as num?)?.toInt() ?? 0;
      final productId = req['productId'] as String? ?? '';
      final productName = req['productName'] as String? ?? '';
      final reason = req['reason'] as String?;

      final batchRef = _db.collection('batches').doc(batchId);
      final batchSnap = await tx.get(batchRef);
      if (!batchSnap.exists) {
        tx.update(reqRef, {
          'status': 'failed',
          'failureReason': 'batch_not_found',
          'reviewedBy': approverId,
          'reviewedByName': approverName,
          'reviewedAt': DateTime.now().toIso8601String(),
        });
        return;
      }

      final batchData = batchSnap.data()!;
      final previousQty = (batchData['quantity'] as num?)?.toInt() ?? 0;
      final newQty = previousQty - quantity;
      if (newQty < 0) {
        tx.update(reqRef, {
          'status': 'failed',
          'failureReason': 'insufficient_quantity',
          'reviewedBy': approverId,
          'reviewedByName': approverName,
          'reviewedAt': DateTime.now().toIso8601String(),
        });
        return;
      }

      final movementRef = _movements.doc();
      tx.set(movementRef, {
        'productId': productId,
        'productName': productName,
        'batchId': batchId,
        'type': MovementType.ajusteNegativo.name,
        'quantity': quantity,
        'reason': reason,
        'activity': null,
        'performedBy': approverId,
        'performedByName': approverName,
        'performedAt': DateTime.now().toIso8601String(),
        'isPendingSync': false,
        'auditBefore': {'quantity': previousQty, 'status': batchData['status']},
        'auditAfter': {
          'quantity': newQty,
          'status': newQty <= 0 ? 'distribuido' : batchData['status'],
        },
      });

      tx.update(batchRef, {
        'quantity': newQty,
        if (newQty <= 0) 'status': 'distribuido',
      });

      final auditRef = _auditLogs.doc();
      tx.set(auditRef, {
        'collection': 'adjustment_approvals',
        'documentId': requestId,
        'action': 'approval_granted',
        'before': {'status': 'pending'},
        'after': {'status': 'approved'},
        'performedBy': approverId,
        'performedByName': approverName,
        'performedAt': DateTime.now().toIso8601String(),
      });

      tx.update(reqRef, {
        'status': 'approved',
        'reviewedBy': approverId,
        'reviewedByName': approverName,
        'reviewedAt': DateTime.now().toIso8601String(),
      });
    });
  }
}
