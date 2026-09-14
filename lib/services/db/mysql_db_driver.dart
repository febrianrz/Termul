import 'package:mysql_client/mysql_client.dart';

import 'db_driver.dart';

/// Wraps [MySQLConnection] (`mysql_client` package, pure Dart) - MySQL and
/// MariaDB share this wire protocol, so one driver covers both engines.
class MySqlDbDriver implements DbDriver {
  MySqlDbDriver({
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

  MySQLConnection? _conn;

  MySQLConnection get _connection {
    final c = _conn;
    if (c == null) throw StateError('Not connected');
    return c;
  }

  @override
  Future<void> open() async {
    final conn = await MySQLConnection.createConnection(
      host: host,
      port: port,
      userName: username,
      password: password,
      // Reached over an SSH tunnel (or directly on an internal network) -
      // the far end rarely has TLS configured for that, and SSH already
      // encrypts the tunnel leg when tunneling.
      secure: false,
      databaseName: initialDatabase,
    );
    await conn.connect(timeoutMs: 15000);
    _conn = conn;
  }

  @override
  Future<void> close() async {
    await _conn?.close();
    _conn = null;
  }

  String _escapeIdent(String s) => '`${s.replaceAll('`', '``')}`';

  @override
  Future<List<String>> listDatabases() async {
    final result = await _connection.execute('SHOW DATABASES');
    return result.rows.map((r) => r.colAt(0) ?? '').toList();
  }

  @override
  Future<List<String>> listTables(String database) async {
    final result = await _connection.execute(
      'SHOW TABLES FROM ${_escapeIdent(database)}',
    );
    return result.rows.map((r) => r.colAt(0) ?? '').toList();
  }

  @override
  Future<List<DbColumn>> listColumns(String database, String table) async {
    final result = await _connection.execute(
      'SHOW COLUMNS FROM ${_escapeIdent(database)}.${_escapeIdent(table)}',
    );
    return result.rows
        .map(
          (r) => DbColumn(
            name: r.colByName('Field') ?? '',
            type: r.colByName('Type') ?? '',
            nullable: (r.colByName('Null') ?? 'YES') == 'YES',
            isPrimaryKey: (r.colByName('Key') ?? '') == 'PRI',
          ),
        )
        .toList();
  }

  @override
  Future<DbQueryResult> execute(String sql, {String? database}) async {
    final stopwatch = Stopwatch()..start();
    if (database != null) {
      await _connection.execute('USE ${_escapeIdent(database)}');
    }
    final result = await _connection.execute(sql);
    stopwatch.stop();
    final columns = result.cols.map((c) => c.name).toList();
    final rows = result.rows
        .map((r) => [for (final c in columns) r.colByName(c)])
        .toList();
    return DbQueryResult(
      columns: columns,
      rows: rows,
      affectedRows: result.affectedRows.toInt(),
      elapsed: stopwatch.elapsed,
    );
  }

  @override
  bool get supportsUserManagement => true;

  @override
  Future<List<DbUser>> listUsers() async {
    final result = await _connection.execute(
      'SELECT User, Host FROM mysql.user ORDER BY User',
    );
    return result.rows
        .map(
          (r) => DbUser(
            username: r.colByName('User') ?? '',
            host: r.colByName('Host'),
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
    final h = host ?? '%';
    assertSafeDbIdentifier(h, 'host');
    final escapedPassword = password.replaceAll("'", "''");
    await _connection.execute(
      "CREATE USER '$username'@'$h' IDENTIFIED BY '$escapedPassword'",
    );
  }

  @override
  Future<void> dropUser(String username, {String? host}) async {
    assertSafeDbIdentifier(username, 'username');
    final h = host ?? '%';
    assertSafeDbIdentifier(h, 'host');
    await _connection.execute("DROP USER '$username'@'$h'");
  }

  @override
  Future<List<String>> listGrants(String username, {String? host}) async {
    assertSafeDbIdentifier(username, 'username');
    final h = host ?? '%';
    assertSafeDbIdentifier(h, 'host');
    final result = await _connection.execute(
      "SHOW GRANTS FOR '$username'@'$h'",
    );
    return result.rows.map((r) => r.colAt(0) ?? '').toList();
  }

  /// [privilege] is interpolated verbatim into the statement - callers must
  /// pass one of a fixed, code-defined set of privilege keywords (e.g. from
  /// a dropdown), never free-typed user input.
  @override
  Future<void> grant(
    String privilege,
    String onDatabase,
    String user, {
    String? host,
  }) async {
    assertSafeDbIdentifier(user, 'username');
    final h = host ?? '%';
    assertSafeDbIdentifier(h, 'host');
    await _connection.execute(
      'GRANT $privilege ON ${_escapeIdent(onDatabase)}.* '
      "TO '$user'@'$h'",
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
    final h = host ?? '%';
    assertSafeDbIdentifier(h, 'host');
    await _connection.execute(
      'REVOKE $privilege ON ${_escapeIdent(onDatabase)}.* '
      "FROM '$user'@'$h'",
    );
  }
}
