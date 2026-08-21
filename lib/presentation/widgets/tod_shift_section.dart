import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/calculation/tod_calculator.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_section.dart';
import '../../domain/entities/energy_log_entity.dart';

/// ToD / Shift analysis — same cards as the v1.2.5 trial UI
/// (Analysis → ToD/Shift): zone table with units+rates+₹, shift summary
/// with pro-rata split, shift-wise MD breach flags and daily stacked bars.
/// Zone rates come from the active tariff preset (share × energy rate).
class TodShiftSection extends StatefulWidget {
  final List<EnergyLogEntity> logs;
  final String siteLabel;

  const TodShiftSection({
    super.key,
    required this.logs,
    required this.siteLabel,
  });

  @override
  State<TodShiftSection> createState() => _TodShiftSectionState();
}

class _TodShiftSectionState extends State<TodShiftSection> {
  static const _zoneTimes = {
    'A': '00–06',
    'B': '06–09',
    'C': '09–17',
    'D': '17–24',
  };
  static const _shiftColors = [
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFFA78BFA),
  ];

  late bool _winter = AppConfig.useWinterTod;

  bool get _isDark =>
      Theme.of(context).brightness == Brightness.dark;

  Color get _dim =>
      _isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;

  Color get _line => _isDark ? AppColors.borderDark : AppColors.borderLight;

  Color get _surface2 =>
      _isDark ? AppColors.surface2Dark : AppColors.surface2Light;

  Map<String, double> get _shares {
    final map = _winter && AppConfig.todZoneSharesWinter.isNotEmpty
        ? AppConfig.todZoneSharesWinter
        : AppConfig.todZoneShares;
    return {
      'A': map['A'] ?? 0,
      'B': map['B'] ?? 0,
      'C': map['C'] ?? 0,
      'D': map['D'] ?? 0,
    };
  }

  double get _energyRate => AppConfig.tariffPerUnit;

  /// Zone-level result via the slot engine (pro-rata 8h windows).
  TodZoneResult get _tod {
    return TodCalculator.calculate(
      logs: widget.logs,
      zoneShares: AppConfig.todZoneShares,
      winterZoneShares: AppConfig.todZoneSharesWinter,
      useWinter: _winter,
      energyRatePerUnit: _energyRate,
      onKvah: AppConfig.billOnKvah,
    );
  }

  /// Units per 8h shift via the day-aware engine — daily-totalizer days
  /// spread their units ⅓ per shift so they are never dumped into one slot.
  List<double> get _byShiftKwh {
    final sums = [0.0, 0.0, 0.0];
    for (final d in TodCalculator.days(
      logs: widget.logs,
      onKvah: AppConfig.billOnKvah,
    )) {
      for (var i = 0; i < 3; i++) {
        sums[i] += d.shiftUnits[i];
      }
    }
    return sums;
  }

  /// Max MD × MF per shift window over the period.
  List<double> get _byShiftMd {
    final maxes = [0.0, 0.0, 0.0];
    for (final l in widget.logs) {
      final md = l.mdRecorded * l.multiplyingFactor;
      final i = TodCalculator.shiftIndex(l.loggedAt.hour);
      if (md > maxes[i]) maxes[i] = md;
    }
    return maxes;
  }

  /// Distinct days (chronological) with their shift units — day-aware.
  List<({DateTime date, List<double> kwh})> get _perDay {
    final list = [
      for (final d in TodCalculator.days(
        logs: widget.logs,
        onKvah: AppConfig.billOnKvah,
      ))
        (date: d.date, kwh: List<double>.of(d.shiftUnits)),
    ];
    return list.length > 120 ? list.sublist(list.length - 120) : list;
  }

  /// Site contract demand — max declared on the period's readings.
  double get _contractDemand {
    var cd = 0.0;
    for (final l in widget.logs) {
      if (l.contractDemand > cd) cd = l.contractDemand;
    }
    return cd;
  }

  /// Days where any shift MD crossed 95% of contract demand.
  List<({DateTime date, double maxMd, int shift})> get _breaches {
    final cd = _contractDemand;
    if (cd <= 0) return const [];
    final threshold = cd * 0.95;
    final map = <String, ({DateTime date, double maxMd, int shift})>{};
    for (final l in widget.logs) {
      final md = l.mdRecorded * l.multiplyingFactor;
      if (md <= threshold) continue;
      final key =
          '${l.loggedAt.year}-${l.loggedAt.month}-${l.loggedAt.day}';
      final shift = TodCalculator.shiftIndex(l.loggedAt.hour);
      final rec = map[key];
      if (rec == null || md > rec.maxMd) {
        map[key] = (
          date: DateTime(
            l.loggedAt.year,
            l.loggedAt.month,
            l.loggedAt.day,
          ),
          maxMd: md,
          shift: shift,
        );
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list.length > 8 ? list.sublist(list.length - 8) : list;
  }

  /// ToD ₹ contributed by a shift: the shift's units (day-aware buckets) ×
  /// hours/8 per window zone × zone rate — the trial's BOUNDS() pro-rata.
  /// Zone units already carry the day-aware allocation, so this never
  /// double-counts and always sums to the net ToD.
  double _shiftAmount({required int shift, required List<(String, double)> zones}) {
    final shares = _shares;
    var amt = 0.0;
    for (final d in TodCalculator.days(
      logs: widget.logs,
      onKvah: AppConfig.billOnKvah,
    )) {
      final units = d.shiftUnits[shift];
      for (final (z, hours) in zones) {
        amt += units * hours / 8 * (shares[z] ?? 0) * _energyRate;
      }
    }
    return amt;
  }

  String _money(double v) {
    final nf = NumberFormat('#,##,##0.00', 'en_IN');
    return (v < 0 ? '−₹' : '₹') + nf.format(v.abs());
  }


  String _pc(double share) => '${(share * 100).toStringAsFixed(0)}%';

  Widget _badge(String text, {bool ok = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (ok ? AppColors.success : AppColors.primary)
            .withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: ok
              ? AppColors.success
              : (_isDark ? AppColors.primaryLight : AppColors.primaryDark),
          height: 1,
        ),
      ),
    );
  }

  Widget _segButton(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: active ? Colors.white : _dim,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _th(String label, {bool right = false}) {
    return Text(
      label.toUpperCase(),
      textAlign: right ? TextAlign.right : TextAlign.start,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _dim,
        letterSpacing: 0.3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tod = _tod;
    final byShift = _byShiftKwh;
    final days = _perDay;
    final cd = _contractDemand;

    final dayAmt = _shiftAmount(shift: 0, zones: const [('B', 3), ('C', 5)]);
    final eveAmt = _shiftAmount(shift: 1, zones: const [('C', 3), ('D', 5)]);
    final nightAmt = _shiftAmount(shift: 2, zones: const [('D', 2), ('A', 6)]);

    final nfGroups = NumberFormat.decimalPattern('en_IN');

    Widget zoneTable() {
      final shares = _shares;
      final rows = <Widget>[];
      for (final z in const ['A', 'B', 'C', 'D']) {
        final share = shares[z]!;
        final rate = share * _energyRate;
        final units = tod.zoneUnits[z] ?? 0;
        final amt = tod.zoneCharges[z] ?? 0;
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    z,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    _zoneTimes[z]!,
                    style: TextStyle(fontSize: 11, color: _dim),
                  ),
                ),
                Expanded(
                  child: Text(
                    nfGroups.format(units.round()),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _dim,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _dim,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: Text(
                    _money(amt),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: amt < 0 ? AppColors.danger : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      final note = [
        for (final z in const ['A', 'B', 'C', 'D'])
          if (shares[z]! != 0) '$z = ${_pc(shares[z]!)}',
      ].join(', ');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Zone table',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              _badge('slot engine'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'units auto from your readings',
            style: TextStyle(fontSize: 11, color: _dim),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(width: 24, child: _th('Zone')),
              SizedBox(width: 56, child: _th('Time')),
              Expanded(child: _th('Units')),
              SizedBox(width: 64, child: _th('Rate', right: true)),
              SizedBox(width: 84, child: _th('₹', right: true)),
            ],
          ),
          const Divider(height: 16),
          ...rows,
          const Divider(height: 16),
          Text(
            'Rates ₹/u: $note of $_energyRate ₹/u (energy rate). '
            'Share me aayega — C = solar rebate, D = peak surcharge, A/B 0.',
            style: TextStyle(fontSize: 11, color: _dim, height: 1.5),
          ),
          const Divider(height: 16),
          Row(
            children: [
              const Text(
                'Net ToD (slot engine)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                _money(tod.netCharges),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: tod.netCharges <= 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      );
    }

    Widget shiftSummary() {
      final shares = _shares;
      final splitTexts = [
        '3h B (${shares['B'] == 0 ? '0' : _pc(shares['B']!)}) '
            '+ 5h C (${shares['C'] == 0 ? '0' : _pc(shares['C']!)})',
        '3h C (${shares['C'] == 0 ? '0' : _pc(shares['C']!)}) '
            '+ 5h D (${shares['D'] == 0 ? '0' : _pc(shares['D']!)})',
        '2h D (${shares['D'] == 0 ? '0' : _pc(shares['D']!)}) '
            '+ 6h A (${shares['A'] == 0 ? '0' : _pc(shares['A']!)})',
      ];
      final rows = [
        ('Day (06–14)', byShift[0], dayAmt, 0),
        ('Evening (14–22)', byShift[1], eveAmt, 1),
        ('Night (22–06)', byShift[2], nightAmt, 2),
      ];
      final total = dayAmt + eveAmt + nightAmt;
      final totalUnits = byShift[0] + byShift[1] + byShift[2];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Shift analysis summary',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              _badge('ToD ₹ per shift'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Units per shift · pro-rata split engine',
            style: TextStyle(fontSize: 11, color: _dim),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _th('Shift')),
              SizedBox(width: 60, child: _th('Units', right: true)),
              SizedBox(width: 42, child: _th('%', right: true)),
              SizedBox(width: 130, child: _th('Zone split')),
              SizedBox(width: 84, child: _th('ToD ₹', right: true)),
            ],
          ),
          const Divider(height: 16),
          for (final (label, kwh, amt, shift) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: _shiftColors[shift],
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(label, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      kwh.round().toString(),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _dim,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      totalUnits > 0
                          ? '${(kwh / totalUnits * 100).round()}%'
                          : '0%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: _dim,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: Text(
                      splitTexts[shift],
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10.5, color: _dim),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      _money(amt),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: amt < 0
                            ? AppColors.success
                            : amt > 0
                                ? AppColors.danger
                                : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          Row(
            children: [
              const Text(
                'Total ToD',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  'net from slot engine',
                  style: TextStyle(fontSize: 10, color: _dim),
                ),
              ),
              const Spacer(),
              Text(
                _money(total),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: total <= 0 ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Shift 8h window covers 2 billing zones — units split pro-rata '
            '(Day 06–14 = 3h B + 5h C; Evening 14–22 = 3h C + 5h D; '
            'Night 22–06 = 2h D + 6h A). ToD ₹ = shift units × zone share × energy rate.',
            style: TextStyle(
              fontSize: 11,
              color: _dim,
              height: 1.5,
            ),
          ),
        ],
      );
    }

    Widget mdCard() {
      final breaches = _breaches;
      final byShiftMd = _byShiftMd;
      final peak = byShiftMd.reduce((a, b) => a > b ? a : b);
      final upper = cd * 1.2;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Shift-wise MD — breach flags',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              _badge('NEW'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'breach = shift MD > ${(cd * 0.95).round()} kVA (95% CD)',
            style: TextStyle(fontSize: 11, color: _dim),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _th('Recent breach')),
              SizedBox(width: 70, child: _th('Max MD', right: true)),
              SizedBox(width: 110, child: _th('Shift', right: true)),
            ],
          ),
          const Divider(height: 16),
          if (breaches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Koi breach nahi',
                style: TextStyle(fontSize: 11.5, color: _dim),
              ),
            )
          else
            for (final (i, b) in breaches.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Day ${i + 1} · ${DateFormat('d MMM').format(b.date)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${b.maxMd.round()} kVA',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        b.shift == 1
                            ? 'Evening BREACH'
                            : b.shift == 0
                                ? 'Day BREACH'
                                : 'Night',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: b.shift == 1 || b.shift == 0
                              ? AppColors.warning
                              : _dim,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total: ${breaches.length} days · peak ${peak.round()} kVA',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'CD ${cd.round()} · 120% = ${upper.round()}',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 10.5, color: _dim),
              ),
            ],
          ),
        ],
      );
    }

    Widget buildBarChart({
      required List<({DateTime date, List<double> kwh})> days,
      required double plotW,
      required double plotH,
      required double barW,
      required double maxTotal,
    }) {
      // Smart Y-axis: 3-5 gridlines, format large numbers (1k, 2k).
      final rawStep = maxTotal > 0 ? maxTotal / 4 : 1.0;
      final mag = rawStep >= 1000 ? 1000.0 : rawStep >= 100 ? 100.0 : rawStep >= 10 ? 10.0 : 1.0;
      final step = (rawStep / mag).ceil() * mag;
      final gridCount = step > 0 ? (maxTotal / step).ceil() : 4;
      final yFmt = (double v) {
        if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
        return '${v.round()}';
      };
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var g = gridCount; g >= 0; g--)
                  Text(
                    yFmt(step * g),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _dim,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SizedBox(
              height: plotH + 14,
              child: Stack(
                children: [
                  for (var g = 0; g <= gridCount; g++)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: gridCount > 0
                          ? (plotH + 14) * g / gridCount - 1
                          : 0,
                      child: Container(
                        height: 1,
                        color: _line.withValues(alpha: 0.5),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in days)
                        Container(
                          width: barW,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 0.5,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              for (var s = 2; s >= 0; s--)
                                Container(
                                  height: maxTotal <= 0
                                      ? 0
                                      : d.kwh[s] / maxTotal *
                                          plotH,
                                  color: _shiftColors[s],
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    Widget dailyChart() {
      final maxTotal = days.fold<double>(
        0,
        (m, d) => d.kwh.fold<double>(m, (a, b) => a + b > m ? a + b : m),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Daily consumption by shift (${days.length} days)',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _badge('stacked'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            children: [
              for (final (label, i) in const [
                ('Day (06–14)', 0),
                ('Evening (14–22)', 1),
                ('Night (22–06)', 2),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: _shiftColors[i],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(fontSize: 12, color: _dim),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: _line),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
            child: days.isEmpty
                ? SizedBox(
                    height: 100,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.query_stats, size: 30, color: _dim),
                          const SizedBox(height: 6),
                          Text(
                            'No readings in this period',
                            style: TextStyle(fontSize: 12, color: _dim),
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final plotW = constraints.maxWidth - 44.0;
                      const minBarW = 14.0;
                      const maxBarW = 44.0;
                      final barW = (plotW / days.length)
                          .clamp(minBarW, maxBarW);
                      final needsScroll = days.length > 20;
                      final chartW = needsScroll
                          ? days.length * minBarW + 44.0
                          : plotW + 44.0;
                      // Height scales with data: 220 for few days, up to 340 for many.
                      final plotH = days.length <= 7
                          ? 220.0
                          : days.length <= 14
                              ? 260.0
                              : 300.0;
                      return SizedBox(
                        height: plotH + 26,
                        child: needsScroll
                            ? SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: chartW,
                                  child: buildBarChart(
                                    days: days,
                                    plotW: chartW - 44,
                                    plotH: plotH,
                                    barW: barW,
                                    maxTotal: maxTotal,
                                  ),
                                ),
                              )
                            : buildBarChart(
                                days: days,
                                plotW: plotW,
                                plotH: plotH,
                                barW: barW,
                                maxTotal: maxTotal,
                              ),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    if (widget.logs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'ToD / Shift Analysis',
          subtitle:
              'slot engine — har reading uske hour ke hisab se zone A/B/C/D '
              'me, bilkul discom jaisa (hour-based, flat average nahi)',
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _surface2,
                border: Border.all(color: _line),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  _segButton(
                    'Apr–Sep',
                    !_winter,
                    () => setState(() {
                      _winter = false;
                      AppConfig.useWinterTod = false;
                    }),
                  ),
                  _segButton(
                    'Oct–Mar',
                    _winter,
                    () => setState(() {
                      _winter = true;
                      AppConfig.useWinterTod = true;
                    }),
                  ),
                ],
              ),
            ),
            const Spacer(),
            _badge(
              '${widget.siteLabel} · ${_perDay.length} days × 3 shifts · '
              '${widget.logs.length} readings',
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 14.0;
            final columns =
                ((constraints.maxWidth + gap) / (260 + gap)).floor().clamp(1, 2);
            final cardWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            final cards = [
              AppCard(
                padding: const EdgeInsets.all(16),
                child: zoneTable(),
              ),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: shiftSummary(),
              ),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: mdCard(),
              ),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: dailyChart(),
              ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final card in cards)
                  SizedBox(width: cardWidth, child: card),
              ],
            );
          },
        ),
      ],
    );
  }
}