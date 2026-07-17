class Panel {
  final String id;
  final String siteId;
  final String name;
  final String? panelType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncPending;

  Panel({
    required this.id,
    required this.siteId,
    required this.name,
    this.panelType,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncPending = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'site_id': siteId,
        'name': name,
        'panel_type': panelType,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_pending': syncPending ? 1 : 0,
      };

  factory Panel.fromMap(Map<String, dynamic> map) => Panel(
        id: map['id'] as String,
        siteId: map['site_id'] as String,
        name: map['name'] as String,
        panelType: map['panel_type'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncPending: (map['sync_pending'] as int?) == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'site_id': siteId,
        'name': name,
        'panel_type': panelType,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Panel.fromJson(Map<String, dynamic> json) => Panel(
        id: json['id'] as String,
        siteId: json['site_id'] as String,
        name: json['name'] as String,
        panelType: json['panel_type'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Panel copyWith({
    String? name,
    String? panelType,
  }) =>
      Panel(
        id: id,
        siteId: siteId,
        name: name ?? this.name,
        panelType: panelType ?? this.panelType,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        syncPending: true,
      );
}
