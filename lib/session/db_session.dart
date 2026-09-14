import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/db_repository.dart';
import '../data/host_repository.dart';
import '../models/db_connection.dart';
import '../models/ssh_host.dart';
import '../services/db/db_driver.dart';
import '../services/db/db_driver_factory.dart';
import '../services/db/sqlite_db_driver.dart';
import 'session_manager.dart';
import 'terminal_session.dart';

enum DbConnectionState { connecting, connected, failed, closed }

/// One live (or once-live) connection to a database server, owned by
/// [DbSessionManager] rather than any screen showing it - same shape as
/// [TerminalSession] (`lib/session/terminal_session.dart`). Unlike
/// [TerminalSession], a dropped connection does not auto-reconnect: the
/// workspace screen offers a manual reconnect instead, since a DB session
/// carries no scrollback/state worth preserving through a retry loop.
class DbSession extends ChangeNotifier {
  DbSession(this.connection);

  final DbConnection connection;

  DbConnectionState state = DbConnectionState.connecting;
  String? errorMessage;
  DbDriver? driver;

  TerminalSession? _tunnelSession;
  int? _tunnelLocalPort;

  /// A SQLite file downloaded over SFTP into a temp file for this session -
  /// deleted again on [close].
  File? _sqliteTempFile;

  bool _disposed = false;

  Future<void> connect(
    DbRepository dbRepo,
    HostRepository hostRepo,
    SessionManager sshSessionManager,
  ) async {
    state = DbConnectionState.connecting;
    errorMessage = null;
    _notify();

    try {
      final driver = connection.engine == DbEngine.sqlite
          ? await _openSqliteDriver(hostRepo, sshSessionManager)
          : await _openNetworkDriver(dbRepo, hostRepo, sshSessionManager);
      await driver.open();
      this.driver = driver;
      state = DbConnectionState.connected;
      _notify();
    } catch (e) {
      await _teardownTunnel();
      errorMessage = e.toString();
      state = DbConnectionState.failed;
      _notify();
    }
  }

  Future<DbDriver> _openNetworkDriver(
    DbRepository dbRepo,
    HostRepository hostRepo,
    SessionManager sshSessionManager,
  ) async {
    final password = await dbRepo.getPassword(connection.id) ?? '';
    var effectiveHost = connection.host;
    var effectivePort = connection.port;

    if (connection.connectMode == DbConnectMode.tunnel) {
      final sshHostId = connection.sshHostId;
      if (sshHostId == null) {
        throw Exception('SSH host belum dipilih untuk tunnel ini');
      }
      final sshHost = _findSshHost(hostRepo, sshHostId);
      if (sshHost == null) {
        throw Exception('SSH host untuk tunnel ini tidak ditemukan');
      }

      final tunnelSession = sshSessionManager.open(sshHost, hostRepo);
      _tunnelSession = tunnelSession;
      await _waitForSshConnected(tunnelSession);

      final localPort = await tunnelSession.openEphemeralLocalForward(
        connection.host,
        connection.port,
      );
      _tunnelLocalPort = localPort;
      effectiveHost = '127.0.0.1';
      effectivePort = localPort;
    }

    return createDbDriver(
      connection,
      effectiveHost: effectiveHost,
      effectivePort: effectivePort,
      password: password,
    );
  }

  /// SQLite has no server to tunnel to or connect directly against - it
  /// resolves to a plain local file path, either one already on the
  /// device or one just downloaded from an SSH host over SFTP.
  Future<DbDriver> _openSqliteDriver(
    HostRepository hostRepo,
    SessionManager sshSessionManager,
  ) async {
    if (connection.sqliteSource == SqliteSource.remote) {
      final remotePath = connection.sqliteRemotePath;
      final sshHostId = connection.sshHostId;
      if (remotePath == null || remotePath.isEmpty || sshHostId == null) {
        throw Exception('Path file SQLite remote belum diisi');
      }
      final sshHost = _findSshHost(hostRepo, sshHostId);
      if (sshHost == null) {
        throw Exception('SSH host untuk file ini tidak ditemukan');
      }

      final tunnelSession = sshSessionManager.open(sshHost, hostRepo);
      await _waitForSshConnected(tunnelSession);

      final tempDir = await getTemporaryDirectory();
      final localFile = File('${tempDir.path}/db_${connection.id}.sqlite');
      final sftp = await tunnelSession.openSftpClient();
      final remoteFile = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.read,
      );
      try {
        await remoteFile.downloadTo(
          localFile.openWrite(),
          closeDestination: true,
        );
      } finally {
        await remoteFile.close();
      }
      _sqliteTempFile = localFile;
      return SqliteDbDriver(filePath: localFile.path);
    }

