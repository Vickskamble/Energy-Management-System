enum AnalysisType {
  highLoad,
  contractDemandExceeded,
  powerFactorIssue,
  voltageIssue,
  currentUnbalance,
  harmonicIssue,
  anomaly,
  energySaving,
  general,
}

enum Severity { low, medium, high, critical }

class AnalysisResult {
  final String id;
  final String? siteId;
  final String? panelId;
  final String? meterId;
  final String? readingId;
  final AnalysisType type;
  final Severity severity;
  final String title;
  final String description;
  final String? recommendation;
  final Map<String, dynamic>? metrics;
  final DateTime createdAt;
  final bool syncPending;

  AnalysisResult({
    required this.id,
    this.siteId,
    this.panelId,
    this.meterId,
    this.readingId,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.recommendation,
    this.metrics,
    DateTime? createdAt,
    this.syncPending = true,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'site_id': siteId,
        'panel_id': panelId,
        'meter_id': meterId,
        'reading_id': readingId,
        'type': type.name,
        'severity': severity.name,
        'title': title,
        'description': description,
        'recommendation': recommendation,
        'metrics': metrics != null ? _encodeMetrics(metrics!) : null,
        'created_at': createdAt.toIso8601String(),
        'sync_pending': syncPending ? 1 : 0,
      };

  factory AnalysisResult.fromMap(Map<String, dynamic> map) => AnalysisResult(
        id: map['id'] as String,
        siteId: map['site_id'] as String?,
        panelId: map['panel_id'] as String?,
        meterId: map['meter_id'] as String?,
        readingId: map['reading_id'] as String?,
        type: AnalysisType.values.firstWhere(
            (e) => e.name == map['type'],
            orElse: () => AnalysisType.general),
        severity: Severity.values.firstWhere(
            (e) => e.name == map['severity'],
            orElse: () => Severity.medium),
        title: map['title'] as String,
        description: map['description'] as String,
        recommendation: map['recommendation'] as String?,
        metrics: map['metrics'] != null
            ? _decodeMetrics(map['metrics'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        syncPending: (map['sync_pending'] as int?) == 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'site_id': siteId,
        'panel_id': panelId,
        'meter_id': meterId,
        'reading_id': readingId,
        'type': type.name,
        'severity': severity.name,
        'title': title,
        'description': description,
        'recommendation': recommendation,
        'metrics': metrics,
        'created_at': createdAt.toIso8601String(),
      };

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
        id: json['id'] as String,
        siteId: json['site_id'] as String?,
        panelId: json['panel_id'] as String?,
        meterId: json['meter_id'] as String?,
        readingId: json['reading_id'] as String?,
        type: AnalysisType.values.firstWhere(
            (e) => e.name == json['type'],
            orElse: () => AnalysisType.general),
        severity: Severity.values.firstWhere(
            (e) => e.name == json['severity'],
            orElse: () => Severity.medium),
        title: json['title'] as String,
        description: json['description'] as String,
        recommendation: json['recommendation'] as String?,
        metrics: json['metrics'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  static String _encodeMetrics(Map<String, dynamic> metrics) =>
      metrics.entries.map((e) => '${e.key}:${e.value}').join('|');

  static Map<String, dynamic> _decodeMetrics(String encoded) {
    final map = <String, dynamic>{};
    for (final pair in encoded.split('|')) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        map[parts[0]] = parts[1];
      }
    }
    return map;
  }
}
