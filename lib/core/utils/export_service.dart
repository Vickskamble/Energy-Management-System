import 'package:intl/intl.dart';
import '../../domain/entities/energy_log_entity.dart';
import 'export_service_io.dart'
    if (dart.library.js_interop) 'export_service_web.dart'
    as save;

class ExportService {
  Future<void> exportCsv(List<EnergyLogEntity> logs) async {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final buffer = StringBuffer();

    buffer.writeln(
      'ID,Meter,Reading kWh,Consumed kWh,Reading kVAh,Consumed kVAh,Power Factor,MD (kW),Contract Demand (kW),Est. Bill (₹),Logged At,Synced',
    );

    for (final log in logs) {
      buffer.writeln(
        [
          _escapeCsv(log.id),
          _escapeCsv(log.meterName),
          log.currentKwh?.toStringAsFixed(2) ?? '',
          log.kwh.toStringAsFixed(2),
          log.currentKvah?.toStringAsFixed(2) ?? '',
          log.kvah.toStringAsFixed(2),
          log.powerFactor.toStringAsFixed(3),
          (log.mdRecorded * log.multiplyingFactor).toStringAsFixed(2),
          log.contractDemand.toStringAsFixed(2),
          log.estimatedBill.toStringAsFixed(2),
          _escapeCsv(dateFmt.format(log.loggedAt)),
          log.isSynced ? 'Yes' : 'No',
        ].join(','),
      );
    }

    await save.saveCsv(buffer.toString(), 'ems_readings_export.csv');
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
