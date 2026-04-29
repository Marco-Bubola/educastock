import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/batch.dart';

class BatchesRemoteDatasource {
  final FirebaseFirestore _db;

  BatchesRemoteDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference get _col => _db.collection('batches');

  Stream<List<Batch>> watchBatchesByProduct(String productId) {
    return _col
        .where('productId', isEqualTo: productId)
        .where('status', isEqualTo: BatchStatus.disponivel.name)
        .orderBy('expiryDate')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Batch.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Retorna todos os lotes disponíveis ordenados por validade (FEFO)
  Stream<List<Batch>> watchAllAvailableBatches() {
    return _col
        .where('status', isEqualTo: BatchStatus.disponivel.name)
        .where('quantity', isGreaterThan: 0)
        .snapshots()
        .map((snap) {
      final batches = snap.docs
          .map((d) => Batch.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      // FEFO: ordenar por expiryDate (null/noExpiry vai para o fim)
      batches.sort((a, b) {
        if (a.noExpiry && b.noExpiry) return 0;
        if (a.noExpiry) return 1;
        if (b.noExpiry) return -1;
        if (a.expiryDate == null && b.expiryDate == null) return 0;
        if (a.expiryDate == null) return 1;
        if (b.expiryDate == null) return -1;
        return a.expiryDate!.compareTo(b.expiryDate!);
      });
      return batches;
    });
  }

  /// Retorna lotes com vencimento nos próximos [days] dias
  Future<List<Batch>> getBatchesExpiringInDays(int days) async {
    final limit = DateTime.now().add(Duration(days: days));
    final snap = await _col
        .where('status', isEqualTo: BatchStatus.disponivel.name)
        .where('noExpiry', isEqualTo: false)
        .where('expiryDate',
            isLessThanOrEqualTo: limit.toIso8601String())
        .orderBy('expiryDate')
        .get();
    return snap.docs
        .map((d) => Batch.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  Future<String> saveBatch(Batch batch) async {
    if (batch.id.isEmpty) {
      final ref = await _col.add(batch.toMap());
      return ref.id;
    }
    await _col.doc(batch.id).set(batch.toMap());
    return batch.id;
  }

  Future<void> updateBatchQuantity(
      String batchId, int newQuantity, BatchStatus status) async {
    await _col.doc(batchId).update({
      'quantity': newQuantity,
      'status': status.name,
    });
  }
}
