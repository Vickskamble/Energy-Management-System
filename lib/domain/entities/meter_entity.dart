class MeterEntity {
  final String id;
  final String name;
  final String? location;
  final double contractDemandKw;
  final bool isActive;
  final double ctRatio;
  final double ptRatio;
  final String site;

  const MeterEntity({
    required this.id,
    required this.name,
    this.location,
    this.contractDemandKw = 400.0,
    this.isActive = true,
    this.ctRatio = 1.0,
    this.ptRatio = 1.0,
    this.site = 'Main Site',
  });

  /// Multiplying factor = CT ratio × PT ratio (defaults to 1 when unset).
  double get multiplyingFactor => ctRatio * ptRatio;
}
