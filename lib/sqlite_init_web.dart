import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

bool _sqliteInitDone = false;

/// Web: SQLite via wasm (requires `dart run sqflite_common_ffi_web:setup`).
Future<void> initSqlite() async {
  if (_sqliteInitDone) return;
  _sqliteInitDone = true;
  databaseFactory = databaseFactoryFfiWeb;
}
