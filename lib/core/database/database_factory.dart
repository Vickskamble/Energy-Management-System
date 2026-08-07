import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart' as io;
import 'package:sembast_web/sembast_web.dart' as web;

DatabaseFactory getDatabaseFactory() {
  if (kIsWeb) return web.databaseFactoryWeb;
  return io.databaseFactoryIo;
}

/// Opens the shared local meta database at a STABLE location.
///
/// On IO platforms a bare relative name (`ems_meta.db`) is resolved against the
/// process working directory, which differs between launches (e.g. `flutter
/// run` vs. running the built exe). That silently lost the persisted device
/// token, so a fresh token was generated on every launch and the leftover
/// `user_sessions` row made SessionGuard report a false "already signed in on
/// another device" conflict. path_provider gives a fixed per-user directory.
/// On web the IndexedDB name is origin-stable.
Future<Database> openMetaDatabase() async {
  if (kIsWeb) return web.databaseFactoryWeb.openDatabase('ems_meta.db');
  final dir = await getApplicationSupportDirectory();
  return io.databaseFactoryIo.openDatabase('${dir.path}/ems_meta.db');
}
