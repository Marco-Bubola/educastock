import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/open_food_facts_datasource.dart';
import '../../data/datasources/open_food_facts_datasource.dart' show ProductApiResult;

final openFoodFactsProvider = Provider<OpenFoodFactsDatasource>(
  (_) => OpenFoodFactsDatasource(),
);

class ScannerState {
  final bool isScanning;
  final String? lastBarcode;
  final AsyncValue<ProductApiResult?> apiResult;

  const ScannerState({
    this.isScanning = false,
    this.lastBarcode,
    this.apiResult = const AsyncValue.data(null),
  });

  ScannerState copyWith({
    bool? isScanning,
    String? lastBarcode,
    AsyncValue<ProductApiResult?>? apiResult,
  }) =>
      ScannerState(
        isScanning: isScanning ?? this.isScanning,
        lastBarcode: lastBarcode ?? this.lastBarcode,
        apiResult: apiResult ?? this.apiResult,
      );
}

class ScannerNotifier extends Notifier<ScannerState> {
  @override
  ScannerState build() => const ScannerState();

  void startScanning() => state = state.copyWith(isScanning: true);
  void stopScanning() => state = state.copyWith(isScanning: false);

  Future<void> onBarcodeDetected(String barcode) async {
    if (state.lastBarcode == barcode) return;
    state = state.copyWith(
      lastBarcode: barcode,
      isScanning: false,
      apiResult: const AsyncValue.loading(),
    );
    state = state.copyWith(
      apiResult: await AsyncValue.guard(() async {
        final ds = ref.read(openFoodFactsProvider);
        return ds.lookupBarcode(barcode);
      }),
    );
  }

  void reset() => state = const ScannerState();
}

final scannerProvider =
    NotifierProvider<ScannerNotifier, ScannerState>(() => ScannerNotifier());
