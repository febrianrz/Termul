import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/db_repository.dart';
import '../data/host_repository.dart';
import '../models/db_connection.dart';
import '../models/ssh_host.dart';
import '../services/db/db_driver.dart';
import '../services/db/db_driver_factory.dart';
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
      final password = await dbRepo.getPassword(connection.id) ?? '';
      var effectiveHost = connection.host;
      var effectivePort = connection.port;

      if (connection.connectMode == DbConnectMode.tunnel) {
        final sshHostId = connection.sshHostId;
        if (sshHostId == null) {
          throw Exception('SSH host belum dipilih untuk tunnel ini');
        }

        SshHost? sshHost;
        for (final h in hostRepo.getAll()) {
          if (h.id == sshHostId) {
            sshHost = h;
            break;
          }
        }
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

      final driver = createDbDriver(
        connection,
        effectiveHost: effectiveHost,
        effectivePort: effectivePort,
        password: password,
      );
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

  Future<DbQueryResult> runQuery(String sql, {String? database}) =>
      _requireDriver().execute(sql, database: database);

  Future<void> close() async {
    state = DbConnectionState.closed;
    await driver?.close();
    driver = null;
    await _teardownTunnel();
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
