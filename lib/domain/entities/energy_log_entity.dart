class EnergyLogEntity {
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

  const EnergyLogEntity({
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

  EnergyLogEntity copyWith({
    String? id,
    String? meterName,
    double? kwh,
    double? kvah,
    double? rkvarhLag,
    double? rkvarhLead,
    double? powerFactor,
    double? mdRecorded,
    double? contractDemand,
    double? estimatedBill,
    DateTime? loggedAt,
    bool? isSynced,
    String? userId,
  }) {
    return EnergyLogEntity(
      id: id ?? this.id,
      meterName: meterName ?? this.meterName,
      kwh: kwh ?? this.kwh,
      kvah: kvah ?? this.kvah,
      rkvarhLag: rkvarhLag ?? this.rkvarhLag,
      rkvarhLead: rkvarhLead ?? this.rkvarhLead,
      powerFactor: powerFactor ?? this.powerFactor,
      mdRecorded: mdRecorded ?? this.mdRecorded,
      contractDemand: contractDemand ?? this.contractDemand,
      estimatedBill: estimatedBill ?? this.estimatedBill,
      loggedAt: loggedAt ?? this.loggedAt,
      isSynced: isSynced ?? this.isSynced,
      userId: userId ?? this.userId,
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
      'kvah: $kvah, pf: $powerFactor, md: $mdRecorded, '
      'bill: $estimatedBill, synced: $isSynced)';
}
