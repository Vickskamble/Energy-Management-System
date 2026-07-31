import 'package:uuid/uuid.dart';
import '../../domain/entities/meter_entity.dart';

class MeterModel {
  final String id;
  final String name;
  final String? location;
  final double contractDemandKw;
  final bool isActive;

  const MeterModel({
    required this.id,
    required this.name,
    this.location,
    this.contractDemandKw = 400.0,
    this.isActive = true,
  });

  MeterEntity toEntity() => MeterEntity(
    id: id,
    name: name,
    location: location,
    contractDemandKw: contractDemandKw,
    isActive: isActive,
  );

  factory MeterModel.fromEntity(MeterEntity entity) => MeterModel(
    id: entity.id,
    name: entity.name,
    location: entity.location,
    contractDemandKw: entity.contractDemandKw,
    isActive: entity.isActive,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    if (location != null) 'location': location,
    'contract_demand_kw': contractDemandKw,
    'is_active': isActive ? 1 : 0,
  };

  factory MeterModel.fromMap(Map<String, Object?> map) => MeterModel(
    id: map['id'] as String,
    name: map['name'] as String,
    location: map['location'] as String?,
    contractDemandKw: (map['contract_demand_kw'] as num?)?.toDouble() ?? 400.0,
    isActive: (map['is_active'] as int?) == 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (location != null) 'location': location,
    'contract_demand_kw': contractDemandKw,
    'is_active': isActive,
  };

  factory MeterModel.fromJson(Map<String, dynamic> json) => MeterModel(
    id: json['id'] as String,
    name: json['name'] as String,
    location: json['location'] as String?,
    contractDemandKw: (json['contract_demand_kw'] as num?)?.toDouble() ?? 400.0,
    isActive: (json['is_active'] as bool?) ?? true,
  );

  factory MeterModel.create({
    required String name,
    String? location,
    double contractDemandKw = 400.0,
  }) => MeterModel(
    id: const Uuid().v4(),
    name: name,
    location: location,
    contractDemandKw: contractDemandKw,
    isActive: true,
  );
}
