import 'package:flutter/foundation.dart';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _sqliteInitDone = false;

Future<void> initSqlite() async {
  if (_sqliteInitDone) return;
  _sqliteInitDone = true;

  switch (defaultTargetPlatform) {
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      return;
    default:
      databaseFactory = databaseFactorySqflitePlugin;
  }
}

