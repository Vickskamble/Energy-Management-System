import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../core/database/database_helper.dart';

enum ReportFormat { csv, json }

class ReportService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<String> exportReadingsReport({
    required String siteId,
    ReportFormat format = ReportFormat.csv,
  }) async {
    final site = await _db.getSite(siteId);
    if (site == null) throw Exception('Site not found');

    final buffer = StringBuffer();

    if (format == ReportFormat.csv) {
      buffer.writeln(
          'Site,Panel,Meter,Date,KWh Import,KWh Export,KVArh Import,KVArh Export,KW Demand,KVA Demand,Voltage (V),Current (A),Power Factor,Frequency (Hz),THD (%)');
    } else {
      buffer.writeln('[');
    }

    final panels = await _db.getPanels(siteId);
    bool isFirst = true;

    for (final panel in panels) {
      final meters = await _db.getMeters(panel.id);
      for (final meter in meters) {
        final readings = await _db.getReadings(meter.id, limit: 365);

        for (final r in readings) {
          final dateStr =
              DateFormat('yyyy-MM-dd').format(r.readingDate);

          if (format == ReportFormat.csv) {
            buffer.writeln(
                '${_escapeCsv(site.name)},${_escapeCsv(panel.name)},${_escapeCsv(meter.meterNumber)},$dateStr,'
                '${_v(r.kwhImport)},${_v(r.kwhExport)},${_v(r.kvahImport)},${_v(r.kvahExport)},'
                '${_v(r.kwDemand)},${_v(r.kvaDemand)},${_v(r.voltageLNAvg)},${_v(r.currentAvg)},'
                '${_v(r.powerFactor)},${_v(r.frequency)},${_v(r.thd)}');
          } else {
            if (!isFirst) buffer.writeln(',');
            isFirst = false;
            buffer.writeln('  {');
            buffer.writeln('    "site": "${site.name}",');
            buffer.writeln('    "panel": "${panel.name}",');
            buffer.writeln('    "meter": "${meter.meterNumber}",');
            buffer.writeln('    "date": "$dateStr",');
            buffer.writeln('    "kwh_import": ${r.kwhImport ?? 0},');
            buffer.writeln('    "kwh_export": ${r.kwhExport ?? 0},');
            buffer.writeln('    "kvah_import": ${r.kvahImport ?? 0},');
            buffer.writeln('    "kw_demand": ${r.kwDemand ?? 0},');
            buffer.writeln('    "kva_demand": ${r.kvaDemand ?? 0},');
            buffer.writeln('    "voltage": ${r.voltageLNAvg ?? 0},');
            buffer.writeln('    "current": ${r.currentAvg ?? 0},');
            buffer.writeln('    "power_factor": ${r.powerFactor ?? 0},');
            buffer.writeln('    "thd": ${r.thd ?? 0}');
            buffer.write('  }');
          }
        }
      }
    }

    if (format == ReportFormat.json) {
      buffer.writeln();
      buffer.writeln(']');
    }

    return await _saveReport(
        'readings_${site.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}'
        '${format == ReportFormat.csv ? '.csv' : '.json'}',
        buffer.toString());
  }

  Future<String> exportAnalysisReport({
    required String siteId,
    ReportFormat format = ReportFormat.csv,
  }) async {
    final site = await _db.getSite(siteId);
    if (site == null) throw Exception('Site not found');

    final analyses = await _db.getAnalysisResults(siteId: siteId);
    final buffer = StringBuffer();

    if (format == ReportFormat.csv) {
      buffer.writeln('Date,Type,Severity,Title,Description,Recommendation');
      for (final a in analyses) {
        buffer.writeln(
            '${DateFormat('yyyy-MM-dd HH:mm').format(a.createdAt)},'
            '${a.type.name},${a.severity.name},'
            '${_escapeCsv(a.title)},${_escapeCsv(a.description)},${_escapeCsv(a.recommendation ?? '')}');
      }
    } else {
      buffer.writeln('[');
      for (int i = 0; i < analyses.length; i++) {
        final a = analyses[i];
        buffer.writeln('  {');
        buffer.writeln(
            '    "date": "${DateFormat('yyyy-MM-dd HH:mm').format(a.createdAt)}",');
        buffer.writeln('    "type": "${a.type.name}",');
        buffer.writeln('    "severity": "${a.severity.name}",');
        buffer.writeln('    "title": "${a.title}",');
        buffer.writeln('    "description": "${a.description}",');
        buffer.writeln('    "recommendation": "${a.recommendation ?? ""}"');
        buffer.write('  }');
        if (i < analyses.length - 1) buffer.writeln(',');
      }
      buffer.writeln();
      buffer.writeln(']');
    }

    return await _saveReport(
        'analysis_${site.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(DateTime.now())}'
        '${format == ReportFormat.csv ? '.csv' : '.json'}',
        buffer.toString());
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _v(dynamic value) => value?.toStringAsFixed(2) ?? '';

  Future<String> _saveReport(String filename, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    return file.path;
  }
}
