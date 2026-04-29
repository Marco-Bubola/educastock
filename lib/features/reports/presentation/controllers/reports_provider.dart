import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------- Modelos de relatório ----------

class ReportSummary {
  final int totalProducts;
  final int totalBatches;
  final int expiringIn30Days;
  final int expiredBatches;
  final int lowStockProducts;
  final int movementsThisMonth;

  const ReportSummary({
    required this.totalProducts,
    required this.totalBatches,
    required this.expiringIn30Days,
    required this.expiredBatches,
    required this.lowStockProducts,
    required this.movementsThisMonth,
  });
}

class CategoryStock {
  final String category;
  final int totalItems;
  final double percentage;

  const CategoryStock({
    required this.category,
    required this.totalItems,
    required this.percentage,
  });
}

// ---------- Datasource ----------

class ReportsRemoteDatasource {
  final _firestore = FirebaseFirestore.instance;

  Future<ReportSummary> fetchSummary() async {
    final now = DateTime.now();
    final in30Days = now.add(const Duration(days: 30));

    final productsSnap =
        await _firestore.collection('products').count().get();
    final batchesSnap = await _firestore.collection('batches').count().get();

    final expiringSnap = await _firestore
        .collection('batches')
        .where('expiryDate',
            isGreaterThan: Timestamp.fromDate(now),
            isLessThan: Timestamp.fromDate(in30Days))
        .count()
        .get();

    final expiredSnap = await _firestore
        .collection('batches')
        .where('expiryDate', isLessThan: Timestamp.fromDate(now))
        .count()
        .get();

    final startOfMonth = DateTime(now.year, now.month, 1);
    final movementsSnap = await _firestore
        .collection('stock_movements')
        .where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .count()
        .get();

    return ReportSummary(
      totalProducts: productsSnap.count ?? 0,
      totalBatches: batchesSnap.count ?? 0,
      expiringIn30Days: expiringSnap.count ?? 0,
      expiredBatches: expiredSnap.count ?? 0,
      lowStockProducts: 0, // calculado via business logic
      movementsThisMonth: movementsSnap.count ?? 0,
    );
  }

  Future<List<CategoryStock>> fetchStockByCategory() async {
    final snap =
        await _firestore.collection('products').get();
    final Map<String, int> counts = {};
    for (final doc in snap.docs) {
      final cat = (doc.data()['category'] as String?) ?? 'outros';
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    final total = counts.values.fold(0, (a, b) => a + b);
    return counts.entries.map((e) {
      return CategoryStock(
        category: e.key,
        totalItems: e.value,
        percentage: total == 0 ? 0 : e.value / total * 100,
      );
    }).toList()
      ..sort((a, b) => b.totalItems.compareTo(a.totalItems));
  }
}

// ---------- Providers ----------

final reportsDatasourceProvider = Provider<ReportsRemoteDatasource>(
  (_) => ReportsRemoteDatasource(),
);

final reportSummaryProvider = FutureProvider<ReportSummary>((ref) {
  return ref.watch(reportsDatasourceProvider).fetchSummary();
});

final stockByCategoryProvider =
    FutureProvider<List<CategoryStock>>((ref) {
  return ref.watch(reportsDatasourceProvider).fetchStockByCategory();
});