    final localPath = connection.sqliteLocalPath;
    if (localPath == null || localPath.isEmpty) {
      throw Exception('File SQLite belum dipilih');
    }
    return SqliteDbDriver(filePath: localPath);
  }

  SshHost? _findSshHost(HostRepository hostRepo, String id) {
    for (final h in hostRepo.getAll()) {
      if (h.id == id) return h;
    }
    return null;
  }

  /// Waits for [session] (an SSH [TerminalSession] being reused/opened for
  /// the tunnel) to reach [TerminalConnectionState.connected], or throws if
  /// it fails first or takes too long.
  Future<void> _waitForSshConnected(TerminalSession session) {
    if (session.state == TerminalConnectionState.connected) {
      return Future.value();
    }
    if (session.state == TerminalConnectionState.failed) {
      throw Exception(session.errorMessage ?? 'Koneksi SSH gagal');
    }

    final completer = Completer<void>();
    late final VoidCallback listener;
    listener = () {
      if (session.state == TerminalConnectionState.connected) {
        session.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      } else if (session.state == TerminalConnectionState.failed) {
        session.removeListener(listener);
        if (!completer.isCompleted) {
          completer.completeError(
            Exception(session.errorMessage ?? 'Koneksi SSH gagal'),
          );
        }
      }
    };
    session.addListener(listener);

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        session.removeListener(listener);
        throw Exception('Waktu koneksi SSH habis');
      },
    );
  }

  DbDriver _requireDriver() {
    final d = driver;
    if (d == null) throw StateError('Belum terhubung');
    return d;
  }

  Future<List<String>> listDatabases() => _requireDriver().listDatabases();

  Future<List<String>> listTables(String database) =>
      _requireDriver().listTables(database);

  Future<List<DbColumn>> listColumns(String database, String table) =>
      _requireDriver().listColumns(database, table);

  bool get supportsUserManagement => driver?.supportsUserManagement ?? false;

  Future<List<DbUser>> listUsers() => _requireDriver().listUsers();

  Future<void> createUser(String username, String password, {String? host}) =>
      _requireDriver().createUser(username, password, host: host);

  Future<void> dropUser(String username, {String? host}) =>
      _requireDriver().dropUser(username, host: host);

  Future<List<String>> listGrants(String username, {String? host}) =>
      _requireDriver().listGrants(username, host: host);

  Future<DbQueryResult> runQuery(String sql, {String? database}) =>
      _requireDriver().execute(sql, database: database);

  Future<void> close() async {
    state = DbConnectionState.closed;
    await driver?.close();
    driver = null;
    await _teardownTunnel();
    await _deleteSqliteTempFile();
    _notify();
  }

  /// Closes just this session's forwarded port, not the underlying SSH
  /// [TerminalSession] - it may still be in use elsewhere (a terminal tab,
  /// a saved Port Forward, another DB connection through the same host),
  /// same as how [PortForwardScreen] leaves the host's session running
  /// after stopping a tunnel.
  Future<void> _teardownTunnel() async {
    final port = _tunnelLocalPort;
    if (port != null) {
      await _tunnelSession?.closeEphemeralLocalForward(port);
    }
    _tunnelLocalPort = null;
    _tunnelSession = null;
  }

  Future<void> _deleteSqliteTempFile() async {
    final file = _sqliteTempFile;
    _sqliteTempFile = null;
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close());
    super.dispose();
  }
}
