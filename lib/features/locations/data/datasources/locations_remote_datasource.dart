import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/storage_location.dart';

class LocationsRemoteDatasource {
  final FirebaseFirestore _db;

  LocationsRemoteDatasource({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('storage_locations');

  Stream<List<StorageLocation>> watchActiveLocations() {
    return _col
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => StorageLocation.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => a.label.compareTo(b.label));
      return list;
    });
  }

  Future<String> createLocation({
    required String section,
    required String shelf,
    String? level,
    String? room,
  }) async {
    final normalized = _normalizedKey(
      section: section,
      shelf: shelf,
      level: level,
      room: room,
    );

    final existing = await _col
        .where('normalizedKey', isEqualTo: normalized)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('Esta localizacao ja esta cadastrada.');
    }

    final location = StorageLocation(
      id: '',
      section: section.trim(),
      shelf: shelf.trim(),
      level: _clean(level),
      room: _clean(room),
      isActive: true,
      createdAt: DateTime.now(),
      normalizedKey: normalized,
    );

    final ref = await _col.add(location.toMap());
    return ref.id;
  }

  Future<void> deactivateLocation(String id) async {
    await _col.doc(id).update({'isActive': false});
  }

  String _normalizedKey({
    required String section,
    required String shelf,
    String? level,
    String? room,
  }) {
    String n(String? value) =>
        (value ?? '').trim().toLowerCase().replaceAll(' ', '');
    return '${n(section)}|${n(shelf)}|${n(level)}|${n(room)}';
  }

  String? _clean(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }
}
