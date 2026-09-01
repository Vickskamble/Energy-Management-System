import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ems/core/utils/pdf_report_service.dart';
import 'package:ems/domain/entities/energy_log_entity.dart';

EnergyLogEntity log({
  required int id,
  required int day,
  int hour = 10,
  double kwh = 100,
  double kvah = 105,
  double md = 22,
}) => EnergyLogEntity(
      id: 'r$id',
      meterName: 'MainFeeder',
      kwh: kwh,
      kvah: kvah,
      rkvarhLag: 0,
      rkvarhLead: 0,
      powerFactor: kvah > 0 ? kwh / kvah : 0,
      mdRecorded: md,
      contractDemand: 201,
      estimatedBill: 0,
      loggedAt: DateTime(2026, 8, day, hour),
      multiplyingFactor: 5,
    );

Future<Uint8List> buildFull({required List<EnergyLogEntity> logs}) async {
  final doc = PdfReportService.buildDocument(
    logs: logs,
    title: 'Energy Management Report',
    subtitle: '${logs.length} reading(s)',
  );
  return doc.save();
}

void main() {
  test('full report renders with a realistic 31-day month (low-PF days incl.)',
      () async {
    final logs = <EnergyLogEntity>[
      for (var day = 1; day <= 31; day++)
        // PF cycles 0.81 → 1.00 across the month (several low-PF days) like
        // the real customer data that triggered the failure.
        log(
          id: day,
          day: day,
          kwh: 90 + (day % 6) * 3,
          kvah: (90 + (day % 6) * 3) / (0.81 + (day % 16) * 0.012),
          md: 20 + (day % 5),
        ),
    ];
    final bytes = await buildFull(logs: logs);
    expect(bytes.length, greaterThan(20000));
  });

  test('full report renders with a single reading', () async {
    final bytes = await buildFull(logs: [log(id: 1, day: 15)]);
    expect(bytes.length, greaterThan(5000));
  });

  test('full report renders with two readings on the SAME calendar day',
      () async {
    final bytes = await buildFull(logs: [
      log(id: 1, day: 15, hour: 8),
      log(id: 2, day: 15, hour: 18),
    ]);
    expect(bytes.length, greaterThan(5000));
  });

  test('full report renders with two readings across two days', () async {
    final bytes = await buildFull(logs: [
      log(id: 1, day: 2),
      log(id: 2, day: 28),
    ]);
    expect(bytes.length, greaterThan(5000));
  });
}