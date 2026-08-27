import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/energy_log_entity.dart';
import '../calculation/bill_breakdown.dart';
import '../calculation/bill_calculator.dart';
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
    final breakdown = logs.isNotEmpty
        ? BillCalculator.calculate(logs: logs)
        : null;

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
          _summaryTable(logs, breakdown),
          if (breakdown != null) ...[
            pw.SizedBox(height: 16),
            _costBreakdown(breakdown),
            pw.SizedBox(height: 16),
            _demandPfAnalysis(breakdown),
            pw.SizedBox(height: 16),
            _todDistribution(breakdown),
          ],
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

  static pw.Widget _summaryTable(
    List<EnergyLogEntity> logs,
    BillBreakdown? breakdown,
  ) {
    final totalKwh = logs.fold<double>(0, (sum, l) => sum + l.kwh);
    final totalBill = breakdown?.netBill ?? 0;
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
            'Executive Summary',
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
                'Net Bill',
                '₹${totalBill.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _costBreakdown(BillBreakdown b) {
    String currencyFmt(double v) => '₹${v.toStringAsFixed(0)}';
    final rows = <(String, double)>[
      ('Energy Charges', b.energyCharges),
      ('Demand Charges', b.demandCharges),
      ('FAC', b.facCharges),
      ('Wheeling', b.wheelingCharges),
      ('Electricity Duty', b.electricityDuty),
      ('Taxes', b.taxes),
      if (b.fixedCharge > 0) ('Fixed Charge', b.fixedCharge),
      if (b.pfRebate > 0) ('PF Rebate', -b.pfRebate),
      if (b.pfSurcharge > 0) ('PF Surcharge', b.pfSurcharge),
      if (b.subsidy > 0) ('Subsidy', -b.subsidy),
      if (b.lfIncentive > 0) ('LF Incentive', -b.lfIncentive),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Cost Breakdown',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Component', 'Amount'],
          data: [
            ...rows.map((r) => [r.$1, currencyFmt(r.$2)]),
            ['Net Total', currencyFmt(b.netBill)],
          ],
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: pw.TextStyle(fontSize: 8),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
          },
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
      ],
    );
  }

  static pw.Widget _demandPfAnalysis(BillBreakdown b) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Demand & Power Factor Analysis',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        _infoRow('Billing Demand', '${b.billingDemand.toStringAsFixed(1)} kVA'),
        _infoRow('Contract Demand', '${b.contractDemand.toStringAsFixed(0)} kVA'),
        _infoRow(
          'Demand Utilization',
          '${((b.billingDemand / b.contractDemand) * 100).clamp(0, 999).toStringAsFixed(0)}%',
        ),
        _infoRow('Combined PF', b.powerFactor.toStringAsFixed(3)),
        _infoRow('Load Factor', '${(b.loadFactor * 100).toStringAsFixed(1)}%'),
        _infoRow('Avg Unit Cost', '₹${b.averageUnitCost.toStringAsFixed(2)}/unit'),
      ],
    );
  }

  static pw.Widget _todDistribution(BillBreakdown b) {
    final zones = ['A', 'B', 'C', 'D'];
    final zoneTime = {'A': '00-06', 'B': '06-09', 'C': '09-17', 'D': '17-24'};
    final totalUnits = b.totalUnits;
    final rows = <pw.Widget>[];
    for (final z in zones) {
      final units = b.todZoneUnits[z] ?? 0;
      final charges = b.todZoneCharges[z] ?? 0;
      final pct = totalUnits > 0 ? (units / totalUnits * 100) : 0.0;
      rows.add(
        pw.Row(
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                'Zone $z (${zoneTime[z]})',
                style: pw.TextStyle(fontSize: 8),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                '${units.toStringAsFixed(0)} units',
                style: pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Expanded(
              flex: 1,
              child: pw.Text(
                '${pct.toStringAsFixed(1)}%',
                style: pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                '₹${charges.toStringAsFixed(0)}',
                style: pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ToD Zone Distribution',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                'Zone',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                'Units',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Expanded(
              flex: 1,
              child: pw.Text(
                'Share',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                'Charge',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        pw.Divider(height: 8, color: PdfColors.grey400),
        ...rows,
        pw.Divider(height: 8, color: PdfColors.grey400),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                'Net ToD',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                '${totalUnits.toStringAsFixed(0)} units',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Expanded(
              flex: 1,
              child: pw.Text(
                '100%',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Text(
                '₹${b.todCharges.toStringAsFixed(0)}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
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
        'Consumed kWh',
        'Consumed kVAh',
        'PF',
        'MD (kVA)',
        'Est. Bill (₹)',
      ],
      data: sorted
          .map(
            (l) => [
              '${l.loggedAt.day.toString().padLeft(2, '0')}/${l.loggedAt.month.toString().padLeft(2, '0')}/${l.loggedAt.year.toString().substring(2)} ${l.loggedAt.hour.toString().padLeft(2, '0')}:${l.loggedAt.minute.toString().padLeft(2, '0')}',
              l.meterName,
              l.kwh.toStringAsFixed(1),
              l.kvah.toStringAsFixed(1),
              l.powerFactor.toStringAsFixed(3),
              (l.mdRecorded * l.multiplyingFactor).toStringAsFixed(1),
              l.estimatedBill.toStringAsFixed(0),
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
      },
    );
  }
}
