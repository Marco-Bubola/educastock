class StorageLocation {
  final String id;
  final String? locationName;
  final String section;
  final String shelf;
  final String? level;
  final String? room;
  final int? shelvesCount;
  final int? levelsCount;
  final int? productsPerLevel;
  final int? capacity;
  final bool isActive;
  final DateTime createdAt;
  final String normalizedKey;

  const StorageLocation({
    required this.id,
    this.locationName,
    required this.section,
    required this.shelf,
    this.level,
    this.room,
    this.shelvesCount,
    this.levelsCount,
    this.productsPerLevel,
    this.capacity,
    this.isActive = true,
    required this.createdAt,
    required this.normalizedKey,
  });

  String get label {
    final parts = <String>[
      if ((locationName ?? '').isNotEmpty) locationName!,
      'Secao $section',
      'Prateleira $shelf',
      if ((level ?? '').isNotEmpty) 'Nivel $level',
      if ((room ?? '').isNotEmpty) 'Sala $room',
    ];
    return parts.join(' • ');
  }

  factory StorageLocation.fromMap(Map<String, dynamic> map, String id) {
    return StorageLocation(
      id: id,
      locationName: map['locationName'] as String?,
      section: map['section'] as String,
      shelf: map['shelf'] as String,
      level: map['level'] as String?,
      room: map['room'] as String?,
      shelvesCount: (map['shelvesCount'] as num?)?.toInt(),
      levelsCount: (map['levelsCount'] as num?)?.toInt(),
      productsPerLevel: (map['productsPerLevel'] as num?)?.toInt(),
      capacity: (map['capacity'] as num?)?.toInt(),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String),
      normalizedKey: map['normalizedKey'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'locationName': locationName,
        'section': section,
        'shelf': shelf,
        'level': level,
        'room': room,
        'shelvesCount': shelvesCount,
        'levelsCount': levelsCount,
        'productsPerLevel': productsPerLevel,
        'capacity': capacity,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'normalizedKey': normalizedKey,
        'label': label,
      };
}
