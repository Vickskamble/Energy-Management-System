import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../utils/app_logger.dart';

/// A single reading extracted from a PDF bill.
///
/// Values are placeholders from the parser — the user confirms/edits them in
/// the import preview before anything is saved (Issue 11, point 4).
class PdfReadingDraft {
  PdfReadingDraft({
    this.meterName = '',
    required this.loggedAt,
    this.kwh = 0,
    this.kvah = 0,
    this.rkvarhLag = 0,
    this.rkvarhLead = 0,
    this.mdRecorded = 0,
    required this.sourcePage,
  });

  String meterName;
  DateTime loggedAt;
  double kwh;
  double kvah;
  double rkvarhLag;
  double rkvarhLead;
  double mdRecorded;
  final int sourcePage;

  bool get isValid => kwh > 0 && mdRecorded > 0;
}

/// Bulk PDF import — Phase 1 (ISSUES_AND_SOLUTIONS.md, Feature: Bulk Data
/// Upload). Text-based PDFs only; scanned/OCR PDFs land in Phase 2.
///
/// Parsing is intentionally label-based (Issue 11) instead of position-based:
/// each page's text is scanned for known labels (kWh, kVAh, MD, PF, dates)
/// and numbers are picked up from the line that carries the label.
class PdfImportService {
  PdfImportService._();

