import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/energy_log_entity.dart';

class ExportService {
  Future<void> exportCsv(List<EnergyLogEntity> logs) async {
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');
    final buffer = StringBuffer();

    buffer.writeln(
      'ID,Meter,kWh,kVAh,Power Factor,MD (kW),Contract Demand (kW),Est. Bill (₹),Logged At,Synced',
    );

    for (final log in logs) {
      buffer.writeln(
        [
          _escapeCsv(log.id),
          _escapeCsv(log.meterName),
          log.kwh.toStringAsFixed(2),
          log.kvah.toStringAsFixed(2),
          log.powerFactor.toStringAsFixed(3),
          log.mdRecorded.toStringAsFixed(2),
          log.contractDemand.toStringAsFixed(2),
          log.estimatedBill.toStringAsFixed(2),
          _escapeCsv(dateFmt.format(log.loggedAt)),
          log.isSynced ? 'Yes' : 'No',
        ].join(','),
      );
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ems_readings_export.csv');
    await file.writeAsString(buffer.toString());

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'EMS Readings Export'),
    );
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
