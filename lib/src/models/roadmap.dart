/// Semantic kind of board column.
enum BoardColumnKind {
  pendingReview('pending_review'),
  normal('normal'),
  done('done');

  final String wireValue;
  const BoardColumnKind(this.wireValue);

  static BoardColumnKind fromWire(String? value) {
    for (final k in BoardColumnKind.values) {
      if (k.wireValue == value) return k;
    }
    return BoardColumnKind.normal;
  }
}

/// Kanban board column on the roadmap.
class BoardColumn {
  final String id;
  final String appId;
  final String name;
  final String slug;
  final int position;
  final bool isVisible;
  final bool isSystem;
  final BoardColumnKind kind;
  final String? color;
  final String createdAt;
  final String updatedAt;

  const BoardColumn({
    required this.id,
    required this.appId,
    required this.name,
    required this.slug,
    required this.position,
    required this.isVisible,
    required this.isSystem,
    required this.kind,
    this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BoardColumn.fromJson(Map<String, dynamic> json) {
    return BoardColumn(
      id: json['id'] as String? ?? '',
      appId: json['appId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      isVisible: json['isVisible'] as bool? ?? true,
      isSystem: json['isSystem'] as bool? ?? false,
      kind: BoardColumnKind.fromWire(json['kind'] as String?),
      color: json['color'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

/// An app release version milestone.
class AppVersion {
  final String id;
  final String appId;
  final String label;
  final int position;
  final bool released;
  final String? releasedAt;
  final String? description;
  final String createdAt;
  final String updatedAt;

  const AppVersion({
    required this.id,
    required this.appId,
    required this.label,
    required this.position,
    required this.released,
    this.releasedAt,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      id: json['id'] as String? ?? '',
      appId: json['appId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      position: (json['position'] as num?)?.toInt() ?? 0,
      released: json['released'] as bool? ?? false,
      releasedAt: json['releasedAt'] as String?,
      description: json['description'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}