  static Future<List<PdfReadingDraft>> extractReadings(Uint8List bytes) async {
    final doc = await PdfDocument.openData(bytes);
    try {
      final readings = <PdfReadingDraft>[];
      final count = doc.pages.length;
      for (var i = 0; i < count; i++) {
        try {
          final page = doc.pages[i];
          await page.ensureLoaded();
          final rawText = await page.loadText();
          if (rawText == null || rawText.fullText.trim().isEmpty) continue;
          final draft = parseBillText(rawText.fullText, pageIndex: i + 1);
          if (draft != null) readings.add(draft);
        } catch (e) {
          AppLogger.w('PDF page ${i + 1} parse failed: $e');
        }
      }
      if (readings.isEmpty) {
        throw const FormatException(
          'No meter readings found in the selected PDF. '
          'Text-based bills are supported; scanned/image PDFs are not yet '
          'supported (Phase 2).',
        );
      }
      return readings;
    } finally {
      await doc.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Label-based parsing (Issue 11 — format flexibility)
  // ---------------------------------------------------------------------------

  /// Label-based parsing of one page's raw text (Issue 11 — format
  /// flexibility). Pure Dart — testable without a PDF engine; returns null
  /// when the page is not an energy bill.
  static PdfReadingDraft? parseBillText(String rawText,
      {required int pageIndex}) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final loggedAt = _findBillDate(lines);
    final kwh = _findUnitsConsumed(lines);
    final md = _findMaxDemand(lines);
    final kvah = _findKvah(lines);
    final pf = _findPowerFactor(lines);
    final (lag, lead) = _findRkvarh(lines);

    // Not an energy bill page — skip silently.
    if (kwh == null && md == null && kvah == null) return null;

    final resolvedKvah = kvah ??
        ((kwh != null && pf != null && pf > 0) ? kwh / pf : 0);

    return PdfReadingDraft(
      loggedAt: loggedAt,
      kwh: kwh ?? 0,
      kvah: resolvedKvah,
      rkvarhLag: lag,
      rkvarhLead: lead,
      mdRecorded: md ?? 0,
      sourcePage: pageIndex,
    );
  }

  /// Preferred source: lines that explicitly state units/consumption.
  /// Fallback: present reading − previous reading (cumulative meters).
  static double? _findUnitsConsumed(List<String> lines) {
    final explicit = _numberForLabel(
      lines,
      RegExp(r'units?|consumed|consumption|energy\s*used', caseSensitive: false),
      skipDateLines: true,
    );
    if (explicit != null && explicit > 0) return explicit;

    final current = _numberForLabel(
      lines,
      RegExp(r'(present|current).*(kwh|kva\s?h)', caseSensitive: false),
      skipDateLines: true,
    );
    final previous = _numberForLabel(
      lines,
      RegExp(r'(previous|last).*(kwh|kva\s?h)', caseSensitive: false),
      skipDateLines: true,
    );
    if (current != null && previous != null && current >= previous) {
      return current - previous;
    }
    return null;
  }

  static double? _findMaxDemand(List<String> lines) {
    return _numberForLabel(
      lines,
      RegExp(r'max(imum)?\s*demand|recorded\s*demand|demand\s*\(kva\)|\bmdi\b|\bmd\b',
          caseSensitive: false),
      skipDateLines: true,
    );
  }

  static double? _findKvah(List<String> lines) {
    return _numberForLabel(
      lines,
      RegExp(r'kvah|kva\s*h(ours?)?', caseSensitive: false),
      skipDateLines: true,
    );
  }

  static double? _findPowerFactor(List<String> lines) {
    for (final line in lines) {
      if (!RegExp(r'power\s*factor|\bpf\b|p\.?\s*f\.?', caseSensitive: false)
          .hasMatch(line)) {
        continue;
      }
      final numbers = _extractNumbers(line);
      for (final n in numbers) {
        if (n > 0 && n <= 1) return n;
      }
    }
    return null;
  }

  /// Returns (lag, lead) reactive energy from rkVARh lines.
  static (double, double) _findRkvarh(List<String> lines) {
    final numbers = <double>[];
    for (final line in lines) {
      if (!RegExp(r'rkvarh|reactive', caseSensitive: false).hasMatch(line)) {
        continue;
      }
      numbers.addAll(_extractNumbers(line));
    }
    if (numbers.isEmpty) return (0, 0);
    return (numbers[0], numbers.length > 1 ? numbers[1] : 0);
  }

  static DateTime _findBillDate(List<String> lines) {
    final dateRe = RegExp(r'\b(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})\b');
    for (final line in lines) {
      if (!RegExp(r'bill\s*date|issue\s*date|reading\s*date|statement\s*date',
              caseSensitive: false)
          .hasMatch(line)) {
        continue;
      }
      final m = dateRe.firstMatch(line);
      if (m != null) {
        final d = _parseDate(m.group(1)!);
        if (d != null) return d;
      }
    }
    for (final line in lines) {
      final m = dateRe.firstMatch(line);
      if (m != null) {
        final d = _parseDate(m.group(1)!);
        if (d != null) return d;
      }
    }
    return DateTime.now();
  }

  /// First number on a line that matches [label] (skipping date-like lines).
  static double? _numberForLabel(
    List<String> lines,
    RegExp label, {
    bool skipDateLines = true,
  }) {
    final dateRe = RegExp(r'\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}');
    for (final line in lines) {
      if (!label.hasMatch(line)) continue;
      if (skipDateLines && dateRe.hasMatch(line)) continue;
      final numbers = _extractNumbers(line);
      if (numbers.isNotEmpty) return numbers.first;
    }
    return null;
  }

  static List<double> _extractNumbers(String line) {
    final re = RegExp(r'\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?');
    final result = <double>[];
    for (final m in re.allMatches(line)) {
      final v = double.tryParse(m.group(0)!.replaceAll(',', ''));
      if (v != null) result.add(v);
    }
    return result;
  }

  /// Parses dd/mm/yyyy or mm/dd/yyyy (Indian bills are dd/mm).
  static DateTime? _parseDate(String raw) {
    final parts = raw.split(RegExp(r'[/\-.]'));
    if (parts.length != 3) return null;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    var year = int.tryParse(parts[2]);
    if (a == null || b == null || year == null) return null;
    if (year < 100) year += 2000;

    final day = a > 12 ? a : b;
    final month = a > 12 ? b : a;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }
}
