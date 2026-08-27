import 'dart:typed_data';

/// Non-web fallback: nothing to do — native platforms use the share sheet.
Future<void> downloadPdf(Uint8List bytes, String fileName) async {}