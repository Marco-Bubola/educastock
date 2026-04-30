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
    required String section,
    required String shelf,
    String? level,
    String? room,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(locationsDatasourceProvider).createLocation(
            section: section,
            shelf: shelf,
            level: level,
            room: room,
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
