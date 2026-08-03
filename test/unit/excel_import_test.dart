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
      expect(a.loggedAt, DateTime(2026, 6, 1));
      expect(a.kwh, 123.45);
      expect(a.kvah, 130.5);
      expect(a.rkvarhLag, 5.5);
      expect(a.rkvarhLead, 1.25);
      expect(a.mdRecorded, 42);
      expect(a.isValid, isTrue);
      expect(a.sourceLabel, 'Row 2');

      final b = drafts[1];
      expect(b.meterName, 'Meter B');
      expect(b.loggedAt, DateTime(2026, 6, 2));
      expect(b.kwh, 200);
      expect(b.mdRecorded, 60);
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
      expect(drafts.first.kwh, 300);
      expect(drafts.first.mdRecorded, 75);
      expect(drafts.first.sourceLabel, 'Row 3');
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
