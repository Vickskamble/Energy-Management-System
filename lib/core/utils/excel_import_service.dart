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
    this.exportKwh,
    this.exportKvah,
    this.generationKwh,
    required this.sourceLabel,
  });

  String meterName;
  DateTime loggedAt;
  double kwh;
  double kvah;
  double? currentKwh;
  double? currentKvah;
  double rkvarhLag;
  double rkvarhLead;
  double mdRecorded;
  double? powerFactor;
  double? exportKwh;
  double? exportKvah;
  double? generationKwh;
  final String sourceLabel;

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

    // User always enters ACTUAL cumulative meter readings. Convert to
    // per-day consumption by taking the difference from the previous row.
    // The first row is the opening baseline → consumption 0.
    // When columns are mapped as currentKwh/prevKwh, use currentKwh as the
    // cumulative source.
    final kwhSourceCol = cols.kwh ?? cols.currentKwh;
    final kvahSourceCol = cols.kvah ?? cols.currentKvah;
    final kwhSeries = kwhSourceCol != null
        ? _cumulativeSeries(rows, headerRow, kwhSourceCol)
        : null;
    final kvahSeries = kvahSourceCol != null
        ? _cumulativeSeries(rows, headerRow, kvahSourceCol)
        : null;
    final lagSeries = cols.lag != null
        ? _cumulativeSeries(rows, headerRow, cols.lag!)
        : null;
    final leadSeries = cols.lead != null
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

      // Consumed = current − previous.
      // When both currentKwh and prevKwh columns exist, compute per-row
      // directly. When only a single cumulative column exists, compute from
      // consecutive rows (cumulative series).
      final double kwh;
      if (cols.currentKwh != null && cols.prevKwh != null) {
        final c = _cellNumber(row[cols.currentKwh!]) ?? 0;
        final p = _cellNumber(row[cols.prevKwh!]) ?? 0;
        kwh = c >= p ? c - p : 0.0;
      } else {
        kwh =
            kwhSeries != null ? kwhSeries[i - (headerRow + 1)] : 0.0;
      }
      final double kvah;
      if (cols.currentKvah != null && cols.prevKvah != null) {
        final c = _cellNumber(row[cols.currentKvah!]) ?? 0;
        final p = _cellNumber(row[cols.prevKvah!]) ?? 0;
        kvah = c >= p ? c - p : 0.0;
      } else {
        kvah =
            kvahSeries != null ? kvahSeries[i - (headerRow + 1)] : 0.0;
      }

      // Actual (cumulative) meter reading from the Excel cell — stored so
      // Analysis/Reports can show the real meter values.
      final double? actualKwh =
          kwhSourceCol != null ? _cellNumber(row[kwhSourceCol]) : null;
      final double? actualKvah =
          kvahSourceCol != null ? _cellNumber(row[kvahSourceCol]) : null;
      final double lag =
          lagSeries != null ? lagSeries[i - (headerRow + 1)] : 0.0;
      final double lead =
          leadSeries != null ? leadSeries[i - (headerRow + 1)] : 0.0;
      final md = cols.md != null ? _cellNumber(row[cols.md!]) ?? 0 : 0.0;

      // PF from the client's file is stored as-is (never recalculated).
      // Excel often stores it as 0.85 or 0.853 — keep the raw value.
      final pfRaw = cols.pf != null ? _cellNumber(row[cols.pf!]) : null;
      final pf = (pfRaw != null && pfRaw > 0 && pfRaw <= 1)
          ? pfRaw
          : (pfRaw != null && pfRaw > 1 && pfRaw <= 100
              ? pfRaw / 100
              : null);

      final isFirstRow = i == headerRow + 1;
      if (kwh <= 0 && kvah <= 0 && md <= 0) continue;

      final exportKwh =
          cols.exportKwh != null ? _cellNumber(row[cols.exportKwh!]) : null;
      final exportKvah =
          cols.exportKvah != null ? _cellNumber(row[cols.exportKvah!]) : null;
      final generationKwh = cols.generationKwh != null
          ? _cellNumber(row[cols.generationKwh!])
          : null;

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
          exportKwh: exportKwh,
          exportKvah: exportKvah,
          generationKwh: generationKwh,
          sourceLabel: isFirstRow ? 'Row ${i + 1} (opening)' : 'Row ${i + 1}',
        ),
      );
    }
    return drafts;
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
        // Positive diff = consumption. Decrease = meter reset → 0 (new baseline).
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
      final isExport = has(h, ['export', 'feed', 'net export']);
      final isGeneration = has(h, ['generation', 'solar gen', 'total gen']);

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
      } else if (isGeneration) {
        map.generationKwh ??= i;
      } else if (isExport) {
        if (isKvah && map.exportKvah == null) {
          map.exportKvah = i;
        } else if (!isKvah && map.exportKwh == null) {
          map.exportKwh = i;
        }
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
    // Date-only cells (no time component) default to midday (12:00) instead
    // of midnight — midnight gets bucketed into the previous day's Night
    // slot and skews shift totals in the dashboard.
    if (v is DateCellValue) {
      return DateTime(v.year, v.month, v.day, 12);
    }
    if (v is DateTimeCellValue) {
      return DateTime(v.year, v.month, v.day, v.hour, v.minute);
    }
    if (v is IntCellValue) return _fromExcelSerial(v.value.toDouble());
    if (v is DoubleCellValue) return _fromExcelSerial(v.value);
    return _parseDateString(_cellText(data));
  }

  /// Excel stores dates as days since 1899-12-30; the fractional part is the
  /// time of day. Whole-day (integer) cells default to midday instead of
  /// midnight so they don't fall into the previous day's Night slot.
  static DateTime? _fromExcelSerial(double serial) {
    if (serial <= 0 || serial > 100000) return null;
    final base = DateTime(1899, 12, 30).add(Duration(days: serial.floor()));
    final fraction = serial - serial.floorToDouble();
    if (fraction <= 0 || fraction >= 1) {
      return DateTime(base.year, base.month, base.day, 12);
    }
    final minutes = (fraction * 24 * 60).round();
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return DateTime(base.year, base.month, base.day, h, m);
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
    // Midday default — see [_cellDate].
    return DateTime(year, month, day, 12);
  }

  /// Builds a ready-to-use .xlsx template that matches the column headers the
  /// importer auto-detects, so users have a concrete starting point instead of
  /// guessing the required layout.
  static Future<Uint8List> generateSampleTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel.sheets.values.first;

    const headers = [
      'Reading Date',
      'Meter Name',
      'kWh',
      'kVAh',
      'MD Recorded (kVA)',
      'PF',
      'rkVARh Lag',
      'rkVARh Lead',
      'Export kWh',
      'Generation kWh',
    ];
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[c]);
    }

    const samples = [
      ['01/06/2026', 'Main Meter', '1250.50', '1320.00', '145.0', '0.98', '120.0', '10.0', '0.0', '0.0'],
      ['02/06/2026', 'Main Meter', '1180.00', '1245.50', '142.5', '0.97', '115.0', '8.0', '0.0', '0.0'],
    ];
    for (var r = 0; r < samples.length; r++) {
      final row = samples[r];
      for (var c = 0; c < row.length; c++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1),
        );
        cell.value = TextCellValue(row[c]);
      }
    }

    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? []);
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
  int? exportKwh;
  int? exportKvah;
  int? generationKwh;
}
