class Site {
  final String id;
  final String name;
  final String? location;
  final double? contractDemandKva;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncPending;

  Site({
    required this.id,
    required this.name,
    this.location,
    this.contractDemandKva,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncPending = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'location': location,
        'contract_demand_kva': contractDemandKva,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_pending': syncPending ? 1 : 0,
      };

  factory Site.fromMap(Map<String, dynamic> map) => Site(
        id: map['id'] as String,
        name: map['name'] as String,
        location: map['location'] as String?,
        contractDemandKva: (map['contract_demand_kva'] as num?)?.toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncPending: (map['sync_pending'] as int?) == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'contract_demand_kva': contractDemandKva,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Site.fromJson(Map<String, dynamic> json) => Site(
        id: json['id'] as String,
        name: json['name'] as String,
        location: json['location'] as String?,
        contractDemandKva: (json['contract_demand_kva'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Site copyWith({
    String? name,
    String? location,
    double? contractDemandKva,
  }) =>
      Site(
        id: id,
        name: name ?? this.name,
        location: location ?? this.location,
        contractDemandKva: contractDemandKva ?? this.contractDemandKva,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        syncPending: true,
      );
}
