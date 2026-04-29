import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/products_remote_datasource.dart';
import '../../domain/entities/product.dart';

final productsDatasourceProvider = Provider<ProductsRemoteDatasource>(
  (_) => ProductsRemoteDatasource(),
);

final productsProvider = StreamProvider<List<Product>>((ref) {
  return ref.watch(productsDatasourceProvider).watchProducts();
});

final productByBarcodeProvider =
    FutureProvider.family<Product?, String>((ref, barcode) async {
  return ref.watch(productsDatasourceProvider).getProductByBarcode(barcode);
});

// Form notifier para criação/edição de produto
class ProductFormNotifier extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncValue.data(null);

  Future<void> saveProduct(Product product) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final ds = ref.read(productsDatasourceProvider);
      return ds.saveProduct(product);
    });
  }
}

final productFormProvider =
    NotifierProvider<ProductFormNotifier, AsyncValue<String?>>(
        () => ProductFormNotifier());
