import 'package:dio/dio.dart';

class ProductApiResult {
  final String? name;
  final String? brand;
  final String? category;
  final String? imageUrl;
  final String barcode;
  final bool found;

  const ProductApiResult({
    this.name,
    this.brand,
    this.category,
    this.imageUrl,
    required this.barcode,
    required this.found,
  });
}

class OpenFoodFactsDatasource {
  final Dio _dio;

  OpenFoodFactsDatasource({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://world.openfoodfacts.org',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {
                'User-Agent':
                    'EducaStock/1.0 (ONG Casa da Crianca; contact@casadacrianca.org.br)',
              },
            ));

  Future<ProductApiResult> lookupBarcode(String barcode) async {
    try {
      final response =
          await _dio.get('/api/v0/product/$barcode.json');
      final data = response.data as Map<String, dynamic>;

      if (data['status'] != 1) {
        return ProductApiResult(barcode: barcode, found: false);
      }

      final product = data['product'] as Map<String, dynamic>;
      final name = _firstNonEmpty([
        product['product_name_pt'] as String?,
        product['product_name'] as String?,
        product['generic_name_pt'] as String?,
        product['generic_name'] as String?,
      ]);

      final brand = product['brands'] as String?;
      final categoryTags =
          (product['categories_tags'] as List?)?.cast<String>() ?? [];
      final category = _mapCategory(categoryTags);
      final imageUrl = product['image_front_url'] as String?;

      return ProductApiResult(
        barcode: barcode,
        found: name != null,
        name: name,
        brand: brand?.split(',').first.trim(),
        category: category,
        imageUrl: imageUrl,
      );
    } on DioException {
      return ProductApiResult(barcode: barcode, found: false);
    }
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  String? _mapCategory(List<String> tags) {
    for (final tag in tags) {
      if (tag.contains('beverages') || tag.contains('bebidas')) {
        return 'bebida';
      }
      if (tag.contains('food') ||
          tag.contains('aliment') ||
          tag.contains('foods')) {
        return 'alimento';
      }
    }
    return null;
  }
}
