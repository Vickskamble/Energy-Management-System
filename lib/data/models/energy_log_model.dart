import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/calculation_engine.dart';
import '../../domain/entities/energy_log_entity.dart';

class EnergyLogModel {
  final String id;
  final String meterName;
  final double kwh;
  final double kvah;
  final double rkvarhLag;
  final double rkvarhLead;
  final double powerFactor;
  final double mdRecorded;
  final double contractDemand;
  final double estimatedBill;
  final DateTime loggedAt;
  final bool isSynced;
  final String? userId;

  const EnergyLogModel({
    required this.id,
    required this.meterName,
    required this.kwh,
    required this.kvah,
    required this.rkvarhLag,
    required this.rkvarhLead,
    required this.powerFactor,
    required this.mdRecorded,
    required this.contractDemand,
    required this.estimatedBill,
    required this.loggedAt,
    this.isSynced = false,
    this.userId,
  });

  EnergyLogEntity toEntity() => EnergyLogEntity(
        id: id,
        meterName: meterName,
        kwh: kwh,
        kvah: kvah,
        rkvarhLag: rkvarhLag,
        rkvarhLead: rkvarhLead,
        powerFactor: powerFactor,
        mdRecorded: mdRecorded,
        contractDemand: contractDemand,
        estimatedBill: estimatedBill,
        loggedAt: loggedAt,
        isSynced: isSynced,
        userId: userId,
      );

  factory EnergyLogModel.fromEntity(EnergyLogEntity entity) => EnergyLogModel(
        id: entity.id,
        meterName: entity.meterName,
        kwh: entity.kwh,
        kvah: entity.kvah,
        rkvarhLag: entity.rkvarhLag,
        rkvarhLead: entity.rkvarhLead,
        powerFactor: entity.powerFactor,
        mdRecorded: entity.mdRecorded,
        contractDemand: entity.contractDemand,
        estimatedBill: entity.estimatedBill,
        loggedAt: entity.loggedAt,
        isSynced: entity.isSynced,
        userId: entity.userId,
      );

  // --- Sembast serialization ---
  Map<String, Object?> toMap() => {
        'id': id,
        'meter_name': meterName,
        'kwh': _toPrecision(kwh, 2),
        'kvah': _toPrecision(kvah, 2),
        'rkvarh_lag': _toPrecision(rkvarhLag, 2),
        'rkvarh_lead': _toPrecision(rkvarhLead, 2),
        'power_factor': _toPrecision(powerFactor, 3),
        'md_recorded': _toPrecision(mdRecorded, 2),
        'contract_demand': _toPrecision(contractDemand, 2),
        'estimated_bill': _toPrecision(estimatedBill, 2),
        'logged_at': loggedAt.toUtc().toIso8601String(),
        'is_synced': isSynced ? 1 : 0,
        if (userId != null) 'user_id': userId,
      };

  factory EnergyLogModel.fromMap(Map<String, Object?> map) {
    return EnergyLogModel(
      id: map['id'] as String,
      meterName: map['meter_name'] as String,
      kwh: _parseDouble(map['kwh']),
      kvah: _parseDouble(map['kvah']),
      rkvarhLag: _parseDouble(map['rkvarh_lag']),
      rkvarhLead: _parseDouble(map['rkvarh_lead']),
      powerFactor: _parseDouble(map['power_factor']),
      mdRecorded: _parseDouble(map['md_recorded']),
      contractDemand: _parseDouble(map['contract_demand']),
      estimatedBill: _parseDouble(map['estimated_bill']),
      loggedAt: DateTime.parse(map['logged_at'] as String).toLocal(),
      isSynced: (map['is_synced'] as int?) == 1,
      userId: map['user_id'] as String?,
    );
  }

  // --- Supabase / JSON serialization ---
  Map<String, dynamic> toJson() => {
        'id': id,
        'meter_name': meterName,
        'kwh': (kwh * 100).round() / 100,
        'kvah': (kvah * 100).round() / 100,
        'rkvarh_lag': (rkvarhLag * 100).round() / 100,
        'rkvarh_lead': (rkvarhLead * 100).round() / 100,
        'power_factor': (powerFactor * 1000).round() / 1000,
        'md_recorded': (mdRecorded * 100).round() / 100,
        'contract_demand': (contractDemand * 100).round() / 100,
        'estimated_bill': (estimatedBill * 100).round() / 100,
        'logged_at': loggedAt.toUtc().toIso8601String(),
        if (userId != null) 'user_id': userId,
      };

  factory EnergyLogModel.fromJson(Map<String, dynamic> json) {
    return EnergyLogModel(
      id: json['id'] as String,
      meterName: json['meter_name'] as String,
      kwh: (json['kwh'] as num).toDouble(),
      kvah: (json['kvah'] as num).toDouble(),
      rkvarhLag: (json['rkvarh_lag'] as num).toDouble(),
      rkvarhLead: (json['rkvarh_lead'] as num).toDouble(),
      powerFactor: (json['power_factor'] as num).toDouble(),
      mdRecorded: (json['md_recorded'] as num).toDouble(),
      contractDemand: (json['contract_demand'] as num).toDouble(),
      estimatedBill: (json['estimated_bill'] as num).toDouble(),
      loggedAt: DateTime.parse(json['logged_at'] as String).toLocal(),
      userId: json['user_id'] as String?,
    );
  }

  /// Factory to create a new reading with computed fields
  factory EnergyLogModel.create({
    required String meterName,
    required double kwh,
    required double kvah,
    double rkvarhLag = 0,
    double rkvarhLead = 0,
    double? powerFactor,
    required double mdRecorded,
    double contractDemand = AppConstants.defaultContractDemandKva,
    DateTime? loggedAt,
    String? userId,
  }) {
    final pf = powerFactor ??
        CalculationEngine.calculatePowerFactor(kwh, kvah);
    final bill = CalculationEngine.calculateEstimatedBill(
      kwh: kwh,
      mdRecorded: mdRecorded,
      powerFactor: pf,
    );
    final uid = userId ??
        _tryGetCurrentUserId();
    return EnergyLogModel(
      id: const Uuid().v4(),
      meterName: meterName,
      kwh: (kwh * 100).round() / 100,
      kvah: (kvah * 100).round() / 100,
      rkvarhLag: (rkvarhLag * 100).round() / 100,
      rkvarhLead: (rkvarhLead * 100).round() / 100,
      powerFactor: (pf * 1000).round() / 1000,
      mdRecorded: (mdRecorded * 100).round() / 100,
      contractDemand: (contractDemand * 100).round() / 100,
      estimatedBill: (bill * 100).round() / 100,
      loggedAt: loggedAt ?? DateTime.now(),
      isSynced: false,
      userId: uid,
    );
  }

  static String? _tryGetCurrentUserId() {
    try {
      return Supabase.instance.client.auth.currentSession?.user.id;
    } catch (_) {
      return null;
    }
  }

  static double _parseDouble(Object? value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double _toPrecision(double value, int decimals) {
    final factor = 10.0 * decimals;
    return (value * factor).round() / factor;
  }
}
