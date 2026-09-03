/// Semantic category of a Kanban roadmap board column.
///
/// Used to differentiate backlog / triage stages, active development, and shipped items.
///
/// ### Example
/// ```dart
/// final kind = BoardColumnKind.fromWire('pending_review');
/// if (kind == BoardColumnKind.pendingReview) {
///   print('Column requires moderation');
/// }
/// ```
enum BoardColumnKind {
  /// Intake or triage column holding newly submitted user suggestions.
  pendingReview('pending_review'),

  /// Standard progress column (e.g. `'Planned'`, `'In Progress'`).
  normal('normal'),

  /// Completed stage column containing shipped or released features.
  done('done');

  /// Wire string representation for API payloads.
  final String wireValue;

  /// Creates a [BoardColumnKind] with the associated [wireValue].
  const BoardColumnKind(this.wireValue);

  /// Parses a wire string representation into a [BoardColumnKind].
  ///
  /// Defaults to [BoardColumnKind.normal] if [value] is unrecognised.
  ///
  /// ### Example
  /// ```dart
  /// final kind = BoardColumnKind.fromWire('done'); // BoardColumnKind.done
  /// ```
  static BoardColumnKind fromWire(String? value) {
    for (final k in BoardColumnKind.values) {
      if (k.wireValue == value) return k;
    }
    return BoardColumnKind.normal;
  }
}

/// Kanban board column representation configured for the public roadmap.
///
/// Returned by `GET /api/v1/public/columns/:appKey`.
///
/// ### Example
/// ```dart
/// final columns = await client.fetchColumns();
/// for (final col in columns) {
///   print('Column: ${col.name} (order: ${col.position})');
/// }
/// ```
class BoardColumn {
  /// Unique database ID of the column.
  final String id;

  /// Identifier of the parent application.
  final String appId;

  /// Display name of the column (e.g. `'In Progress'`).
  final String name;

  /// URL and filter slug (e.g. `'in-progress'`).
  final String slug;

  /// Relative sort order position on the roadmap board.
  final int position;

  /// Whether this column is visible to public end users.
  final bool isVisible;

  /// Whether this is a default built-in system column.
  final bool isSystem;

  /// Semantic classification of the column stage.
  final BoardColumnKind kind;

  /// Optional hex color code for column header accents (e.g. `'#10B981'`).
  final String? color;

  /// ISO 8601 creation timestamp string.
  final String createdAt;

  /// ISO 8601 last-update timestamp string.
  final String updatedAt;

  /// Creates a [BoardColumn] configuration record.
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

  /// Deserializes [BoardColumn] from a JSON map.
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

/// Release version milestone configured for the application.
///
/// Returned by `GET /api/v1/public/versions/:appKey`.
///
/// ### Example
/// ```dart
/// final versions = await client.fetchVersions();
/// final active = versions.where((v) => !v.released);
/// print('Upcoming versions: ${active.map((v) => v.label).join(', ')}');
/// ```
class AppVersion {
  /// Unique database ID of the version milestone.
  final String id;

  /// Identifier of the parent application.
  final String appId;

  /// Version label for display (e.g. `'2.1.0'`, `'Summer 2026'`).
  final String label;

  /// Relative sort order position.
  final int position;

  /// Whether this version has officially been shipped and released.
  final bool released;

  /// ISO 8601 release timestamp string, if released.
  final String? releasedAt;

  /// Optional release notes summary or milestone description.
  final String? description;

  /// ISO 8601 creation timestamp string.
  final String createdAt;

  /// ISO 8601 last-update timestamp string.
  final String updatedAt;

  /// Creates an [AppVersion] milestone record.
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

  /// Deserializes [AppVersion] from a JSON map.
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
