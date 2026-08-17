import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/energy_log_entity.dart';
import 'export_service_io.dart'
    if (dart.library.js_interop) 'export_service_web.dart'
    as save;

class PdfReportService {
  PdfReportService._();

  static Future<void> exportPdf({
    required List<EnergyLogEntity> logs,
    required String title,
    String? subtitle,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 18)),
                pw.Text(
                  'Generated: ${DateTime.now().toString().substring(0, 16)}',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
          if (subtitle != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text(
                subtitle,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
            ),
          pw.SizedBox(height: 8),
          _summaryTable(logs),
          pw.SizedBox(height: 20),
          pw.Text(
            'Reading History',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _readingsTable(logs),
        ],
      ),
    );

    final bytes = await doc.save();
    await save.saveBytes(bytes, 'ems_report.pdf', 'application/pdf');
  }

  static pw.Widget _summaryTable(List<EnergyLogEntity> logs) {
    final totalKwh = logs.fold<double>(0, (sum, l) => sum + l.kwh);
    final totalBill = logs.fold<double>(0, (sum, l) => sum + l.estimatedBill);
    final peakMd = logs.fold<double>(
      0,
      (peak, l) => l.mdRecorded * l.multiplyingFactor > peak
          ? l.mdRecorded * l.multiplyingFactor
          : peak,
    );
    final totalKvah = logs.fold<double>(0, (sum, l) => sum + l.kvah);
    final avgPf = (logs.isEmpty || totalKvah <= 0)
        ? 0.0
        : (totalKwh / totalKvah).clamp(0.0, 1.0);

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem('Readings', '${logs.length}'),
              _summaryItem('Total kWh', totalKwh.toStringAsFixed(1)),
              _summaryItem('Peak MD (kVA)', peakMd.toStringAsFixed(1)),
              _summaryItem('Avg PF', avgPf.toStringAsFixed(3)),
              _summaryItem(
                'Est. Total Bill',
                '₹${totalBill.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _readingsTable(List<EnergyLogEntity> logs) {
    final sorted = List<EnergyLogEntity>.from(logs)
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));

    return pw.TableHelper.fromTextArray(
      headers: [
        'Date',
        'Meter',
        'Reading kWh',
        'Consumed kWh',
        'Reading kVAh',
        'PF',
        'MD (kVA)',
        'Est. Bill (₹)',
        'Sync',
      ],
      data: sorted
          .map(
            (l) => [
              '${l.loggedAt.day.toString().padLeft(2, '0')}/${l.loggedAt.month.toString().padLeft(2, '0')}/${l.loggedAt.year.toString().substring(2)} ${l.loggedAt.hour.toString().padLeft(2, '0')}:${l.loggedAt.minute.toString().padLeft(2, '0')}',
              l.meterName,
              l.currentKwh != null ? l.currentKwh!.toStringAsFixed(1) : '—',
              l.kwh.toStringAsFixed(1),
              l.currentKvah != null ? l.currentKvah!.toStringAsFixed(1) : '—',
              l.powerFactor.toStringAsFixed(3),
              (l.mdRecorded * l.multiplyingFactor).toStringAsFixed(1),
              l.estimatedBill.toStringAsFixed(0),
              l.isSynced ? 'Cloud' : 'Pending',
            ],
          )
          .toList(),
      headerStyle: pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: pw.TextStyle(fontSize: 7),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.center,
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.center,
      },
    );
  }
}
