import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/calculation_engine.dart';
import '../../domain/entities/energy_log_entity.dart';

class EnergyLogModel {
  final String id;
  final String meterName;
  final double kwh;
  final double kvah;

  /// ACTUAL (cumulative) meter reading this entry was recorded against.
  /// Null for legacy rows — [hydrateActualReadings] reconstructs it as the
  /// running sum of consumed values per meter.
  final double? currentKwh;
  final double? currentKvah;

  final double rkvarhLag;
  final double rkvarhLead;
  final double powerFactor;
  final double mdRecorded;
  final double contractDemand;
  final double estimatedBill;
  final DateTime loggedAt;
  final bool isSynced;
  final String? userId;

  final double energyCharges;
  final double demandCharges;
  final double facCharges;
  final double wheelingCharges;
  final double electricityDuty;
  final double taxes;
  final double pfRebate;
  final double pfSurcharge;
  final double subsidy;
  final double netBill;
  final double billingDemand;
  final double loadFactor;
  final double avgUnitCost;
  final double multiplyingFactor;

  const EnergyLogModel({
    required this.id,
    required this.meterName,
    required this.kwh,
    required this.kvah,
    this.currentKwh,
    this.currentKvah,
    required this.rkvarhLag,
    required this.rkvarhLead,
    required this.powerFactor,
    required this.mdRecorded,
    required this.contractDemand,
    required this.estimatedBill,
    required this.loggedAt,
    this.isSynced = false,
    this.userId,
    this.energyCharges = 0,
    this.demandCharges = 0,
    this.facCharges = 0,
    this.wheelingCharges = 0,
    this.electricityDuty = 0,
    this.taxes = 0,
    this.pfRebate = 0,
    this.pfSurcharge = 0,
    this.subsidy = 0,
    this.netBill = 0,
    this.billingDemand = 0,
    this.loadFactor = 0,
    this.avgUnitCost = 0,
    this.multiplyingFactor = 1.0,
  });

  EnergyLogEntity toEntity() => EnergyLogEntity(
    id: id,
    meterName: meterName,
    kwh: kwh,
    kvah: kvah,
    currentKwh: currentKwh,
    currentKvah: currentKvah,
    rkvarhLag: rkvarhLag,
    rkvarhLead: rkvarhLead,
    powerFactor: powerFactor,
    mdRecorded: mdRecorded,
    contractDemand: contractDemand,
    estimatedBill: estimatedBill,
    loggedAt: loggedAt,
    isSynced: isSynced,
    userId: userId,
    energyCharges: energyCharges,
    demandCharges: demandCharges,
    facCharges: facCharges,
    wheelingCharges: wheelingCharges,
    electricityDuty: electricityDuty,
    taxes: taxes,
    pfRebate: pfRebate,
    pfSurcharge: pfSurcharge,
    subsidy: subsidy,
    netBill: netBill,
    billingDemand: billingDemand,
    loadFactor: loadFactor,
    avgUnitCost: avgUnitCost,
    multiplyingFactor: multiplyingFactor,
  );

