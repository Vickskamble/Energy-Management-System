class MeterEntity {
  final String id;
  final String name;
  final String? location;
  final double contractDemandKw;
  final bool isActive;

  const MeterEntity({
    required this.id,
    required this.name,
    this.location,
    this.contractDemandKw = 400.0,
    this.isActive = true,
  });
}
