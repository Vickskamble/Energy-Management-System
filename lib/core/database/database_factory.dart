import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart' as io;
import 'package:sembast_web/sembast_web.dart' as web;
import 'package:flutter/foundation.dart' show kIsWeb;

DatabaseFactory getDatabaseFactory() {
  if (kIsWeb) return web.databaseFactoryWeb;
  return io.databaseFactoryIo;
}
