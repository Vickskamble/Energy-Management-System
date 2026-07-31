import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveCsv(String content, String filename) =>
    saveBytes(Uint8List.fromList(content.codeUnits), filename, 'text/csv');

Future<void> saveBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      subject: 'EMS Report',
    ),
  );
}
