import 'package:flutter/foundation.dart';

import '../data/host_repository.dart';
import '../models/ssh_host.dart';
import 'terminal_session.dart';

/// Tracks every SSH session the user has opened, keyed by host id, so they
/// survive navigating away from the terminal screen and can be resumed
/// from a session switcher (or another tab) instead of dying with the
/// screen that opened them.
class SessionManager extends ChangeNotifier {
  final Map<String, TerminalSession> _sessions = {};

  List<TerminalSession> get sessions =>
      List.unmodifiable(_sessions.values);

  TerminalSession? sessionForHost(String hostId) => _sessions[hostId];

  /// Returns the existing session for [host] if one is already open,
  /// otherwise creates one and starts connecting.
  TerminalSession open(SshHost host, HostRepository repo) {
    final existing = _sessions[host.id];
    if (existing != null) return existing;

    final session = TerminalSession(host);
    _sessions[host.id] = session;
    notifyListeners();
    session.connect(repo);
    return session;
  }

  void closeSession(String hostId) {
    final session = _sessions.remove(hostId);
    if (session == null) return;
    session.terminate();
    session.dispose();
    notifyListeners();
  }
}
