import 'package:postgres/postgres.dart';

import 'db_driver.dart';

/// Wraps [Connection] (`postgres` package, pure Dart).
///
/// Postgres has no MySQL-style "list every database, `USE` one mid
/// session" - switching to a different actual database requires a new TCP
/// connection. So here, and in the workspace screen that calls it, treat
/// [listDatabases]/[execute]'s `database` argument as a **schema** inside
/// the database this connection is already scoped to (`connection`'s
/// `database` field / `public` by default) rather than a real Postgres
/// database - the same simplification most lightweight Postgres GUI tools
/// make.
class PostgresDbDriver implements DbDriver {
  PostgresDbDriver({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.initialDatabase,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final String? initialDatabase;

  Connection? _conn;

  Connection get _connection {
    final c = _conn;
    if (c == null) throw StateError('Not connected');
    return c;
  }

  @override
  Future<void> open() async {
    final conn = await Connection.open(
      Endpoint(
        host: host,
        port: port,
        database: initialDatabase ?? 'postgres',
        username: username,
        password: password,
      ),
      // Reached over an SSH tunnel (or directly on an internal network) -
      // the far end rarely has TLS configured for that, and SSH already
      // encrypts the tunnel leg when tunneling.
      settings: const ConnectionSettings(sslMode: SslMode.disable),
    );
    _conn = conn;
  }

  @override
  Future<void> close() async {
    await _conn?.close();
    _conn = null;
  }

  String _escapeIdent(String s) => '"${s.replaceAll('"', '""')}"';
  String _escapeLiteral(String s) => "'${s.replaceAll("'", "''")}'";

  @override
  Future<List<String>> listDatabases() async {
    final result = await _connection.execute(
      "SELECT schema_name FROM information_schema.schemata "
      "WHERE schema_name NOT IN ('pg_catalog', 'information_schema') "
      "AND schema_name NOT LIKE 'pg_toast%' AND schema_name NOT LIKE 'pg_temp%' "
      'ORDER BY schema_name',
    );
    return result.map((row) => row[0] as String).toList();
  }

  @override
  Future<List<String>> listTables(String database) async {
    final schema = database.isEmpty ? 'public' : database;
    final result = await _connection.execute(
      'SELECT tablename FROM pg_tables WHERE schemaname = '
      '${_escapeLiteral(schema)} ORDER BY tablename',
    );
    return result.map((row) => row[0] as String).toList();
  }

  @override
  Future<List<DbColumn>> listColumns(String database, String table) async {
    final schema = database.isEmpty ? 'public' : database;
    final escapedSchema = _escapeLiteral(schema);
    final escapedTable = _escapeLiteral(table);

    final columnsResult = await _connection.execute(
      'SELECT column_name, data_type, is_nullable FROM information_schema.columns '
      'WHERE table_schema = $escapedSchema AND table_name = $escapedTable '
      'ORDER BY ordinal_position',
    );
    final pkResult = await _connection.execute(
      'SELECT kcu.column_name FROM information_schema.table_constraints tc '
      'JOIN information_schema.key_column_usage kcu '
      'ON tc.constraint_name = kcu.constraint_name '
      'AND tc.table_schema = kcu.table_schema '
      "WHERE tc.constraint_type = 'PRIMARY KEY' "
      'AND tc.table_schema = $escapedSchema AND tc.table_name = $escapedTable',
    );
    final pkColumns = pkResult.map((r) => r[0] as String).toSet();

    return columnsResult.map((r) {
      final name = r[0] as String;
      return DbColumn(
        name: name,
        type: r[1] as String,
        nullable: (r[2] as String) == 'YES',
        isPrimaryKey: pkColumns.contains(name),
      );
    }).toList();
  }

  @override
  Future<DbQueryResult> execute(String sql, {String? database}) async {
    final stopwatch = Stopwatch()..start();
    if (database != null && database.isNotEmpty) {
      await _connection.execute('SET search_path TO ${_escapeIdent(database)}');
    }
    final result = await _connection.execute(sql);
    stopwatch.stop();
    final columns = result.schema.columns
        .map((c) => c.columnName ?? '')
        .toList();
    final rows = result
        .map((row) => [for (var i = 0; i < columns.length; i++) row[i]])
        .toList();
    return DbQueryResult(
      columns: columns,
      rows: rows,
      affectedRows: result.affectedRows,
      elapsed: stopwatch.elapsed,
    );
  }

  @override
  bool get supportsUserManagement => true;

  @override
  Future<List<DbUser>> listUsers() async {
    final result = await _connection.execute(
      "SELECT rolname, rolcanlogin FROM pg_roles "
      "WHERE rolname NOT LIKE 'pg\\_%' ORDER BY rolname",
    );
    return result
        .map(
          (r) => DbUser(
            username: r[0] as String,
            canLogin: r[1] as bool,
          ),
        )
        .toList();
  }

  @override
  Future<void> createUser(
    String username,
    String password, {
    String? host,
  }) async {
    assertSafeDbIdentifier(username, 'username');
    await _connection.execute(
      'CREATE ROLE ${_escapeIdent(username)} LOGIN PASSWORD '
      '${_escapeLiteral(password)}',
    );
  }

  @override
  Future<void> dropUser(String username, {String? host}) async {
    assertSafeDbIdentifier(username, 'username');
    await _connection.execute('DROP ROLE ${_escapeIdent(username)}');
  }

  @override
  Future<List<String>> listGrants(String username, {String? host}) async {
    assertSafeDbIdentifier(username, 'username');
    final result = await _connection.execute(
      'SELECT table_schema, table_name, privilege_type '
      'FROM information_schema.role_table_grants '
      'WHERE grantee = ${_escapeLiteral(username)} '
      'ORDER BY table_schema, table_name, privilege_type',
    );
    return result
        .map((r) => '${r[0]}.${r[1]}: ${r[2]}')
        .toList();
  }

  /// [privilege] is interpolated verbatim into the statement - callers must
  /// pass one of a fixed, code-defined set of privilege keywords (e.g. from
  /// a dropdown), never free-typed user input. [onDatabase] is treated as a
  /// schema, same as elsewhere in this driver.
  @override
  Future<void> grant(
    String privilege,
    String onDatabase,
    String user, {
    String? host,
  }) async {
    assertSafeDbIdentifier(user, 'username');
    await _connection.execute(
      'GRANT $privilege ON ALL TABLES IN SCHEMA ${_escapeIdent(onDatabase)} '
      'TO ${_escapeIdent(user)}',
    );
  }

  @override
  Future<void> revoke(
    String privilege,
    String onDatabase,
    String user, {
    String? host,
  }) async {
    assertSafeDbIdentifier(user, 'username');
    await _connection.execute(
      'REVOKE $privilege ON ALL TABLES IN SCHEMA ${_escapeIdent(onDatabase)} '
      'FROM ${_escapeIdent(user)}',
    );
  }
}
