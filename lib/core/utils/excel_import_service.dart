import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../utils/app_logger.dart';

/// A single reading extracted from an Excel (.xlsx) file.
///
/// Values are placeholders from the parser — the user confirms/edits them in
/// the import preview before anything is saved.
class ExcelReadingDraft {
  ExcelReadingDraft({
    this.meterName = '',
    required this.loggedAt,
    this.kwh = 0,
    this.kvah = 0,
    this.rkvarhLag = 0,
    this.rkvarhLead = 0,
    this.mdRecorded = 0,
    required this.sourceLabel,
  });

  String meterName;
  DateTime loggedAt;
  double kwh;
  double kvah;
  double rkvarhLag;
  double rkvarhLead;
  double mdRecorded;

  /// Human-readable source, e.g. "Row 5" (1-based Excel row number).
  final String sourceLabel;

  bool get isValid => kwh > 0 && mdRecorded > 0;
}

/// Bulk Excel import — reads readings (with dates) from a client-supplied
/// .xlsx file so the whole history can be added to the system in one go.
///
/// Column detection is header-label based (case-insensitive), so the client
/// file is flexible:
///   Meter | Reading Date | kWh (or Current kWh + Previous kWh) |
///   kVAh | rkVARh Lag | rkVARh Lead | MD Recorded
class ExcelImportService {
  ExcelImportService._();

  static Future<List<ExcelReadingDraft>> extractReadings(
    Uint8List bytes,
  ) async {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      AppLogger.e('Excel decode failed', e);
      throw const FormatException(
        'Unable to read the Excel file. Make sure it is a valid .xlsx file.',
      );
    }

