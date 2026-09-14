import '../../models/db_connection.dart';
import 'db_driver.dart';
import 'mysql_db_driver.dart';

/// Builds the right [DbDriver] for [connection.engine], pointed at
/// [effectiveHost]:[effectivePort] - the real target for a direct
/// connection, or `127.0.0.1:<local forward port>` when tunneling through
/// an SSH host (see `lib/session/db_session.dart`).
DbDriver createDbDriver(
  DbConnection connection, {
  required String effectiveHost,
  required int effectivePort,
  required String password,
}) {
  switch (connection.engine) {
    case DbEngine.mysql:
    case DbEngine.mariadb:
      return MySqlDbDriver(
        host: effectiveHost,
        port: effectivePort,
        username: connection.username,
        password: password,
        initialDatabase: connection.database,
      );
    case DbEngine.postgres:
      throw UnimplementedError('Dukungan PostgreSQL belum tersedia');
    case DbEngine.sqlite:
      throw UnimplementedError('Dukungan SQLite belum tersedia');
  }
}
