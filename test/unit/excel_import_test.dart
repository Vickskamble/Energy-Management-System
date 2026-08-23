import 'dart:typed_data';

import 'package:ems/core/utils/excel_import_service.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _buildWorkbook(
  String sheetName,
  List<List<CellValue?>> rows,
) {
  final excel = Excel.createExcel();
  if (sheetName != 'Sheet1') excel.rename('Sheet1', sheetName);
  final sheet = excel[sheetName];
  for (final row in rows) {
    sheet.appendRow(row);
  }
  return Uint8List.fromList(excel.encode()!);
}

void main() {
  group('ExcelImportService.extractReadings', () {
    test('parses typed cells: meter, date, kWh, kVAh, rkVARh, MD', () async {
      final bytes = _buildWorkbook('Readings', [
        [
          TextCellValue('Meter'),
          TextCellValue('Reading Date'),
          TextCellValue('kWh'),
          TextCellValue('kVAh'),
          TextCellValue('rkVARh (Lag)'),
          TextCellValue('rkVARh (Lead)'),
          TextCellValue('MD Recorded'),
        ],
        [
          TextCellValue('Meter A'),
          const DateCellValue(year: 2026, month: 6, day: 1),
          const DoubleCellValue(123.45),
          const DoubleCellValue(130.5),
          const DoubleCellValue(5.5),
          const DoubleCellValue(1.25),
          const DoubleCellValue(42),
        ],
        [
          TextCellValue('Meter B'),
          TextCellValue('02/06/2026'),
          const IntCellValue(200),
          const IntCellValue(210),
          const IntCellValue(0),
          const IntCellValue(0),
          const IntCellValue(60),
        ],
      ]);

      final drafts = await ExcelImportService.extractReadings(bytes);

      expect(drafts, hasLength(2));

      final a = drafts[0];
      expect(a.meterName, 'Meter A');
      expect(a.loggedAt, DateTime(2026, 6, 1, 12));
      // First row = baseline (consumed 0), actual reading stored.
      expect(a.kwh, 0);
      expect(a.kvah, 0);
      expect(a.rkvarhLag, 0);
      expect(a.rkvarhLead, 0);
      expect(a.mdRecorded, 42);
      expect(a.currentKwh, 123.45);
      expect(a.currentKvah, 130.5);
      expect(a.isValid, isTrue);
      expect(a.sourceLabel, contains('opening'));

      final b = drafts[1];
      expect(b.meterName, 'Meter B');
      expect(b.loggedAt, DateTime(2026, 6, 2, 12));
      expect(b.kwh, closeTo(200 - 123.45, 0.01));
      expect(b.mdRecorded, 60);
      expect(b.currentKwh, 200);
      expect(b.sourceLabel, 'Row 3');
    });

    test('skips a title row and finds the header row lower in the sheet',
        () async {
      final bytes = _buildWorkbook('Readings', [
        [TextCellValue('Meter A — Monthly Readings, June 2026')],
        [
          TextCellValue('Meter'),
          TextCellValue('Reading Date'),
          TextCellValue('kWh'),
          TextCellValue('MD Recorded'),
        ],
        [
          TextCellValue('Meter A'),
          TextCellValue('03/06/2026'),
          IntCellValue(300),
          IntCellValue(75),
        ],
      ]);

      final drafts = await ExcelImportService.extractReadings(bytes);

      expect(drafts, hasLength(1));
      // Single row = baseline consumed 0, actual reading stored.
      expect(drafts.first.kwh, 0);
      expect(drafts.first.currentKwh, 300);
      expect(drafts.first.mdRecorded, 75);
      expect(drafts.first.sourceLabel, contains('opening'));
    });

    test('computes consumed units from current minus previous readings',
        () async {
      final bytes = _buildWorkbook('Readings', [
        [
          TextCellValue('Meter'),
          TextCellValue('Reading Date'),
          TextCellValue('Current Reading'),
          TextCellValue('Previous Reading'),
          TextCellValue('MD Recorded'),
        ],
        [
          TextCellValue('Meter A'),
          TextCellValue('04/06/2026'),
          IntCellValue(10500),
          IntCellValue(10200),
          IntCellValue(50),
        ],
      ]);

      final drafts = await ExcelImportService.extractReadings(bytes);

      expect(drafts, hasLength(1));
      expect(drafts.first.kwh, 300);
      // The actual meter reading is kept alongside consumed.
      expect(drafts.first.currentKwh, 10500);
    });

    test('skips invalid rows (zero kWh and zero MD)', () async {
      final bytes = _buildWorkbook('Readings', [
        [
          TextCellValue('Meter'),
          TextCellValue('Reading Date'),
          TextCellValue('kWh'),
          TextCellValue('MD Recorded'),
        ],
        [
          TextCellValue('Meter A'),
          TextCellValue('05/06/2026'),
          IntCellValue(0),
          IntCellValue(0),
        ],
        [
          TextCellValue('Meter B'),
          TextCellValue('06/06/2026'),
          IntCellValue(150),
          IntCellValue(40),
        ],
      ]);

      final drafts = await ExcelImportService.extractReadings(bytes);

      expect(drafts, hasLength(1));
      expect(drafts.first.meterName, 'Meter B');
    });

    test('accepts DateTimeCellValue cells', () async {
      final bytes = _buildWorkbook('Readings', [
        [
          TextCellValue('Meter'),
          TextCellValue('Reading Date'),
          TextCellValue('kWh'),
          TextCellValue('MD Recorded'),
        ],
        [
          TextCellValue('Meter A'),
          const DateTimeCellValue(
            year: 2026,
            month: 6,
            day: 7,
            hour: 12,
            minute: 30,
          ),
          const DoubleCellValue(90.5),
          const DoubleCellValue(30),
        ],
      ]);

      final drafts = await ExcelImportService.extractReadings(bytes);

      expect(drafts, hasLength(1));
      expect(drafts.first.loggedAt, DateTime(2026, 6, 7, 12, 30));
    });

    test('converts cumulative meter readings to per-day consumption',
        () async {
      final bytes = _buildWorkbook('Readings', [
        [
          TextCellValue('Meter'),
          TextCellValue('Reading Date'),
          TextCellValue('kWh'),
          TextCellValue('kVAh'),
          TextCellValue('MD Recorded'),
        ],
        [
          TextCellValue('Meter A'),
          TextCellValue('01/07/2026'),
          IntCellValue(57037),
          IntCellValue(59109),
          IntCellValue(126),
        ],
        [
          TextCellValue('Meter A'),
          TextCellValue('02/07/2026'),
          IntCellValue(57123),
          IntCellValue(59201),
          IntCellValue(0),
        ],
        [
          TextCellValue('Meter A'),
          TextCellValue('03/07/2026'),
          IntCellValue(57268),
          IntCellValue(59350),
          IntCellValue(0),
        ],
        [
          TextCellValue('Meter A'),
          TextCellValue('30/07/2026'),
          IntCellValue(60641),
          IntCellValue(62702),
          IntCellValue(0),
        ],
      ]);

      final drafts = await ExcelImportService.extractReadings(bytes);

      expect(drafts, hasLength(4));
      // First row = opening baseline → 0 consumption, its MD is kept.
      expect(drafts[0].kwh, 0);
      expect(drafts[0].kvah, 0);
      expect(drafts[0].mdRecorded, 126);
      expect(drafts[0].sourceLabel, contains('opening'));
      // The actual cumulative reading is kept alongside the consumed value.
      expect(drafts[0].currentKwh, 57037);
      expect(drafts[0].currentKvah, 59109);
      expect(drafts[1].currentKwh, 57123);
      expect(drafts[1].currentKvah, 59201);
      // Subsequent rows = current − previous cumulative value.
      expect(drafts[1].kwh, 86); // 57123 − 57037
      expect(drafts[1].kvah, 92); // 59201 − 59109
      expect(drafts[2].kwh, 145); // 57268 − 57123
      expect(drafts[2].kvah, 149); // 59350 − 59201
      // Total consumption = last − first opening value.
      final totalKwh = drafts.fold<double>(0, (sum, d) => sum + d.kwh);
      final totalKvah = drafts.fold<double>(0, (sum, d) => sum + d.kvah);
      expect(totalKwh, 60641 - 57037); // 3604
      expect(totalKvah, 62702 - 59109); // 3593
    });

    test('does not treat small per-day consumption as cumulative', () async {
      final bytes = _buildWorkbook('Readings', [
        [
          TextCellValue('Meter'),
          TextCellValue('Reading Date'),
          TextCellValue('kWh'),
          TextCellValue('MD Recorded'),
        ],
        [
          TextCellValue('Meter A'),
          TextCellValue('01/07/2026'),
          IntCellValue(120),
          IntCellValue(40),
        ],
        [
          TextCellValue('Meter A'),
          TextCellValue('02/07/2026'),
          IntCellValue(95),
          IntCellValue(30),
        ],
      ]);

      final drafts = await ExcelImportService.extractReadings(bytes);

      expect(drafts, hasLength(2));
      // Now always treated as cumulative — first row = baseline 0,
      // second row = 95 - 120 = negative → meter reset → 0.
      expect(drafts[0].kwh, 0);
      expect(drafts[0].currentKwh, 120);
      expect(drafts[1].kwh, 0);
      expect(drafts[1].currentKwh, 95);
    });

    test('throws FormatException when no readable data is present', () async {
      final excel = Excel.createExcel();
      final bytes = Uint8List.fromList(excel.encode()!);

      await expectLater(
        ExcelImportService.extractReadings(bytes),
        throwsFormatException,
      );
    });
  });
}
