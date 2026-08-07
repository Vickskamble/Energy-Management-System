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
    this.currentKwh,
    this.currentKvah,
    this.rkvarhLag = 0,
    this.rkvarhLead = 0,
    this.mdRecorded = 0,
    this.powerFactor,
    required this.sourceLabel,
  });

  String meterName;
  DateTime loggedAt;

  /// Consumed units for this period (current − previous).
  double kwh;
  double kvah;

  /// ACTUAL meter readings as recorded — the meter's cumulative total.
  /// Null when the file only carries per-day consumption values.
  double? currentKwh;
  double? currentKvah;

  double rkvarhLag;
  double rkvarhLead;
  double mdRecorded;

  /// PF as recorded in the client's file (column "PF"). Null when the file
  /// has no PF column — the system calculates it from kWh/kVAh instead.
  double? powerFactor;

  /// Human-readable source, e.g. "Row 5" (1-based Excel row number).
  final String sourceLabel;

  /// A draft is importable when it has consumption (kWh) OR an actual meter
  /// reading, plus a demand value. The opening row of a cumulative series
  /// (consumption 0, but a real meter reading) counts as importable — it
  /// anchors the actual-reading chain.
  bool get isValid => (kwh > 0 || (currentKwh ?? 0) > 0) && mdRecorded > 0;
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

  /// Max compressed workbook size (bytes) — guards against crafted files
  /// that exhaust memory (SECURITY.md gap G8).
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  /// Max readings extracted from a single file (row-count guard).
  static const int maxReadingsPerFile = 5000;

  static Future<List<ExcelReadingDraft>> extractReadings(
    Uint8List bytes, {
    ExcelColumnMap? columnMap,
  }) async {
    if (bytes.lengthInBytes > maxFileSizeBytes) {
      throw const FormatException(
        'Excel file is too large (max ${maxFileSizeBytes ~/ (1024 * 1024)} MB '
        'allowed). Please split the file and try again.',
      );
    }

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
      drafts.addAll(_parseSheet(sheet, columnMap));
      if (drafts.length > maxReadingsPerFile) break;
    }
    if (drafts.isEmpty) {
      throw const FormatException(
        'No readings found in the selected Excel file. '
        'Expected headers: Meter, Reading Date, kWh, MD Recorded '
        '(kVAh / rkVARh Lag / rkVARh Lead optional).',
      );
    }
    if (drafts.length > maxReadingsPerFile) {
      throw FormatException(
        'File has more than $maxReadingsPerFile readings. '
        'Split the file and import in batches.',
      );
    }
    return drafts;
  }

  // ---------------------------------------------------------------------------
  // Sheet parsing
  // ---------------------------------------------------------------------------

  /// Reads the header (column names) of the first data sheet. Used by the
  /// manual column-mapping UI so the user can assign each field.
  static Future<List<String>> readHeaders(Uint8List bytes) async {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      AppLogger.e('Excel decode failed', e);
      return const [];
    }
    for (final sheet in excel.tables.values) {
      final rows = sheet.rows;
      if (rows.isEmpty) continue;
      final headerRow = _findHeaderRow(rows);
      if (headerRow < 0) continue;
      return rows[headerRow].map(_cellText).toList();
    }
    return const [];
  }

  /// Best-effort automatic column detection. Returns a map the UI can present
  /// as default values before the user confirms.
  static ExcelColumnMap detectMapping(List<String> headers) {
    return _mapColumns(headers);
  }

  /// Whether an [ExcelColumnMap] has enough info to import rows.
  static bool hasValidMapping(ExcelColumnMap? map) {
    if (map == null) return false;
    return map.kwh != null || (map.currentKwh != null && map.prevKwh != null);
  }

  static List<ExcelReadingDraft> _parseSheet(
    Sheet sheet, [
    ExcelColumnMap? columnMap,
  ]) {
    final rows = sheet.rows;
    if (rows.isEmpty) return [];

    final headerRow = _findHeaderRow(rows);
    if (headerRow < 0) return [];
    final cols = columnMap ??
        _mapColumns(rows[headerRow].map(_cellText).toList());
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
    final lagCumulative = cols.lag != null &&
        _isCumulative(rows, headerRow, cols.lag!, minValue: 1000);
    final leadCumulative = cols.lead != null &&
        _isCumulative(rows, headerRow, cols.lead!, minValue: 1000);
    final kwhSeries = kwhCumulative
        ? _cumulativeSeries(rows, headerRow, cols.kwh!)
        : null;
    final kvahSeries = kvahCumulative
        ? _cumulativeSeries(rows, headerRow, cols.kvah!)
        : null;
    final lagSeries = lagCumulative
        ? _cumulativeSeries(rows, headerRow, cols.lag!)
        : null;
    final leadSeries = leadCumulative
        ? _cumulativeSeries(rows, headerRow, cols.lead!)
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

      // Actual (cumulative) meter readings — kept alongside consumed so the
      // client sees real meter values on Analysis/Reports. Available when the
      // file carries cumulative readings or explicit Current/Previous columns.
      final double? actualKwh;
      if (kwhSeries != null && cols.kwh != null) {
        actualKwh = _cellNumber(row[cols.kwh!]);
      } else if (cols.currentKwh != null) {
        actualKwh = _cellNumber(row[cols.currentKwh!]);
      } else {
        actualKwh = null;
      }
      final double? actualKvah;
      if (kvahSeries != null && cols.kvah != null) {
        actualKvah = _cellNumber(row[cols.kvah!]);
      } else if (cols.currentKvah != null) {
        actualKvah = _cellNumber(row[cols.currentKvah!]);
      } else {
        actualKvah = null;
      }
      final double lag;
      if (lagSeries != null) {
        lag = lagSeries[i - (headerRow + 1)];
      } else {
        lag = cols.lag != null ? _cellNumber(row[cols.lag!]) ?? 0 : 0.0;
      }
      final double lead;
      if (leadSeries != null) {
        lead = leadSeries[i - (headerRow + 1)];
      } else {
        lead = cols.lead != null
            ? _cellNumber(row[cols.lead!]) ?? 0
            : 0.0;
      }
      final md = cols.md != null ? _cellNumber(row[cols.md!]) ?? 0 : 0.0;

      // PF from the client's file is stored as-is (never recalculated).
      // Excel often stores it as 0.85 or 0.853 — keep the raw value.
      final pfRaw = cols.pf != null ? _cellNumber(row[cols.pf!]) : null;
      final pf = (pfRaw != null && pfRaw > 0 && pfRaw <= 1)
          ? pfRaw
          : (pfRaw != null && pfRaw > 1 && pfRaw <= 100
              ? pfRaw / 100
              : null);

      final baseline = kwhSeries != null && i == headerRow + 1;
      if (kwh <= 0 && kvah <= 0 && md <= 0) continue;

      drafts.add(
        ExcelReadingDraft(
          powerFactor: pf,
          meterName: meter,
          loggedAt: loggedAt,
          kwh: kwh,
          kvah: kvah,
          currentKwh: actualKwh,
          currentKvah: actualKvah,
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
    int col, {
    double minValue = 10000,
  }) {
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
    return nonDecreasing >= valid - 1 && minVal >= minValue;
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

  static ExcelColumnMap _mapColumns(List<String> header) {
    bool has(String text, List<String> needles) {
      final t = text.toLowerCase();
      return needles.any(t.contains);
    }

    final map = ExcelColumnMap();
    for (var i = 0; i < header.length; i++) {
      final h = header[i].toLowerCase();
      if (h.isEmpty) continue;
      final isCurrent =
          has(h, ['current', 'present', 'this']) ||
          (h.contains('reading') && !has(h, ['previous', 'last']));
      final isPrev = has(h, ['previous', 'prev', 'last']);
      final isKvah = h.contains('kvah');
      final isReactive = h.contains('kvarh') ||
          h.contains('rkvarh') ||
          h.contains('reactive');
      final isLag = h.contains('lag');
      final isLead = h.contains('lead');
      final isConst = has(h, ['const', 'multiplier', 'ct&pt', 'ct/pt']);

      if (map.meter == null && has(h, ['meter']) && !isConst) {
        map.meter = i;
      } else if (map.date == null && has(h, ['date'])) {
        map.date = i;
      } else if (map.pf == null &&
          (h == 'pf' || h.startsWith('pf') && h.length <= 4) &&
          !isKvah) {
        map.pf = i;
      } else if (isReactive && (isLag || isLead)) {
        if (isLag && map.lag == null) map.lag = i;
        if (isLead && map.lead == null) map.lead = i;
      } else if (!isKvah &&
          !isLag &&
          !isLead &&
          !isConst &&
          has(h, ['md', 'demand', 'mdi'])) {
        if (map.md == null || h.contains('kva')) map.md = i;
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

class ExcelColumnMap {
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
  int? pf;
}
