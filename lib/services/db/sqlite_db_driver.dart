import 'package:sqflite/sqflite.dart';

import 'db_driver.dart';

/// Wraps a local `sqflite` [Database] opened from [filePath] - either a
/// file already on the device, or one downloaded from an SSH host over
/// SFTP into a temp file first (see `lib/session/db_session.dart`).
///
/// SQLite has a single implicit "database" per file and no user/role
/// concept, so [listDatabases] returns one synthetic `main` entry (kept so
/// the workspace screen's database/table picker works the same way across
/// every engine) and the user-management methods are all unreachable in
/// the UI ([supportsUserManagement] is false) - they throw if called
/// directly.
class SqliteDbDriver implements DbDriver {
  SqliteDbDriver({required this.filePath});

  final String filePath;
  Database? _db;

  Database get _connection {
    final d = _db;
    if (d == null) throw StateError('Not connected');
    return d;
  }

  @override
  Future<void> open() async {
    _db = await openDatabase(filePath, readOnly: false);
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  String _escapeIdent(String s) => '"${s.replaceAll('"', '""')}"';

  @override
  Future<List<String>> listDatabases() async => const ['main'];

  @override
  Future<List<String>> listTables(String database) async {
    final rows = await _connection.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    return rows.map((r) => r['name'] as String).toList();
  }

  @override
  Future<List<DbColumn>> listColumns(String database, String table) async {
    final rows = await _connection.rawQuery(
      'PRAGMA table_info(${_escapeIdent(table)})',
    );
    return rows
        .map(
          (r) => DbColumn(
            name: r['name'] as String,
            type: (r['type'] as String?) ?? '',
            nullable: (r['notnull'] as int? ?? 0) == 0,
            isPrimaryKey: (r['pk'] as int? ?? 0) > 0,
          ),
        )
        .toList();
  }

  @override
  Future<DbQueryResult> execute(String sql, {String? database}) async {
    final stopwatch = Stopwatch()..start();
    final trimmed = sql.trim().toUpperCase();
    final isRead =
        trimmed.startsWith('SELECT') ||
        trimmed.startsWith('PRAGMA') ||
        trimmed.startsWith('EXPLAIN') ||
        trimmed.startsWith('WITH');

    if (isRead) {
      final rows = await _connection.rawQuery(sql);
      stopwatch.stop();
      // sqflite's rawQuery exposes column names only via the returned
      // rows' map keys, so a zero-row SELECT can't show column headers -
      // a known limitation of this engine's simple query path.
      final columns = rows.isEmpty ? <String>[] : rows.first.keys.toList();
      final data = rows
          .map((row) => [for (final c in columns) row[c]])
          .toList();
      return DbQueryResult(columns: columns, rows: data, elapsed: stopwatch.elapsed);
    }

    await _connection.execute(sql);
    final changesResult = await _connection.rawQuery('SELECT changes() AS c');
    final affected = changesResult.isNotEmpty
        ? changesResult.first['c'] as int?
        : null;
    stopwatch.stop();
    return DbQueryResult(
      columns: const [],
      rows: const [],
      affectedRows: affected,
      elapsed: stopwatch.elapsed,
    );
  }

  @override
  bool get supportsUserManagement => false;

  @override
  Future<List<DbUser>> listUsers() =>
      throw UnsupportedError('SQLite has no user/role concept');

  @override
  Future<void> createUser(String username, String password, {String? host}) =>
      throw UnsupportedError('SQLite has no user/role concept');

  @override
  Future<void> dropUser(String username, {String? host}) =>
      throw UnsupportedError('SQLite has no user/role concept');

  @override
  Future<List<String>> listGrants(String username, {String? host}) =>
      throw UnsupportedError('SQLite has no user/role concept');

  @override
  Future<void> grant(
    String privilege,
    String onDatabase,
    String user, {
    String? host,
  }) => throw UnsupportedError('SQLite has no user/role concept');

  @override
  Future<void> revoke(
    String privilege,
    String onDatabase,
    String user, {
    String? host,
  }) => throw UnsupportedError('SQLite has no user/role concept');
}
