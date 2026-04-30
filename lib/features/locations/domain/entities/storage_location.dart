class StorageLocation {
  final String id;
  final String section;
  final String shelf;
  final String? level;
  final String? room;
  final bool isActive;
  final DateTime createdAt;
  final String normalizedKey;

  const StorageLocation({
    required this.id,
    required this.section,
    required this.shelf,
    this.level,
    this.room,
    this.isActive = true,
    required this.createdAt,
    required this.normalizedKey,
  });

  String get label {
    final parts = <String>[
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
      section: map['section'] as String,
      shelf: map['shelf'] as String,
      level: map['level'] as String?,
      room: map['room'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String),
      normalizedKey: map['normalizedKey'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'section': section,
        'shelf': shelf,
        'level': level,
        'room': room,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'normalizedKey': normalizedKey,
        'label': label,
      };
}
