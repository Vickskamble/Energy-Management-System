import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/energy_log_entity.dart';
import '../calculation/bill_breakdown.dart';
import '../calculation/bill_calculator.dart';
import '../calculation/energy_intelligence.dart';
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
    final doc = buildDocument(logs: logs, title: title, subtitle: subtitle);
    final bytes = await doc.save();
    await save.saveBytes(bytes, 'ems_report.pdf', 'application/pdf');
  }

  /// Builds the full report document (kept separate from the save so it can
  /// be exercised in tests / web).
  static pw.Document buildDocument({
    required List<EnergyLogEntity> logs,
    required String title,
    String? subtitle,
  }) {
    final doc = pw.Document();
    final breakdown = logs.isNotEmpty
        ? BillCalculator.calculate(logs: logs)
        : null;
    final intelligence =
        (logs.isNotEmpty && breakdown != null)
        ? EnergyIntelligence.from(logs, breakdown)
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
          if (intelligence != null) ...[
            _managementSummary(intelligence, logs),
            pw.SizedBox(height: 16),
            _findingsSection(intelligence),
          ],
          if (breakdown != null) ...[
            pw.SizedBox(height: 16),
            _validationSection(logs, breakdown),
            if (intelligence != null) ...[
              pw.SizedBox(height: 16),
              _pfTrendSection(intelligence),
              pw.SizedBox(height: 16),
              _anomaliesSection(intelligence),
              pw.SizedBox(height: 16),
              _topDaysSection(intelligence),
              pw.SizedBox(height: 16),
              _costEfficiencySection(intelligence),
              pw.SizedBox(height: 16),
              _incentivesSection(intelligence),
              pw.SizedBox(height: 16),
              _opportunitiesSection(intelligence),
            ],
            pw.SizedBox(height: 16),
            _costBreakdown(breakdown),
            pw.SizedBox(height: 16),
            _demandPfAnalysis(breakdown, intelligence),
            pw.SizedBox(height: 16),
            _todDistribution(breakdown),
            if (intelligence != null) ...[
              pw.SizedBox(height: 16),
              _conclusionSection(intelligence, breakdown),
            ],
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

    return doc;
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
              'ALERT: Data validation required - some reading(s) were '
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
                : '$flagged flagged reading(s) - kWh > kVAh or PF mismatch',
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

  static pw.Widget _demandPfAnalysis(BillBreakdown b, EnergyIntelligence? i) {
    final peakDisplay = i != null
        ? '${i.measuredPeakMd.toStringAsFixed(1)} kVA (EMS measured)'
        : '${b.billingDemand.toStringAsFixed(1)} kVA';
    final billingDisplay = '${b.billingDemand.toStringAsFixed(1)} kVA';
    final utilDisplay = i != null
        ? '${i.billingUtilPct.toStringAsFixed(1)}% (billing demand ÷ contract demand)'
        : '${((b.billingDemand / b.contractDemand) * 100).clamp(0, 999).toStringAsFixed(1)}%';
    final peakUtilDisplay = i != null
        ? '${i.peakUtilPct.toStringAsFixed(1)}% (EMS peak ÷ contract demand)'
        : null;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Demand & Power Factor Analysis',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        _infoRow(
          'Measured Peak Demand (EMS)',
          peakDisplay,
        ),
        _infoRow('Billing Demand', billingDisplay),
        _infoRow('Contract Demand', '${b.contractDemand.toStringAsFixed(0)} kVA'),
        if (peakUtilDisplay != null)
          _infoRow('EMS Peak Utilization', peakUtilDisplay),
        _infoRow('Billing Demand Utilization', utilDisplay),
        if (i != null && (b.billingDemand - i.measuredPeakMd).abs() > 1) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6, bottom: 6),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Why billing demand ($billingDisplay) differs from EMS peak '
                '($peakDisplay):\n'
                'Billing demand may differ from the EMS measured peak due to '
                'the utility billing methodology, billing-period maximum '
                'demand (ratchet/contract floor), meter synchronization, or '
                'measurement intervals.',
                style: pw.TextStyle(fontSize: 7.5, color: PdfColors.amber900),
              ),
            ),
          ),
        ],
        _infoRow('Combined PF', b.powerFactor.toStringAsFixed(3)),
        _infoRow('Load Factor', '${(b.loadFactor * 100).toStringAsFixed(1)}%'),
        _infoRow(
          'Avg Unit Cost',
          'Rs. ${b.averageUnitCost.toStringAsFixed(2)}/billed unit',
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

  // ── Energy Intelligence sections ────────────────────────────────

  static String projMonth(EnergyIntelligence i) {
    final months = const [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    if (i.logs.isEmpty) return 'This period';
    final d = i.logs.first.loggedAt;
    return '${months[d.month - 1]} ${d.year}';
  }

  static pw.Widget _managementSummary(EnergyIntelligence i, List<EnergyLogEntity> logs) {
    final month = projMonth(i);
    final topRow = <pw.Widget>[
      _summaryItem('Readings', '${logs.length}'),
      _summaryItem('Total Consumption', '${i.totalKwh.toStringAsFixed(1)} kWh'),
      _summaryItem('Average PF', i.avgPf.toStringAsFixed(3)),
      _summaryItem('Billing Demand', '${i.billingDemand.toStringAsFixed(0)} kVA'),
      _summaryItem('Contract Demand', '${i.contractDemand.toStringAsFixed(0)} kVA'),
      _summaryItem('Energy Charges', 'Rs. ${i.b.energyCharges.toStringAsFixed(0)}'),
      _summaryItem('Total Bill', 'Rs. ${i.b.netBill.toStringAsFixed(0)}'),
    ];

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
            '$month Energy Performance',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(spacing: 24, runSpacing: 8, children: topRow),
          pw.SizedBox(height: 8),
          pw.Text(
            'Basis: billed units (kVAh × MF) = ${i.billedUnits.toStringAsFixed(0)}. '
            '"Total Consumption" is raw active kWh WITHOUT the meter factor - '
            'a different basis, not an error.',
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _findingsSection(EnergyIntelligence i) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Management Findings',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        for (final f in i.findings)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.Text(_sig(f.status), style: pw.TextStyle(fontSize: 9)),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(
                    f.text,
                    style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _sig(SigStatus s) => switch (s) {
        SigStatus.green => 'GREEN',
        SigStatus.yellow => 'YELLOW',
        SigStatus.red => 'RED',
      };

  static pw.Widget _pfTrendSection(EnergyIntelligence i) {
    final pwWidgets = <pw.Widget>[
      pw.Text(
        'Power Factor Trend (per reading)',
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
    ];

    // Distinct calendar days — the FixedAxis x-axis MUST span at least two
    // different values or the pdf chart divides by zero (NaN crash).
    final distinctDays = i.pfSeries.map((s) => s.date.day).toSet().toList()
      ..sort();

    if (distinctDays.length >= 2) {
      final data = <pw.PointChartValue>[
        for (final s in i.pfSeries)
          pw.PointChartValue(s.date.day.toDouble(), s.pf),
      ];

      // 2-4 evenly spaced ticks across the reading span (always >= 2 distinct).
      final minDay = distinctDays.first;
      final maxDay = distinctDays.last;
      final span = maxDay - minDay;
      final dayTicks = (() {
        final ticks = <int>{};
        for (var k = 0; k <= 3; k++) {
          ticks.add(minDay + (span * k / 3).round());
        }
        return ticks.toList()..sort();
      })();

      pwWidgets.add(
        pw.Container(
          height: 140,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Chart(
            grid: pw.CartesianGrid(
              xAxis: pw.FixedAxis<int>(
                dayTicks,
                divisions: true,
                ticks: true,
                format: (v) => v.toString(),
              ),
              yAxis: pw.FixedAxis<double>(
                const [0.0, 0.50, 0.70, 0.80, 0.90, 0.95, 1.0],
                divisions: true,
                ticks: true,
              ),
            ),
            datasets: [
              pw.LineDataSet<pw.PointChartValue>(
                data: data,
                legend: 'PF',
                color: PdfColors.blue,
                pointColor: PdfColors.blue,
                pointSize: 3,
                lineWidth: 2,
              ),
            ],
          ),
        ),
      );
    } else {
      pwWidgets.add(
        pw.Text(
          distinctDays.isEmpty
              ? 'No PF readings available for a trend.'
              : 'At least two readings on different days are needed for a '
                  'trend chart.',
          style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
        ),
      );
    }

    pwWidgets.addAll([
      pw.SizedBox(height: 8),
      _infoRow('Best PF', i.bestPf.toStringAsFixed(3)),
      _infoRow('Worst PF', i.worstPf.toStringAsFixed(3)),
      _infoRow('Average PF', i.avgPf.toStringAsFixed(3)),
      _infoRow('Low PF Events', '${i.lowPfEvents.length}'),
    ]);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: pwWidgets,
    );
  }

  static pw.Widget _anomaliesSection(EnergyIntelligence i) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Detected Anomalies',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (i.lowPfEvents.isEmpty && i.flaggedInvalid == 0)
          pw.Text(
            'No anomalies detected in the available readings.',
            style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          )
        else ...[
          for (final e in i.lowPfEvents)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                children: [
                  pw.Text('${e.date.day.toString().padLeft(2, '0')} '
                      '${_monthNames[e.date.month - 1]}',
                    style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: pw.Text(
                      'PF dropped to ${e.pf.toStringAsFixed(3)}',
                      style: pw.TextStyle(fontSize: 8.5),
                    ),
                  ),
                ],
              ),
            ),
          if (i.flaggedInvalid > 0)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(
                'ALERT: ${i.flaggedInvalid} reading(s) report kWh greater than kVAh (physically invalid)',
                style: pw.TextStyle(fontSize: 8.5, color: PdfColors.red800),
              ),
            ),
        ],
      ],
    );
  }

  static pw.Widget _topDaysSection(EnergyIntelligence i) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Top Energy Consumption Days',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        for (final t in i.topDays)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.Text(
                  '${t.date.day.toString().padLeft(2, '0')} '
                  '${_monthNames[t.date.month - 1]}',
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    '${t.kwh.toStringAsFixed(1)} kWh',
                    style: pw.TextStyle(fontSize: 8.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static pw.Widget _costEfficiencySection(EnergyIntelligence i) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Energy Cost Efficiency',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        _infoRow(
          'Avg Unit Cost',
          'Rs. ${i.b.averageUnitCost.toStringAsFixed(2)}/billed unit',
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Area', 'Amount', 'Share'],
          data: [
            for (final c in i.costShare)
              ['${c.label} ', 'Rs. ${c.amount.toStringAsFixed(0)}', '${c.percent.toStringAsFixed(1)}%'],
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
            2: pw.Alignment.centerRight,
          },
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Where your money goes - largest share of gross charges first.',
          style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
      ],
    );
  }

  static pw.Widget _incentivesSection(EnergyIntelligence i) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Incentives Earned',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        _infoRow(
          'Total Incentives',
          i.incentivesTotal > 0
              ? 'Rs. ${i.incentivesTotal.toStringAsFixed(0)}'
              : 'None this period',
        ),
        if (i.incentivesTotal > 0) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'PF + load-factor incentives reduced the monthly bill by '
            'Rs. ${i.incentivesTotal.toStringAsFixed(0)}.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.green800),
          ),
        ],
      ],
    );
  }

  static pw.Widget _opportunitiesSection(EnergyIntelligence i) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Cost Optimization Opportunities',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['Area', 'Status', 'Potential', 'Detail'],
          data: [
            for (final o in i.opportunities)
              [
                o.area,
                '${_sig(o.status)} ${o.statusLabel}',
                o.potential,
                o.note,
              ],
          ],
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: pw.TextStyle(fontSize: 7.5),
          cellAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerLeft,
            2: pw.Alignment.centerLeft,
            3: pw.Alignment.centerLeft,
          },
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        ),
      ],
    );
  }

  static pw.Widget _conclusionSection(EnergyIntelligence i, BillBreakdown b) {
    final month = projMonth(i);
    final confidenceLabel = i.confidenceScore >= 90
        ? 'HIGH'
        : i.confidenceScore >= 70
            ? 'MEDIUM'
            : 'REVIEW REQUIRED';

    final sb = StringBuffer()
      ..write('Overall energy performance during $month was ')
      ..write(i.avgPf >= EnergyIntelligence.pfLowWarn
          ? 'stable based on the available readings, with an average PF of '
              '${i.avgPf.toStringAsFixed(3)}. '
          : 'mixed, with an average PF of ${i.avgPf.toStringAsFixed(3)} and '
              'low-PF events observed. ')
      ..write('Billing demand utilization was approximately '
          '${i.billingUtilPct.toStringAsFixed(0)}% of contract demand '
          '(${i.billingDemand.toStringAsFixed(0)} kVA of '
          '${i.contractDemand.toStringAsFixed(0)} kVA). ');
    if (i.flaggedInvalid > 0 || i.missingDayCount > 0) {
      sb.write(
          'Consumption and TOD figures should be validated for consistency '
          'before using this report for financial decision-making.');
    } else {
      sb.write(
          'Consumption and TOD figures are internally consistent and can be '
          'used with confidence.');
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.green300, width: 0.5),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PowerEMS Recommendation',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            sb.toString(),
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Report Confidence',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Data Quality: ${i.confidenceScore.toStringAsFixed(0)}% '
                '($confidenceLabel)',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: i.confidenceScore >= 90 ? PdfColors.green800 : PdfColors.amber900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