  factory EnergyLogModel.fromEntity(EnergyLogEntity entity) => EnergyLogModel(
    id: entity.id,
    meterName: entity.meterName,
    kwh: entity.kwh,
    kvah: entity.kvah,
    currentKwh: entity.currentKwh,
    currentKvah: entity.currentKvah,
    rkvarhLag: entity.rkvarhLag,
    rkvarhLead: entity.rkvarhLead,
    powerFactor: entity.powerFactor,
    mdRecorded: entity.mdRecorded,
    contractDemand: entity.contractDemand,
    estimatedBill: entity.estimatedBill,
    loggedAt: entity.loggedAt,
    isSynced: entity.isSynced,
    userId: entity.userId,
    energyCharges: entity.energyCharges,
    demandCharges: entity.demandCharges,
    facCharges: entity.facCharges,
    wheelingCharges: entity.wheelingCharges,
    electricityDuty: entity.electricityDuty,
    taxes: entity.taxes,
    pfRebate: entity.pfRebate,
    pfSurcharge: entity.pfSurcharge,
    subsidy: entity.subsidy,
    netBill: entity.netBill,
    billingDemand: entity.billingDemand,
    loadFactor: entity.loadFactor,
    avgUnitCost: entity.avgUnitCost,
    multiplyingFactor: entity.multiplyingFactor,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'meter_name': meterName,
    'kwh': _toPrecision(kwh, 2),
    'kvah': _toPrecision(kvah, 2),
    if (currentKwh != null) 'current_kwh': _toPrecision(currentKwh!, 2),
    if (currentKvah != null) 'current_kvah': _toPrecision(currentKvah!, 2),
    'rkvarh_lag': _toPrecision(rkvarhLag, 2),
    'rkvarh_lead': _toPrecision(rkvarhLead, 2),
    'power_factor': _toPrecision(powerFactor, 3),
    'md_recorded': _toPrecision(mdRecorded, 2),
    'contract_demand': _toPrecision(contractDemand, 2),
    'estimated_bill': _toPrecision(estimatedBill, 2),
    'logged_at': loggedAt.toUtc().toIso8601String(),
    'is_synced': isSynced,
    if (userId != null) 'user_id': userId,
    'energy_charges': _toPrecision(energyCharges, 2),
    'demand_charges': _toPrecision(demandCharges, 2),
    'fac_charges': _toPrecision(facCharges, 2),
    'wheeling_charges': _toPrecision(wheelingCharges, 2),
    'electricity_duty': _toPrecision(electricityDuty, 2),
    'taxes': _toPrecision(taxes, 2),
    'pf_rebate': _toPrecision(pfRebate, 2),
    'pf_surcharge': _toPrecision(pfSurcharge, 2),
    'subsidy': _toPrecision(subsidy, 2),
    'net_bill': _toPrecision(netBill, 2),
    'billing_demand': _toPrecision(billingDemand, 2),
    'load_factor': _toPrecision(loadFactor, 4),
    'avg_unit_cost': _toPrecision(avgUnitCost, 2),
    'multiplying_factor': _toPrecision(multiplyingFactor, 4),
  };

