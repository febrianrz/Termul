/// Column metadata from `listColumns`.
class DbColumn {
  final String name;
  final String type;
  final bool nullable;
  final bool isPrimaryKey;

  DbColumn({
    required this.name,
    required this.type,
    required this.nullable,
    required this.isPrimaryKey,
  });
}

/// One DB user/role, as returned by `listUsers`.
class DbUser {
  final String username;

  /// The host pattern a MySQL/MariaDB user is scoped to (e.g. `%`,
  /// `localhost`). `null` for engines without this concept (Postgres).
  final String? host;
  final bool canLogin;

  DbUser({required this.username, this.host, this.canLogin = true});
}

/// The result of running one query: column names in display order, each row
/// as a list of values in that same order, how many rows a DML statement
/// touched (if applicable), and how long the query took.
class DbQueryResult {
  final List<String> columns;
  final List<List<Object?>> rows;
  final int? affectedRows;
  final Duration elapsed;

  DbQueryResult({
    required this.columns,
    required this.rows,
    this.affectedRows,
    required this.elapsed,
  });
}

/// A connection to one database server, abstracting over the wire protocol
/// (MySQL/MariaDB, later Postgres/SQLite) behind one interface the
/// Database-tab screens can share. Implementations: [MySqlDbDriver]
/// (`lib/services/db/mysql_db_driver.dart`) for now.
abstract class DbDriver {
  Future<void> open();
  Future<void> close();

  Future<List<String>> listDatabases();
  Future<List<String>> listTables(String database);
  Future<List<DbColumn>> listColumns(String database, String table);
  Future<DbQueryResult> execute(String sql, {String? database});

  /// Whether this engine has a user/role concept at all (false for SQLite).
  bool get supportsUserManagement;

  Future<List<DbUser>> listUsers();
  Future<void> createUser(String username, String password, {String? host});
  Future<void> dropUser(String username, {String? host});
  Future<List<String>> listGrants(String username, {String? host});
  Future<void> grant(
    String privilege,
    String onDatabase,
    String user, {
    String? host,
  });
  Future<void> revoke(
    String privilege,
    String onDatabase,
    String user, {
    String? host,
  });
}

/// SQL identifiers (usernames, database/table names used in DDL like
/// `CREATE USER`/`GRANT`, which can't be parameter-bound) must be validated
/// against this before being interpolated into a query string - callers
/// that skip this open a SQL-injection hole in the admin features.
final RegExp dbIdentifierPattern = RegExp(r'^[A-Za-z0-9_\-\$]+$');

void assertSafeDbIdentifier(String value, String what) {
  if (!dbIdentifierPattern.hasMatch(value)) {
    throw ArgumentError('Invalid $what: $value');
  }
}
