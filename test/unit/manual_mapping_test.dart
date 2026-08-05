import 'dart:io';

import 'package:ems/core/utils/excel_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HQ_Register-1.xlsx readHeaders + detectMapping + extractReadings', () async {
    final file = File(r'C:\Users\PC3\Downloads\HQ_Register-1.xlsx');
    if (!file.existsSync()) {
      markTestSkipped('HQ file not present');
      return;
    }
    final bytes = file.readAsBytesSync();

    final headers = await ExcelImportService.readHeaders(bytes);
    // ignore: avoid_print
    print('HEADERS=$headers');

    final detected = ExcelImportService.detectMapping(headers);
    // ignore: avoid_print
    print('DATE=${detected.date} KWH=${detected.kwh} '
        'KVAH=${detected.kvah} MD=${detected.md} '
        'LAG=${detected.lag} LEAD=${detected.lead} METER=${detected.meter}');

    // Manual override: user mapped kVA demand to "Contract KVA" (col J = 9).
    final drafts =
        await ExcelImportService.extractReadings(bytes, columnMap: detected);
    // ignore: avoid_print
    print('DRAFTS=${drafts.length}');
    for (var i = 0; i < (drafts.length < 5 ? drafts.length : 5); i++) {
      final d = drafts[i];
      // ignore: avoid_print
      print('  ${d.loggedAt} kwh=${d.kwh.toStringAsFixed(1)} '
          'kvah=${d.kvah.toStringAsFixed(1)} lag=${d.rkvarhLag.toStringAsFixed(1)} '
          'lead=${d.rkvarhLead.toStringAsFixed(1)} '
          'md=${d.mdRecorded.toStringAsFixed(2)}');
    }

    expect(headers, isNotEmpty);
  });
}