  factory EnergyLogModel.fromMap(Map<String, Object?> map) {
    return EnergyLogModel(
      id: map['id'] as String,
      meterName: map['meter_name'] as String,
      kwh: _parseDouble(map['kwh']),
      kvah: _parseDouble(map['kvah']),
      currentKwh: _parseNullableDouble(map['current_kwh']),
      currentKvah: _parseNullableDouble(map['current_kvah']),
      rkvarhLag: _parseDouble(map['rkvarh_lag']),
      rkvarhLead: _parseDouble(map['rkvarh_lead']),
      powerFactor: _parseDouble(map['power_factor']),
      mdRecorded: _parseDouble(map['md_recorded']),
      contractDemand: _parseDouble(map['contract_demand']),
      estimatedBill: _parseDouble(map['estimated_bill']),
      loggedAt: DateTime.parse(map['logged_at'] as String).toLocal(),
      isSynced: map['is_synced'] == true || map['is_synced'] == 1,
      userId: map['user_id'] as String?,
      energyCharges: _parseDouble(map['energy_charges']),
      demandCharges: _parseDouble(map['demand_charges']),
      facCharges: _parseDouble(map['fac_charges']),
      wheelingCharges: _parseDouble(map['wheeling_charges']),
      electricityDuty: _parseDouble(map['electricity_duty']),
      taxes: _parseDouble(map['taxes']),
      pfRebate: _parseDouble(map['pf_rebate']),
      pfSurcharge: _parseDouble(map['pf_surcharge']),
      subsidy: _parseDouble(map['subsidy']),
      netBill: _parseDouble(map['net_bill']),
      billingDemand: _parseDouble(map['billing_demand']),
      loadFactor: _parseDouble(map['load_factor']),
      avgUnitCost: _parseDouble(map['avg_unit_cost']),
      multiplyingFactor: _parseDouble(map['multiplying_factor']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'meter_name': meterName,
    'kwh': (kwh * 100).round() / 100,
    'kvah': (kvah * 100).round() / 100,
    if (currentKwh != null) 'current_kwh': (currentKwh! * 100).round() / 100,
    if (currentKvah != null) 'current_kvah': (currentKvah! * 100).round() / 100,
    'rkvarh_lag': (rkvarhLag * 100).round() / 100,
    'rkvarh_lead': (rkvarhLead * 100).round() / 100,
    'power_factor': (powerFactor * 1000).round() / 1000,
    'md_recorded': (mdRecorded * 100).round() / 100,
    'contract_demand': (contractDemand * 100).round() / 100,
    'estimated_bill': (estimatedBill * 100).round() / 100,
    'logged_at': loggedAt.toUtc().toIso8601String(),
    if (userId != null) 'user_id': userId,
    'energy_charges': (energyCharges * 100).round() / 100,
    'demand_charges': (demandCharges * 100).round() / 100,
    'fac_charges': (facCharges * 100).round() / 100,
    'wheeling_charges': (wheelingCharges * 100).round() / 100,
    'electricity_duty': (electricityDuty * 100).round() / 100,
    'taxes': (taxes * 100).round() / 100,
    'pf_rebate': (pfRebate * 100).round() / 100,
    'pf_surcharge': (pfSurcharge * 100).round() / 100,
    'subsidy': (subsidy * 100).round() / 100,
    'net_bill': (netBill * 100).round() / 100,
    'billing_demand': (billingDemand * 100).round() / 100,
    'load_factor': (loadFactor * 1000).round() / 1000,
    'avg_unit_cost': (avgUnitCost * 100).round() / 100,
    'multiplying_factor': (multiplyingFactor * 1000).round() / 1000,
  };

  factory EnergyLogModel.fromJson(Map<String, dynamic> json) {
    return EnergyLogModel(
      id: json['id'] as String,
      meterName: json['meter_name'] as String,
      kwh: (json['kwh'] as num).toDouble(),
      kvah: (json['kvah'] as num).toDouble(),
      currentKwh: (json['current_kwh'] as num?)?.toDouble(),
      currentKvah: (json['current_kvah'] as num?)?.toDouble(),
      rkvarhLag: (json['rkvarh_lag'] as num).toDouble(),
      rkvarhLead: (json['rkvarh_lead'] as num).toDouble(),
      powerFactor: (json['power_factor'] as num).toDouble(),
      mdRecorded: (json['md_recorded'] as num).toDouble(),
      contractDemand: (json['contract_demand'] as num).toDouble(),
      estimatedBill: (json['estimated_bill'] as num).toDouble(),
      loggedAt: DateTime.parse(json['logged_at'] as String).toLocal(),
      userId: json['user_id'] as String?,
      energyCharges: (json['energy_charges'] as num?)?.toDouble() ?? 0,
      demandCharges: (json['demand_charges'] as num?)?.toDouble() ?? 0,
      facCharges: (json['fac_charges'] as num?)?.toDouble() ?? 0,
      wheelingCharges: (json['wheeling_charges'] as num?)?.toDouble() ?? 0,
      electricityDuty: (json['electricity_duty'] as num?)?.toDouble() ?? 0,
      taxes: (json['taxes'] as num?)?.toDouble() ?? 0,
      pfRebate: (json['pf_rebate'] as num?)?.toDouble() ?? 0,
      pfSurcharge: (json['pf_surcharge'] as num?)?.toDouble() ?? 0,
      subsidy: (json['subsidy'] as num?)?.toDouble() ?? 0,
      netBill: (json['net_bill'] as num?)?.toDouble() ?? 0,
      billingDemand: (json['billing_demand'] as num?)?.toDouble() ?? 0,
      loadFactor: (json['load_factor'] as num?)?.toDouble() ?? 0,
      avgUnitCost: (json['avg_unit_cost'] as num?)?.toDouble() ?? 0,
      multiplyingFactor:
          (json['multiplying_factor'] as num?)?.toDouble() ?? 1.0,
    );
  }

  factory EnergyLogModel.create({
    String? id,
    required String meterName,
    required double kwh,
    required double kvah,
    double? currentKwh,
    double? currentKvah,
    double rkvarhLag = 0,
    double rkvarhLead = 0,
    double? powerFactor,
    required double mdRecorded,
    double contractDemand = AppConstants.defaultContractDemandKva,
    DateTime? loggedAt,
    String? userId,
    bool isSynced = false,
    double multiplyingFactor = AppConstants.multiplyingFactor,
  }) {
    final pf = powerFactor ?? CalculationEngine.calculatePowerFactor(kwh, kvah);
    final totalUnits = kwh * multiplyingFactor;
    final billingDemand = CalculationEngine.calculateBillingDemand(
      mdRecorded * multiplyingFactor,
      contractDemand,
    );

    final energyCharges = CalculationEngine.calculateEnergyCharges(
      totalUnits,
      AppConfig.tariffPerUnit,
    );
    final demandCharges = CalculationEngine.calculateDemandCharges(
      billingDemand,
      AppConfig.demandChargePerKva,
    );
    final facCharges = CalculationEngine.calculateFac(
      totalUnits,
      AppConfig.facRatePerUnit,
    );
    final wheelingCharges = CalculationEngine.calculateWheelingCharges(
      totalUnits,
      AppConfig.wheelingChargePerUnit,
    );

    final subtotal =
        energyCharges + demandCharges + facCharges + wheelingCharges;
    final electricityDuty = AppConfig.dutyPercent > 0
        ? energyCharges * AppConfig.dutyPercent / 100
        : CalculationEngine.calculateElectricityDuty(
            totalUnits,
            AppConfig.electricityDutyPerUnit,
          );
    final taxes = AppConfig.taxPercent > 0
        ? energyCharges * AppConfig.taxPercent / 100
        : CalculationEngine.calculateTaxes(
            totalUnits,
            AppConfig.taxPerUnit,
          );

    final pfRebate = CalculationEngine.calculatePfRebate(
      energyCharges,
      demandCharges,
      pf,
    );
    final pfSurcharge = CalculationEngine.calculatePfSurcharge(
      energyCharges,
      demandCharges,
      pf,
    );
    final subsidy = AppConfig.subsidyPercent > 0
        ? subtotal * AppConfig.subsidyPercent / 100
        : 0.0;

    final netBill =
        energyCharges +
        demandCharges +
        facCharges +
        wheelingCharges +
        electricityDuty +
        taxes +
        pfSurcharge -
        pfRebate -
        subsidy;

    final avgUnitCost = totalUnits > 0 ? netBill / totalUnits : 0.0;

    final bill = CalculationEngine.calculateEstimatedBill(
      kwh: kwh,
      mdRecorded: mdRecorded,
      powerFactor: pf,
      multiplyingFactor: multiplyingFactor,
    );
    final uid = userId ?? _tryGetCurrentUserId();

    return EnergyLogModel(
      id: id ?? const Uuid().v4(),
      meterName: meterName,
      kwh: (kwh * 100).round() / 100,
      kvah: (kvah * 100).round() / 100,
      currentKwh: currentKwh == null ? null : (currentKwh * 100).round() / 100,
      currentKvah:
          currentKvah == null ? null : (currentKvah * 100).round() / 100,
      rkvarhLag: (rkvarhLag * 100).round() / 100,
      rkvarhLead: (rkvarhLead * 100).round() / 100,
      powerFactor: (pf * 1000).round() / 1000,
      mdRecorded: (mdRecorded * 100).round() / 100,
      contractDemand: (contractDemand * 100).round() / 100,
      estimatedBill: (bill * 100).round() / 100,
      loggedAt: loggedAt ?? DateTime.now(),
      isSynced: isSynced,
      userId: uid,
      energyCharges: (energyCharges * 100).round() / 100,
      demandCharges: (demandCharges * 100).round() / 100,
      facCharges: (facCharges * 100).round() / 100,
      wheelingCharges: (wheelingCharges * 100).round() / 100,
      electricityDuty: (electricityDuty * 100).round() / 100,
      taxes: (taxes * 100).round() / 100,
      pfRebate: (pfRebate * 100).round() / 100,
      pfSurcharge: (pfSurcharge * 100).round() / 100,
      subsidy: (subsidy * 100).round() / 100,
      netBill: (netBill * 100).round() / 100,
      billingDemand: (billingDemand * 100).round() / 100,
      loadFactor: 0,
      avgUnitCost: (avgUnitCost * 100).round() / 100,
      multiplyingFactor: (multiplyingFactor * 1000).round() / 1000,
    );
  }

  /// Fills [currentKwh]/[currentKvah] for legacy rows that have no stored
  /// actual reading, using the running sum of consumed values per meter in
  /// date order — i.e. the meter's cumulative value AT that entry. Rows with
  /// stored actual readings are left untouched.
  ///
  /// When a meter has rows WITH stored readings, those act as anchors: legacy
  /// rows after an anchor continue from the anchor value (the consumed chain
  /// alone would drift, because meters don't start from zero).
  ///
  /// Legacy rows before any anchor are summed from zero (best effort — the
  /// true opening reading is not in the DB).
  static List<EnergyLogModel> hydrateActualReadings(
    List<EnergyLogModel> logs,
  ) {
    final sorted = List<EnergyLogModel>.of(logs)
      ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    final anchorKwh = <String, double>{};
    final anchorKvah = <String, double>{};
    final tailKwh = <String, double>{};
    final tailKvah = <String, double>{};
    return sorted.map((m) {
      final kwhAt = m.currentKwh ??
          (anchorKwh[m.meterName] ?? 0) + (tailKwh[m.meterName] ?? 0) + m.kwh;
      final kvahAt = m.currentKvah ??
          (anchorKvah[m.meterName] ?? 0) + (tailKvah[m.meterName] ?? 0) +
              m.kvah;
      if (m.currentKwh != null) {
        anchorKwh[m.meterName] = m.currentKwh!;
        tailKwh[m.meterName] = 0;
      } else {
        tailKwh[m.meterName] = (tailKwh[m.meterName] ?? 0) + m.kwh;
      }
      if (m.currentKvah != null) {
        anchorKvah[m.meterName] = m.currentKvah!;
        tailKvah[m.meterName] = 0;
      } else {
        tailKvah[m.meterName] = (tailKvah[m.meterName] ?? 0) + m.kvah;
      }
      if (m.currentKwh != null && m.currentKvah != null) return m;
      return EnergyLogModel(
        id: m.id,
        meterName: m.meterName,
        kwh: m.kwh,
        kvah: m.kvah,
        currentKwh: kwhAt,
        currentKvah: kvahAt,
        rkvarhLag: m.rkvarhLag,
        rkvarhLead: m.rkvarhLead,
        powerFactor: m.powerFactor,
        mdRecorded: m.mdRecorded,
        contractDemand: m.contractDemand,
        estimatedBill: m.estimatedBill,
        loggedAt: m.loggedAt,
        isSynced: m.isSynced,
        userId: m.userId,
        energyCharges: m.energyCharges,
        demandCharges: m.demandCharges,
        facCharges: m.facCharges,
        wheelingCharges: m.wheelingCharges,
        electricityDuty: m.electricityDuty,
        taxes: m.taxes,
        pfRebate: m.pfRebate,
        pfSurcharge: m.pfSurcharge,
        subsidy: m.subsidy,
        netBill: m.netBill,
        billingDemand: m.billingDemand,
        loadFactor: m.loadFactor,
        avgUnitCost: m.avgUnitCost,
        multiplyingFactor: m.multiplyingFactor,
      );
    }).toList();
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

  static double? _parseNullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static double _toPrecision(double value, int decimals) {
    final factor = pow(10, decimals).toDouble();
    return (value * factor).round() / factor;
  }
}
