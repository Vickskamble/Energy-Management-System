import 'dart:typed_data';

import 'package:ems/core/utils/pdf_import_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

/// Issue 11 — test fixture: generate a text-based PDF bill and verify the
/// label-based parser extracts the expected readings.
void main() {
  test('extracts units, MD, PF and bill date from a PDF bill', () async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('UPCL Electricity Bill - June 2026'),
            pw.Text('Bill Date: 15/06/2026'),
            pw.Text('Present Reading (kWh): 1250.50'),
            pw.Text('Previous Reading (kWh): 1100.00'),
            pw.Text('Units Consumed: 150.50'),
            pw.Text('Max Demand (kVA): 95.2'),
            pw.Text('Power Factor: 0.92'),
            pw.Text('rkVARh (Lag): 45.6  rkVARh (Lead): 12.3'),
          ],
        ),
      ),
    );
    final bytes = await doc.save();

    final readings =
        await PdfImportService.extractReadings(Uint8List.fromList(bytes));

    expect(readings, hasLength(1));
    final r = readings.first;
    expect(r.kwh, closeTo(150.50, 0.01));
    expect(r.mdRecorded, closeTo(95.2, 0.01));
    expect(r.kvah, closeTo(150.50 / 0.92, 0.01));
    expect(r.rkvarhLag, closeTo(45.6, 0.01));
    expect(r.rkvarhLead, closeTo(12.3, 0.01));
    expect(r.loggedAt.year, 2026);
    expect(r.loggedAt.month, 6);
    expect(r.loggedAt.day, 15);
    expect(r.sourcePage, 1);
  });

  test('falls back to present minus previous when no explicit units line',
      () async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('MSEB Bill'),
            pw.Text('Bill Date: 02/07/2026'),
            pw.Text('Current kWh: 8000'),
            pw.Text('Previous kWh: 7000'),
            pw.Text('MD: 110'),
          ],
        ),
      ),
    );
    final bytes = await doc.save();

    final readings =
        await PdfImportService.extractReadings(Uint8List.fromList(bytes));

    expect(readings, hasLength(1));
    expect(readings.first.kwh, closeTo(1000, 0.01));
    expect(readings.first.mdRecorded, closeTo(110, 0.01));
  });

  test('throws when the PDF has no readable readings', () async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(build: (ctx) => pw.Text('Just a normal document')),
    );
    final bytes = await doc.save();

    expect(
      () => PdfImportService.extractReadings(Uint8List.fromList(bytes)),
      throwsA(isA<FormatException>()),
    );
  });
}
