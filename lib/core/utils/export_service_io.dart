import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveCsv(String content, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);

  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: 'EMS Readings Export'),
  );
}
