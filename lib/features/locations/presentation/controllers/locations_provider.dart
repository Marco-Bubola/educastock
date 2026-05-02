import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/locations_remote_datasource.dart';
import '../../domain/entities/storage_location.dart';

final locationsDatasourceProvider = Provider<LocationsRemoteDatasource>(
  (_) => LocationsRemoteDatasource(),
);

final activeLocationsProvider = StreamProvider<List<StorageLocation>>((ref) {
  return ref.watch(locationsDatasourceProvider).watchActiveLocations();
});

class LocationsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createLocation({
    String? locationName,
    required String section,
    required String shelf,
    String? level,
    String? room,
    int? shelvesCount,
    int? levelsCount,
    int? productsPerLevel,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(locationsDatasourceProvider).createLocation(
            locationName: locationName,
            section: section,
            shelf: shelf,
            level: level,
            room: room,
            shelvesCount: shelvesCount,
            levelsCount: levelsCount,
            productsPerLevel: productsPerLevel,
          );
    });
  }

  Future<void> deactivateLocation(String id) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(locationsDatasourceProvider).deactivateLocation(id);
    });
  }
}

final locationsNotifierProvider =
    AsyncNotifierProvider<LocationsNotifier, void>(LocationsNotifier.new);
