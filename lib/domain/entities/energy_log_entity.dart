class EnergyLogEntity {
  final String id;
  final String meterName;
  final double kwh;
  final double kvah;

  /// ACTUAL (cumulative) meter reading this entry was recorded against.
  /// Null for legacy rows — hydrate reads it as the running sum of consumed.
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

  /// Export (solar) consumption in kWh — raw meter diff, before MF.
  /// Null for non-solar consumers.
  final double? exportKwh;

  /// Export (solar) consumption in kVAh — raw meter diff, before MF.
  final double? exportKvah;

  /// Total solar generation in kWh — raw meter diff, before MF.
  /// May exceed [exportKwh] when some generation is self-consumed.
  final double? generationKwh;

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

  /// ACTUAL demand in kVA — the raw MD recorded by the meter (Excel/manual)
  /// scaled by the meter's multiplying factor (CT/PT ratio). All displays and
  /// calculations use this value; [mdRecorded] stays the raw meter reading.
  double get actualMd => mdRecorded * multiplyingFactor;

  const EnergyLogEntity({
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
    this.exportKwh,
    this.exportKvah,
    this.generationKwh,
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

  EnergyLogEntity copyWith({
    String? id,
    String? meterName,
    double? kwh,
    double? kvah,
    double? currentKwh,
    double? currentKvah,
    double? rkvarhLag,
    double? rkvarhLead,
    double? powerFactor,
    double? mdRecorded,
    double? contractDemand,
    double? estimatedBill,
    DateTime? loggedAt,
    bool? isSynced,
    String? userId,
    double? exportKwh,
    double? exportKvah,
    double? generationKwh,
    double? multiplyingFactor,
    double? energyCharges,
    double? demandCharges,
    double? facCharges,
    double? wheelingCharges,
    double? electricityDuty,
    double? taxes,
    double? pfRebate,
    double? pfSurcharge,
    double? subsidy,
    double? netBill,
    double? billingDemand,
    double? loadFactor,
    double? avgUnitCost,
  }) {
    return EnergyLogEntity(
      id: id ?? this.id,
      meterName: meterName ?? this.meterName,
      kwh: kwh ?? this.kwh,
      kvah: kvah ?? this.kvah,
      currentKwh: currentKwh ?? this.currentKwh,
      currentKvah: currentKvah ?? this.currentKvah,
      rkvarhLag: rkvarhLag ?? this.rkvarhLag,
      rkvarhLead: rkvarhLead ?? this.rkvarhLead,
      powerFactor: powerFactor ?? this.powerFactor,
      mdRecorded: mdRecorded ?? this.mdRecorded,
      contractDemand: contractDemand ?? this.contractDemand,
      estimatedBill: estimatedBill ?? this.estimatedBill,
      loggedAt: loggedAt ?? this.loggedAt,
      isSynced: isSynced ?? this.isSynced,
      userId: userId ?? this.userId,
      exportKwh: exportKwh ?? this.exportKwh,
      exportKvah: exportKvah ?? this.exportKvah,
      generationKwh: generationKwh ?? this.generationKwh,
      energyCharges: energyCharges ?? this.energyCharges,
      demandCharges: demandCharges ?? this.demandCharges,
      facCharges: facCharges ?? this.facCharges,
      wheelingCharges: wheelingCharges ?? this.wheelingCharges,
      electricityDuty: electricityDuty ?? this.electricityDuty,
      taxes: taxes ?? this.taxes,
      pfRebate: pfRebate ?? this.pfRebate,
      pfSurcharge: pfSurcharge ?? this.pfSurcharge,
      subsidy: subsidy ?? this.subsidy,
      netBill: netBill ?? this.netBill,
      billingDemand: billingDemand ?? this.billingDemand,
      loadFactor: loadFactor ?? this.loadFactor,
      avgUnitCost: avgUnitCost ?? this.avgUnitCost,
      multiplyingFactor: multiplyingFactor ?? this.multiplyingFactor,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnergyLogEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'EnergyLogEntity(id: $id, meterName: $meterName, kwh: $kwh, '
      'kvah: $kvah, currentKwh: $currentKwh, currentKvah: $currentKvah, '
      'pf: $powerFactor, md: $mdRecorded, '
      'bill: $estimatedBill, synced: $isSynced)';
}
