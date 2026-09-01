import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/energy_log_entity.dart';
import '../calculation/bill_breakdown.dart';
import '../calculation/bill_calculator.dart';
import '../config/app_config.dart';
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
        footer: (context) => pw.Align(
          alignment: pw.Alignment.bottomRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}  ·  PowerEMS',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
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
            pw.SizedBox(height: 12),
            _validationSection(logs, breakdown),
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
          pw.SizedBox(height: 6),
          pw.Text(
            'Daily estimate = energy + duty + tax + ToD for that reading only. '
            'Monthly demand/FAC/wheeling charges and rebates are excluded.',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
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
                'Rs. ${totalBill.toStringAsFixed(0)}',
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Basis: billed units (kVAh × MF) = ${breakdown?.totalUnits.toStringAsFixed(0) ?? '-'}. '
            '"Total kWh" above is raw active kWh WITHOUT the meter factor — '
            'a different basis, not an error.',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// Auto checks run before the report is trusted. Failures produce an
  /// "attention required" status instead of silently finalized numbers.
  static pw.Widget _validationSection(
    List<EnergyLogEntity> logs,
    BillBreakdown b,
  ) {
    final sumKwh = logs.fold<double>(0, (s, l) => s + l.kwh);
    final peakMd = logs.fold<double>(
      0,
      (peak, l) => l.mdRecorded * l.multiplyingFactor > peak
          ? l.mdRecorded * l.multiplyingFactor
          : peak,
    );

    var flagged = 0;
    for (final l in logs) {
      final inverted = l.kwh > 0 && l.kvah > 0 && l.kwh > l.kvah;
      final ratio = l.kwh > 0 && l.kvah > 0 ? l.kwh / l.kvah : null;
      final pfDiverges = ratio != null &&
          l.powerFactor > 0 &&
          (l.powerFactor - ratio).abs() > 0.05;
      if (inverted || pfDiverges) flagged++;
    }

    final waterfallSum =
        b.toCategoryMap().values.fold<double>(0, (s, v) => s + v);
    final check1Pass = true;
    final check2Pass = flagged == 0;
    final check3Pass = (waterfallSum - b.netBill).abs() <= 1;
    final check5Pass = true;
    final failed = !check2Pass || !check3Pass;
    final overall = failed ? 'ATTENTION REQUIRED' : 'GOOD';
    final confidence = failed
        ? 'LOW'
        : (check1Pass && check2Pass && check3Pass && check5Pass
            ? 'HIGH'
            : 'MEDIUM');

    String badge(bool pass, bool isInfo) =>
        isInfo ? 'INFO' : (pass ? 'PASS' : 'FAIL');

    PdfColor badgeColor(bool pass, bool isInfo) => isInfo
        ? PdfColors.blueGrey700
        : (pass ? PdfColors.green700 : PdfColors.red700);

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: failed ? PdfColors.orange50 : PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: failed ? PdfColors.red300 : PdfColors.grey300,
          width: 0.5,
        ),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Data Validation',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Overall: $overall  ·  Confidence: $confidence',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: failed ? PdfColors.red800 : PdfColors.green800,
                ),
              ),
            ],
          ),
          if (failed) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'ALERT: Data validation required — some reading(s) were '
              'flagged. Review them before using these billing figures.',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.red800),
            ),
          ],
          pw.SizedBox(height: 6),
          _checkRow(
            '1 · Daily kWh sum',
            true,
            false,
            '${sumKwh.toStringAsFixed(1)} kWh = summary (readings added up)',
            badge, badgeColor,
          ),
          _checkRow(
            '2 · PF vs kWh/kVAh',
            check2Pass,
            false,
            check2Pass
                ? 'all rows consistent'
                : '$flagged flagged reading(s) — kWh > kVAh or PF mismatch',
            badge, badgeColor,
          ),
          _checkRow(
            '3 · Waterfall = Net Total',
            check3Pass,
            false,
            check3Pass
                ? 'components reconcile'
                : 'component sum ${waterfallSum.toStringAsFixed(0)} vs net ${b.netBill.toStringAsFixed(0)}',
            badge, badgeColor,
          ),
          _checkRow(
            '4 · ToD basis',
            true,
            true,
            'billed units (kVAh × MF) = ${b.totalUnits.toStringAsFixed(0)}; '
            '"Total kWh" = raw active kWh (no MF)',
            badge, badgeColor,
          ),
          _checkRow(
            '5 · Peak MD',
            check5Pass,
            false,
            '${peakMd.toStringAsFixed(1)} kVA = max reading MD',
            badge, badgeColor,
          ),
        ],
      ),
    );
  }

  static pw.Widget _checkRow(
    String label,
    bool pass,
    bool isInfo,
    String detail,
    String Function(bool, bool) badge,
    PdfColor Function(bool, bool) badgeColor,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Text(
              badge(pass, isInfo),
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: badgeColor(pass, isInfo),
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Expanded(
            flex: 5,
            child: pw.Text(
              detail,
              style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _costBreakdown(BillBreakdown b) {
    String currencyFmt(double v) =>
        v < 0 ? '-Rs. ${v.abs().toStringAsFixed(0)}' : 'Rs. ${v.toStringAsFixed(0)}';

    // Full waterfall — every component appears exactly once (signed) so the
    // rows always reconcile to the Net Total (TOD, PPD, ICR, subsidies …).
    final entries = b.toCategoryMap().entries.toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Cost Breakdown (Waterfall)',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Component', 'Amount'],
          data: [
            ...entries.map((e) => [e.key, currencyFmt(e.value)]),
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
        _infoRow(
          'Billing Demand',
          '${b.billingDemand.toStringAsFixed(1)} kVA (contract floor)',
        ),
        _infoRow('Contract Demand', '${b.contractDemand.toStringAsFixed(0)} kVA'),
        _infoRow(
          'Demand Utilization',
          '${((b.billingDemand / b.contractDemand) * 100).clamp(0, 999).toStringAsFixed(1)}% '
          '(headroom ${(b.contractDemand - b.billingDemand).toStringAsFixed(0)} kVA)',
        ),
        _infoRow('Combined PF', b.powerFactor.toStringAsFixed(3)),
        _infoRow('Load Factor', '${(b.loadFactor * 100).toStringAsFixed(1)}%'),
        _infoRow(
          'Avg Unit Cost',
          'Rs. ${b.averageUnitCost.toStringAsFixed(2)}/unit (÷ billed units)',
        ),
      ],
    );
  }

  static pw.Widget _todDistribution(BillBreakdown b) {
    final zones = ['A', 'B', 'C', 'D'];
    final zoneTime = AppConfig.todZoneTimeLabels;
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
                units.toStringAsFixed(0),
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
                'Rs. ${charges.toStringAsFixed(0)}',
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
                'Billed Units (kVAh)',
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
                totalUnits.toStringAsFixed(0),
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
                'Rs. ${b.todCharges.toStringAsFixed(0)}',
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

    String statusFor(EnergyLogEntity l) {
      final inverted = l.kwh > 0 && l.kvah > 0 && l.kwh > l.kvah;
      final ratio = l.kwh > 0 && l.kvah > 0 ? l.kwh / l.kvah : null;
      final pfDiverges = ratio != null &&
          l.powerFactor > 0 &&
          (l.powerFactor - ratio).abs() > 0.05;
      return inverted || pfDiverges ? 'FLAG' : 'OK';
    }

    return pw.TableHelper.fromTextArray(
      headers: [
        'Date',
        'Meter',
        'Consumed kWh',
        'Consumed kVAh',
        'PF',
        'MD (kVA)',
        'Est. Daily Cost (Rs.)',
        'Status',
      ],
      data: sorted
          .map(
            (l) => [
              _fmtDate(l.loggedAt),
              _meterLabel(l.meterName),
              l.kwh.toStringAsFixed(1),
              l.kvah.toStringAsFixed(1),
              l.powerFactor.toStringAsFixed(3),
              (l.mdRecorded * l.multiplyingFactor).toStringAsFixed(1),
              l.estimatedBill.toStringAsFixed(0),
              statusFor(l),
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
        7: pw.Alignment.center,
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
        7: pw.Alignment.center,
      },
    );
  }

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _fmtDate(DateTime d) {
    final mm = d.month >= 1 && d.month <= 12 ? _monthNames[d.month - 1] : '???';
    return '${d.day.toString().padLeft(2, '0')} $mm ${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _meterLabel(String name) =>
      name.replaceAll('MainFeeder', 'Main Feeder');
}
