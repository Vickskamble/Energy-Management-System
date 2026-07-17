class Meter {
  final String id;
  final String panelId;
  final String meterNumber;
  final String? meterType;
  final double? ctRatio;
  final double? ptRatio;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncPending;

  Meter({
    required this.id,
    required this.panelId,
    required this.meterNumber,
    this.meterType,
    this.ctRatio,
    this.ptRatio,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncPending = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'panel_id': panelId,
        'meter_number': meterNumber,
        'meter_type': meterType,
        'ct_ratio': ctRatio,
        'pt_ratio': ptRatio,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_pending': syncPending ? 1 : 0,
      };

  factory Meter.fromMap(Map<String, dynamic> map) => Meter(
        id: map['id'] as String,
        panelId: map['panel_id'] as String,
        meterNumber: map['meter_number'] as String,
        meterType: map['meter_type'] as String?,
        ctRatio: (map['ct_ratio'] as num?)?.toDouble(),
        ptRatio: (map['pt_ratio'] as num?)?.toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncPending: (map['sync_pending'] as int?) == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'panel_id': panelId,
        'meter_number': meterNumber,
        'meter_type': meterType,
        'ct_ratio': ctRatio,
        'pt_ratio': ptRatio,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Meter.fromJson(Map<String, dynamic> json) => Meter(
        id: json['id'] as String,
        panelId: json['panel_id'] as String,
        meterNumber: json['meter_number'] as String,
        meterType: json['meter_type'] as String?,
        ctRatio: (json['ct_ratio'] as num?)?.toDouble(),
        ptRatio: (json['pt_ratio'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Meter copyWith({
    String? meterNumber,
    String? meterType,
    double? ctRatio,
    double? ptRatio,
  }) =>
      Meter(
        id: id,
        panelId: panelId,
        meterNumber: meterNumber ?? this.meterNumber,
        meterType: meterType ?? this.meterType,
        ctRatio: ctRatio ?? this.ctRatio,
        ptRatio: ptRatio ?? this.ptRatio,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        syncPending: true,
      );
}