    final drafts = <ExcelReadingDraft>[];
    for (final sheet in excel.tables.values) {
      drafts.addAll(_parseSheet(sheet));
    }
    if (drafts.isEmpty) {
      throw const FormatException(
        'No readings found in the selected Excel file. '
        'Expected headers: Meter, Reading Date, kWh, MD Recorded '
        '(kVAh / rkVARh Lag / rkVARh Lead optional).',
      );
    }
    return drafts;
  }

  // ---------------------------------------------------------------------------
  // Sheet parsing
  // ---------------------------------------------------------------------------

  static List<ExcelReadingDraft> _parseSheet(Sheet sheet) {
    final rows = sheet.rows;
    if (rows.isEmpty) return [];

    final headerRow = _findHeaderRow(rows);
    if (headerRow < 0) return [];
    final cols = _mapColumns(rows[headerRow]);
    if (cols.kwh == null && (cols.currentKwh == null || cols.prevKwh == null)) {
      return [];
    }

    // When the kWh / kVAh columns carry CUMULATIVE meter readings (each row
    // is the meter's current total), convert to per-day consumption by taking
    // the difference from the previous row. The first row is the opening
    // baseline → consumption 0.
    final kwhCumulative =
        cols.kwh != null && _isCumulative(rows, headerRow, cols.kwh!);
    final kvahCumulative =
        cols.kvah != null && _isCumulative(rows, headerRow, cols.kvah!);
    final kwhSeries = kwhCumulative
        ? _cumulativeSeries(rows, headerRow, cols.kwh!)
        : null;
    final kvahSeries = kvahCumulative
        ? _cumulativeSeries(rows, headerRow, cols.kvah!)
        : null;

    final drafts = <ExcelReadingDraft>[];
    for (var i = headerRow + 1; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;

      final meter = cols.meter != null ? _cellText(row[cols.meter!]) : '';
      final loggedAt = cols.date != null
          ? _cellDate(row[cols.date!]) ?? DateTime.now()
          : DateTime.now();
      if (loggedAt.isAfter(DateTime.now())) continue;

      final double kwh;
      if (kwhSeries != null) {
        kwh = kwhSeries[i - (headerRow + 1)];
      } else {
        kwh = _resolveConsumed(
          row,
          cols.kwh,
          cols.currentKwh,
          cols.prevKwh,
        );
      }
      final double kvah;
      if (kvahSeries != null) {
        kvah = kvahSeries[i - (headerRow + 1)];
      } else {
        kvah = _resolveConsumed(
          row,
          cols.kvah,
          cols.currentKvah,
          cols.prevKvah,
        );
      }
      final lag = cols.lag != null ? _cellNumber(row[cols.lag!]) ?? 0 : 0.0;
      final lead = cols.lead != null
          ? _cellNumber(row[cols.lead!]) ?? 0
          : 0.0;
      final md = cols.md != null ? _cellNumber(row[cols.md!]) ?? 0 : 0.0;

      final baseline = kwhSeries != null && i == headerRow + 1;
      if (kwh <= 0 && kvah <= 0 && md <= 0) continue;

      drafts.add(
        ExcelReadingDraft(
          meterName: meter,
          loggedAt: loggedAt,
          kwh: kwh,
          kvah: kvah,
          rkvarhLag: lag,
          rkvarhLead: lead,
          mdRecorded: md,
          sourceLabel: baseline ? 'Row ${i + 1} (opening)' : 'Row ${i + 1}',
        ),
      );
    }
    return drafts;
  }

  /// Heuristic: treat a column as cumulative meter readings when it holds a
  /// mostly-monotonically-increasing series of large values (meters display
  /// running totals like 57,037 — not small per-day consumption figures).
  static bool _isCumulative(
    List<List<Data?>> rows,
    int headerRow,
    int col,
  ) {
    var minVal = double.infinity;
    var prev = double.nan;
    var nonDecreasing = 0;
    var valid = 0;
    for (var i = headerRow + 1; i < rows.length; i++) {
      final v = _cellNumber(rows[i][col]);
      if (v == null) continue;
      valid++;
      if (v < minVal) minVal = v;
      if (!prev.isNaN) {
        if (v >= prev) nonDecreasing++;
      }
      prev = v;
    }
    if (valid < 2) return false;
    return nonDecreasing >= valid - 1 && minVal >= 10000;
  }

  /// Cumulative readings → per-row consumed (current − previous). The first
  /// data row has no predecessor → 0. Out-of-order (meter reset) → 0.
  static List<double> _cumulativeSeries(
    List<List<Data?>> rows,
    int headerRow,
    int col,
  ) {
    final series = <double>[];
    var prev = double.nan;
    for (var i = headerRow + 1; i < rows.length; i++) {
      final v = _cellNumber(rows[i][col]);
      if (v == null) {
        series.add(0.0);
        continue;
      }
      if (prev.isNaN) {
        series.add(0.0);
      } else {
        series.add(v >= prev ? v - prev : 0.0);
      }
      prev = v;
    }
    return series;
  }

  /// Returns the index of the row containing column headers, or -1.
  static int _findHeaderRow(List<List<Data?>> rows) {
    final last = rows.length > 15 ? 15 : rows.length;
    for (var i = 0; i < last; i++) {
      final cells = rows[i].map(_cellText).toList();
      final nonEmpty = cells.where((c) => c.isNotEmpty).length;
      if (nonEmpty < 2) continue;
      final hasMeter = cells.any((c) => c.toLowerCase().contains('meter'));
      final hasDate = cells.any((c) => c.toLowerCase().contains('date'));
      final hasKwh = cells.any(
        (c) =>
            c.toLowerCase().contains('kwh') ||
            c.toLowerCase().contains('unit') ||
            c.toLowerCase().contains('reading'),
      );
      if (hasMeter || (hasDate && hasKwh)) return i;
    }
    return -1;
  }

  static _ColumnMap _mapColumns(List<Data?> header) {
    bool has(String text, List<String> needles) {
      final t = text.toLowerCase();
      return needles.any(t.contains);
    }

    final map = _ColumnMap();
    for (var i = 0; i < header.length; i++) {
      final h = _cellText(header[i]).toLowerCase();
      if (h.isEmpty) continue;
      final isCurrent =
          has(h, ['current', 'present', 'this']) ||
          (h.contains('reading') && !has(h, ['previous', 'last']));
      final isPrev = has(h, ['previous', 'prev', 'last']);
      final isKvah = h.contains('kvah');
      final isReactive = h.contains('rkvarh') || h.contains('reactive');
      final isLag = h.contains('lag');
      final isLead = h.contains('lead');

      if (map.meter == null && has(h, ['meter'])) {
        map.meter = i;
      } else if (map.date == null && has(h, ['date'])) {
        map.date = i;
      } else if (isReactive && (isLag || isLead)) {
        if (isLag && map.lag == null) map.lag = i;
        if (isLead && map.lead == null) map.lead = i;
      } else if (!isKvah &&
          !isLag &&
          !isLead &&
          has(h, ['md', 'demand', 'mdi'])) {
        map.md ??= i;
      } else if (!isKvah &&
          (h.contains('kwh') ||
              h.contains('reading') ||
              has(h, ['unit', 'consum']))) {
        if (isCurrent && map.currentKwh == null) {
          map.currentKwh = i;
        } else if (isPrev && map.prevKwh == null) {
          map.prevKwh = i;
        } else if (!isCurrent && !isPrev && map.kwh == null) {
          map.kwh = i;
        }
      } else if (isKvah && !isLag && !isLead) {
        if (isCurrent && map.currentKvah == null) {
          map.currentKvah = i;
        } else if (isPrev && map.prevKvah == null) {
          map.prevKvah = i;
        } else if (!isCurrent && !isPrev && map.kvah == null) {
          map.kvah = i;
        }
      }
    }
    return map;
  }

  /// Consumed value = explicit column, or current − previous when the file
  /// carries cumulative readings.
  static double _resolveConsumed(
    List<Data?> row,
    int? direct,
    int? current,
    int? prev,
  ) {
    if (direct != null) {
      final v = _cellNumber(row[direct]);
      if (v != null && v > 0) return v;
    }
    if (current != null && prev != null) {
      final c = _cellNumber(row[current]);
      final p = _cellNumber(row[prev]);
      if (c != null && p != null && c >= p) return c - p;
    }
    return 0;
  }

  static bool _isRowEmpty(List<Data?> row) {
    for (final cell in row) {
      if (_cellText(cell).isNotEmpty) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Cell helpers
  // ---------------------------------------------------------------------------

  static String _cellText(Data? data) {
    if (data == null) return '';
    final v = data.value;
    if (v is TextCellValue) return v.value.text?.trim() ?? '';
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toString();
    if (v is BoolCellValue) return v.value.toString();
    return '';
  }

  static double? _cellNumber(Data? data) {
    if (data == null) return null;
    final v = data.value;
    if (v is IntCellValue) return v.value.toDouble();
    if (v is DoubleCellValue) return v.value;
    final s = _cellText(data).replaceAll(',', '').replaceAll(
      RegExp(r'[₹\s]'),
      '',
    );
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static DateTime? _cellDate(Data? data) {
    if (data == null) return null;
    final v = data.value;
    if (v is DateCellValue) return DateTime(v.year, v.month, v.day);
    if (v is DateTimeCellValue) {
      return DateTime(v.year, v.month, v.day, v.hour, v.minute);
    }
    if (v is IntCellValue) return _fromExcelSerial(v.value.toDouble());
    if (v is DoubleCellValue) return _fromExcelSerial(v.value);
    return _parseDateString(_cellText(data));
  }

  /// Excel stores dates as days since 1899-12-30.
  static DateTime? _fromExcelSerial(double serial) {
    if (serial <= 0 || serial > 100000) return null;
    return DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
  }

  /// Parses dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy or yyyy-mm-dd.
  static DateTime? _parseDateString(String raw) {
    final text = raw.trim().split(' ').first;
    if (text.isEmpty) return null;
    final parts = text.split(RegExp(r'[/\-.]'));
    if (parts.length != 3) return null;

    final yearRaw = int.tryParse(parts[2]);
    if (yearRaw == null) return null;

    if (parts[0].length == 4) {
      final month = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (month == null || day == null) return null;
      return _validDate(yearRaw, month, day);
    }

    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) return null;
    var year = yearRaw;
    if (year < 100) year += 2000;
    // dd/mm/yyyy first (India convention); swap only when that is invalid.
    var day = a;
    var month = b;
    if (month < 1 || month > 12) {
      day = b;
      month = a;
    }
    return _validDate(year, month, day);
  }

  static DateTime? _validDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }
}

class _ColumnMap {
  int? meter;
  int? date;
  int? kwh;
  int? currentKwh;
  int? prevKwh;
  int? kvah;
  int? currentKvah;
  int? prevKvah;
  int? lag;
  int? lead;
  int? md;
}
