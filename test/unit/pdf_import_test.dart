import 'package:ems/core/utils/pdf_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Issue 11 — label-based parser (pure Dart). Parsing is format-flexible by
/// design: numbers are picked up from lines carrying known labels (kWh, kVAh,
/// MD, PF, dates), so every utility's layout works. Tests feed realistic bill
/// text directly — no PDFium engine needed (CI runners have no libpdfium.so).
void main() {
  test('extracts units, MD, PF and bill date from a bill page', () {
    const text = '''
UPCL Electricity Bill - June 2026
Bill Date: 15/06/2026
Present Reading (kWh): 1250.50
Previous Reading (kWh): 1100.00
Units Consumed: 150.50
Max Demand (kVA): 95.2
Power Factor: 0.92
rkVARh (Lag): 45.6  rkVARh (Lead): 12.3
''';

    final r = PdfImportService.parseBillText(text, pageIndex: 1);

    expect(r, isNotNull);
    expect(r!.kwh, closeTo(150.50, 0.01));
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
      () {
    const text = '''
MSEB Bill
Bill Date: 02/07/2026
Current kWh: 8000
Previous kWh: 7000
MD: 110
''';

    final r = PdfImportService.parseBillText(text, pageIndex: 1);

    expect(r, isNotNull);
    expect(r!.kwh, closeTo(1000, 0.01));
    expect(r.mdRecorded, closeTo(110, 0.01));
  });

  test('returns null when the page has no readable readings', () {
    const text = 'Just a normal document with no meter values.';

    expect(
      PdfImportService.parseBillText(text, pageIndex: 1),
      isNull,
    );
  });
}
