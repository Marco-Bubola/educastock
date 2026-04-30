import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product.dart';

class ProductsRemoteDatasource {
  final FirebaseFirestore _db;

  ProductsRemoteDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference get _col => _db.collection('products');

  Stream<List<Product>> watchProducts() {
    return _col
        .where('isActive', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Product.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final snap = await _col
        .where('barcode', isEqualTo: barcode)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Product.fromMap(d.data() as Map<String, dynamic>, d.id);
  }

  Future<Product?> getProductById(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return Product.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<String> saveProduct(Product product) async {
    if (product.id.isEmpty) {
      final ref = await _col.add(product.toMap());
      return ref.id;
    }
    await _col.doc(product.id).set(product.toMap());
    return product.id;
  }

  Future<void> deleteProduct(String id) async {
    await _col.doc(id).update({'isActive': false});
  }
}
