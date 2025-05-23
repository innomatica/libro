import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';

import 'schema.dart';

class DatabaseException implements Exception {
  DatabaseException(this.cause);
  String cause;
}

class DatabaseService {
  Database? _db;
  // ignore: unused_field
  final _logger = Logger('Sqlite');

  Future<Database> _getDatabase() async {
    return _db ??= await openDatabase(
      dbname,
      version: dbversion,
      onCreate: (db, version) async {
        _logger.fine('oncreate: $db, $version');
        await db.execute(resourceSchema);
        await db.execute(serverSchema);
      },
    );
  }

  Future<void> close() async {
    final db = await _getDatabase();
    db.close();
  }

  Future<void> execute(String sql, [List<Object?>? args]) async {
    try {
      final db = await _getDatabase();
      return await db.execute(sql, args);
    } on Exception catch (e) {
      _logger.info(e.toString());
      rethrow;
    }
  }

  Future<int> insert(String sql, [List<Object?>? args]) async {
    try {
      final db = await _getDatabase();
      return await db.rawInsert(sql, args);
    } on Exception catch (e) {
      _logger.info(e.toString());
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> queryAll(
    String sql, [
    List<Object?>? args,
  ]) async {
    try {
      final db = await _getDatabase();
      return await db.rawQuery(sql, args);
    } on Exception catch (e) {
      _logger.info(e.toString());
      rethrow;
    }
  }

  Future<Map<String, Object?>?> query(String sql, [List<Object?>? args]) async {
    try {
      final db = await _getDatabase();
      final res = await db.rawQuery(sql, args);
      return res.isNotEmpty ? res.first : null;
    } on Exception catch (e) {
      _logger.info(e.toString());
      rethrow;
    }
  }

  Future<int> update(String sql, [List<Object?>? args]) async {
    try {
      final db = await _getDatabase();
      return await db.rawUpdate(sql, args);
    } on Exception catch (e) {
      _logger.info(e.toString());
      rethrow;
    }
  }

  Future<int> delete(String sql, [List<Object?>? args]) async {
    try {
      final db = await _getDatabase();
      return await db.rawDelete(sql, args);
    } on Exception catch (e) {
      _logger.info(e.toString());
      rethrow;
    }
  }
}
