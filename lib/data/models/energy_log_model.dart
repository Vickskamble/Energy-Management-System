import 'dart:math';
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
      );

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
    );
  }

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
    );
  }

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
    final pf = powerFactor ?? CalculationEngine.calculatePowerFactor(kwh, kvah);
    final totalUnits = kwh * AppConstants.multiplyingFactor;
    final billingDemand = CalculationEngine.calculateBillingDemand(mdRecorded, contractDemand);

    final energyCharges = CalculationEngine.calculateEnergyCharges(totalUnits, AppConstants.tariffPerUnit);
    final demandCharges = CalculationEngine.calculateDemandCharges(billingDemand, AppConstants.demandChargePerKva);
    final facCharges = CalculationEngine.calculateFac(totalUnits, AppConstants.facRatePerUnit);
    final wheelingCharges = CalculationEngine.calculateWheelingCharges(totalUnits, AppConstants.wheelingChargePerUnit);

    final subtotal = energyCharges + demandCharges + facCharges + wheelingCharges;
    final electricityDuty = CalculationEngine.calculateElectricityDuty(subtotal, AppConstants.electricityDutyPercent);
    final taxes = CalculationEngine.calculateTaxes(subtotal + electricityDuty, AppConstants.taxPercent);

    final pfRebate = CalculationEngine.calculatePfRebate(energyCharges, demandCharges, pf);
    final pfSurcharge = CalculationEngine.calculatePfSurcharge(energyCharges, demandCharges, pf);
    final subsidy = AppConstants.subsidyPercent > 0 ? subtotal * AppConstants.subsidyPercent / 100 : 0.0;

    final netBill = energyCharges + demandCharges + facCharges + wheelingCharges +
        electricityDuty + taxes + pfSurcharge - pfRebate - subsidy;

    final avgUnitCost = totalUnits > 0 ? netBill / totalUnits : 0.0;

    final bill = CalculationEngine.calculateEstimatedBill(kwh: kwh, mdRecorded: mdRecorded, powerFactor: pf);
    final uid = userId ?? _tryGetCurrentUserId();

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
    final factor = pow(10, decimals).toDouble();
    return (value * factor).round() / factor;
  }
}
