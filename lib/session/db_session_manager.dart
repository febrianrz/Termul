import 'package:flutter/foundation.dart';

import '../data/db_repository.dart';
import '../data/host_repository.dart';
import '../models/db_connection.dart';
import 'db_session.dart';
import 'session_manager.dart';

/// Tracks every open Database connection, keyed by connection id - the
/// Database-tab equivalent of [SessionManager]
/// (`lib/session/session_manager.dart`), so a connection survives
/// navigating away from the workspace screen instead of dying with it.
class DbSessionManager extends ChangeNotifier {
  final Map<String, DbSession> _sessions = {};

  List<DbSession> get sessions => List.unmodifiable(_sessions.values);

  DbSession? sessionForConnection(String connectionId) =>
      _sessions[connectionId];

  /// Returns the existing session for [connection] if one is already open,
  /// otherwise creates one and starts connecting.
  DbSession open(
    DbConnection connection,
    DbRepository dbRepo,
    HostRepository hostRepo,
    SessionManager sshSessionManager,
  ) {
    final existing = _sessions[connection.id];
    if (existing != null) return existing;

    final session = DbSession(connection);
    _sessions[connection.id] = session;
    notifyListeners();
    session.connect(dbRepo, hostRepo, sshSessionManager);
    return session;
  }

  void closeSession(String connectionId) {
    final session = _sessions.remove(connectionId);
    if (session == null) return;
    session.dispose();
    notifyListeners();
  }
}
