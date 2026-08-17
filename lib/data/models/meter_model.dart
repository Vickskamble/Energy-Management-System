import 'package:uuid/uuid.dart';
import '../../domain/entities/meter_entity.dart';

class MeterModel {
  final String id;
  final String name;
  final String? location;
  final double contractDemandKw;
  final bool isActive;
  final double ctRatio;
  final double ptRatio;
  final String site;

  /// Client's daily average kWh consumption target — 0 = not set.
  final double dailyKwhTarget;

  const MeterModel({
    required this.id,
    required this.name,
    this.location,
    this.contractDemandKw = 400.0,
    this.isActive = true,
    this.ctRatio = 1.0,
    this.ptRatio = 1.0,
    this.site = 'Main Site',
    this.dailyKwhTarget = 0.0,
  });

  /// Multiplying factor = CT ratio × PT ratio (defaults to 1 when unset).
  double get multiplyingFactor => ctRatio * ptRatio;

  MeterEntity toEntity() => MeterEntity(
    id: id,
    name: name,
    location: location,
    contractDemandKw: contractDemandKw,
    isActive: isActive,
    ctRatio: ctRatio,
    ptRatio: ptRatio,
    site: site,
    dailyKwhTarget: dailyKwhTarget,
  );

  factory MeterModel.fromEntity(MeterEntity entity) => MeterModel(
    id: entity.id,
    name: entity.name,
    location: entity.location,
    contractDemandKw: entity.contractDemandKw,
    isActive: entity.isActive,
    ctRatio: entity.ctRatio,
    ptRatio: entity.ptRatio,
    site: entity.site,
    dailyKwhTarget: entity.dailyKwhTarget,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    if (location != null) 'location': location,
    'contract_demand_kw': contractDemandKw,
    'is_active': isActive ? 1 : 0,
    'ct_ratio': ctRatio,
    'pt_ratio': ptRatio,
    'site': site,
    'daily_kwh_target': dailyKwhTarget,
  };

  factory MeterModel.fromMap(Map<String, Object?> map) => MeterModel(
    id: map['id'] as String,
    name: map['name'] as String,
    location: map['location'] as String?,
    contractDemandKw: (map['contract_demand_kw'] as num?)?.toDouble() ?? 400.0,
    isActive: (map['is_active'] as int?) == 1,
    ctRatio: (map['ct_ratio'] as num?)?.toDouble() ?? 1.0,
    ptRatio: (map['pt_ratio'] as num?)?.toDouble() ?? 1.0,
    site: map['site'] as String? ?? 'Main Site',
    dailyKwhTarget: (map['daily_kwh_target'] as num?)?.toDouble() ?? 0.0,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (location != null) 'location': location,
    'contract_demand_kw': contractDemandKw,
    'is_active': isActive,
    'ct_ratio': ctRatio,
    'pt_ratio': ptRatio,
    'site': site,
    'daily_kwh_target': dailyKwhTarget,
  };

  factory MeterModel.fromJson(Map<String, dynamic> json) => MeterModel(
    id: json['id'] as String,
    name: json['name'] as String,
    location: json['location'] as String?,
    contractDemandKw: (json['contract_demand_kw'] as num?)?.toDouble() ?? 400.0,
    isActive: (json['is_active'] as bool?) ?? true,
    ctRatio: (json['ct_ratio'] as num?)?.toDouble() ?? 1.0,
    ptRatio: (json['pt_ratio'] as num?)?.toDouble() ?? 1.0,
    site: json['site'] as String? ?? 'Main Site',
    dailyKwhTarget: (json['daily_kwh_target'] as num?)?.toDouble() ?? 0.0,
  );

  factory MeterModel.create({
    required String name,
    String? location,
    double contractDemandKw = 400.0,
    double ctRatio = 1.0,
    double ptRatio = 1.0,
    String site = 'Main Site',
    double dailyKwhTarget = 0.0,
  }) => MeterModel(
    id: const Uuid().v4(),
    name: name,
    location: location,
    contractDemandKw: contractDemandKw,
    isActive: true,
    ctRatio: ctRatio,
    ptRatio: ptRatio,
    site: site,
    dailyKwhTarget: dailyKwhTarget,
  );
}
