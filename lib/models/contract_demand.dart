class ContractDemand {
  final String id;
  final String siteId;
  final double contractDemandKva;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final DateTime createdAt;
  final bool syncPending;

  ContractDemand({
    required this.id,
    required this.siteId,
    required this.contractDemandKva,
    required this.effectiveFrom,
    this.effectiveTo,
    DateTime? createdAt,
    this.syncPending = true,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'site_id': siteId,
        'contract_demand_kva': contractDemandKva,
        'effective_from': effectiveFrom.toIso8601String().substring(0, 10),
        'effective_to': effectiveTo?.toIso8601String().substring(0, 10),
        'created_at': createdAt.toIso8601String(),
        'sync_pending': syncPending ? 1 : 0,
      };

  factory ContractDemand.fromMap(Map<String, dynamic> map) => ContractDemand(
        id: map['id'] as String,
        siteId: map['site_id'] as String,
        contractDemandKva: (map['contract_demand_kva'] as num).toDouble(),
        effectiveFrom: DateTime.parse(map['effective_from'] as String),
        effectiveTo: map['effective_to'] != null
            ? DateTime.parse(map['effective_to'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        syncPending: (map['sync_pending'] as int?) == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'site_id': siteId,
        'contract_demand_kva': contractDemandKva,
        'effective_from': effectiveFrom.toIso8601String().substring(0, 10),
        'effective_to': effectiveTo?.toIso8601String().substring(0, 10),
        'created_at': createdAt.toIso8601String(),
      };

  factory ContractDemand.fromJson(Map<String, dynamic> json) =>
      ContractDemand(
        id: json['id'] as String,
        siteId: json['site_id'] as String,
        contractDemandKva: (json['contract_demand_kva'] as num).toDouble(),
        effectiveFrom: DateTime.parse(json['effective_from'] as String),
        effectiveTo: json['effective_to'] != null
            ? DateTime.parse(json['effective_to'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
