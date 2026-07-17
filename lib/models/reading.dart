class Reading {
  final String id;
  final String meterId;
  final DateTime readingDate;
  final double? kwhImport;
  final double? kwhExport;
  final double? kvahImport;
  final double? kvahExport;
  final double? kwDemand;
  final double? kvaDemand;
  final double? voltageLNAvg;
  final double? currentAvg;
  final double? powerFactor;
  final double? frequency;
  final double? thd;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncPending;

  Reading({
    required this.id,
    required this.meterId,
    required this.readingDate,
    this.kwhImport,
    this.kwhExport,
    this.kvahImport,
    this.kvahExport,
    this.kwDemand,
    this.kvaDemand,
    this.voltageLNAvg,
    this.currentAvg,
    this.powerFactor,
    this.frequency,
    this.thd,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncPending = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'meter_id': meterId,
        'reading_date': readingDate.toIso8601String().substring(0, 10),
        'kwh_import': kwhImport,
        'kwh_export': kwhExport,
        'kvah_import': kvahImport,
        'kvah_export': kvahExport,
        'kw_demand': kwDemand,
        'kva_demand': kvaDemand,
        'voltage_ln_avg': voltageLNAvg,
        'current_avg': currentAvg,
        'power_factor': powerFactor,
        'frequency': frequency,
        'thd': thd,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_pending': syncPending ? 1 : 0,
      };

  factory Reading.fromMap(Map<String, dynamic> map) => Reading(
        id: map['id'] as String,
        meterId: map['meter_id'] as String,
        readingDate: DateTime.parse(map['reading_date'] as String),
        kwhImport: (map['kwh_import'] as num?)?.toDouble(),
        kwhExport: (map['kwh_export'] as num?)?.toDouble(),
        kvahImport: (map['kvah_import'] as num?)?.toDouble(),
        kvahExport: (map['kvah_export'] as num?)?.toDouble(),
        kwDemand: (map['kw_demand'] as num?)?.toDouble(),
        kvaDemand: (map['kva_demand'] as num?)?.toDouble(),
        voltageLNAvg: (map['voltage_ln_avg'] as num?)?.toDouble(),
        currentAvg: (map['current_avg'] as num?)?.toDouble(),
        powerFactor: (map['power_factor'] as num?)?.toDouble(),
        frequency: (map['frequency'] as num?)?.toDouble(),
        thd: (map['thd'] as num?)?.toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncPending: (map['sync_pending'] as int?) == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'meter_id': meterId,
        'reading_date': readingDate.toIso8601String().substring(0, 10),
        'kwh_import': kwhImport,
        'kwh_export': kwhExport,
        'kvah_import': kvahImport,
        'kvah_export': kvahExport,
        'kw_demand': kwDemand,
        'kva_demand': kvaDemand,
        'voltage_ln_avg': voltageLNAvg,
        'current_avg': currentAvg,
        'power_factor': powerFactor,
        'frequency': frequency,
        'thd': thd,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Reading.fromJson(Map<String, dynamic> json) => Reading(
        id: json['id'] as String,
        meterId: json['meter_id'] as String,
        readingDate: DateTime.parse(json['reading_date'] as String),
        kwhImport: (json['kwh_import'] as num?)?.toDouble(),
        kwhExport: (json['kwh_export'] as num?)?.toDouble(),
        kvahImport: (json['kvah_import'] as num?)?.toDouble(),
        kvahExport: (json['kvah_export'] as num?)?.toDouble(),
        kwDemand: (json['kw_demand'] as num?)?.toDouble(),
        kvaDemand: (json['kva_demand'] as num?)?.toDouble(),
        voltageLNAvg: (json['voltage_ln_avg'] as num?)?.toDouble(),
        currentAvg: (json['current_avg'] as num?)?.toDouble(),
        powerFactor: (json['power_factor'] as num?)?.toDouble(),
        frequency: (json['frequency'] as num?)?.toDouble(),
        thd: (json['thd'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

extension ReadingCalculations on Reading {
  double get kvaCalculated {
    if (kwDemand != null && powerFactor != null && powerFactor! > 0) {
      return kwDemand! / powerFactor!;
    }
    return kvaDemand ?? 0;
  }

  double get kvahCalculated {
    if (kwhImport != null && powerFactor != null && powerFactor! > 0) {
      return kwhImport! / powerFactor!;
    }
    return kvahImport ?? 0;
  }

  double get loadFactor {
    if (kvaDemand != null && kvaDemand! > 0) {
      return (kwDemand ?? 0) / kvaDemand!;
    }
    return 0;
  }
}
