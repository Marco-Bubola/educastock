import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/entities/batch.dart';

class BatchesRemoteDatasource {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  BatchesRemoteDatasource({FirebaseFirestore? db, FirebaseStorage? storage})
      : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

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

  Future<String> saveBatch(Batch batch, {File? imageFile}) async {
    String? imageUrl = batch.imageUrl;

    // Faz upload da imagem se fornecida
    if (imageFile != null) {
      final ext = imageFile.path.split('.').last;
      final batchRef = batch.id.isNotEmpty ? batch.id : 'tmp_${DateTime.now().millisecondsSinceEpoch}';
      final ref = _storage.ref('batches/$batchRef/foto.$ext');
      final task = await ref.putFile(imageFile);
      imageUrl = await task.ref.getDownloadURL();
    }

    final batchWithImage = imageUrl != null ? batch.copyWith(imageUrl: imageUrl) : batch;

    if (batch.id.isEmpty) {
      final ref = await _col.add(batchWithImage.toMap());
      // Se tinha imagem temporária, atualiza o path no Storage com o ID real
      if (imageFile != null && imageUrl != null && imageUrl.contains('tmp_')) {
        final ext = imageFile.path.split('.').last;
        final newRef = _storage.ref('batches/${ref.id}/foto.$ext');
        await newRef.putFile(imageFile);
        final newUrl = await newRef.getDownloadURL();
        await ref.update({'imageUrl': newUrl});
      }
      return ref.id;
    }

    // Edição: se havia imagem temporária, agora atualiza com ID correto
    if (imageFile != null && imageUrl != null) {
      final ext = imageFile.path.split('.').last;
      final ref = _storage.ref('batches/${batch.id}/foto.$ext');
      final task = await ref.putFile(imageFile);
      final finalUrl = await task.ref.getDownloadURL();
      await _col.doc(batch.id).set(batchWithImage.copyWith(imageUrl: finalUrl).toMap());
      return batch.id;
    }

    await _col.doc(batch.id).set(batchWithImage.toMap());
    return batch.id;
  }

  Future<void> updateBatchQuantity(
      String batchId, int newQuantity, BatchStatus status) async {
    await _col.doc(batchId).update({
      'quantity': newQuantity,
      'status': status.name,
    });
  }

  Future<void> deleteBatch(String batchId) async {
    await _col.doc(batchId).delete();
  }
}
