import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:xterm/xterm.dart';

import '../data/host_repository.dart';
import '../models/port_forward.dart';
import '../models/ssh_host.dart';

/// Pipes bytes between an [SSHForwardChannel] and a plain TCP [Socket] in
/// both directions, and tears down one side when the other closes or
/// errors. Shared by local forwards (socket is the local client connection)
/// and remote forwards (socket is the connection to the local target).
void _pipe(SSHForwardChannel channel, Socket socket) {
  channel.stream.listen(
    socket.add,
    onDone: socket.destroy,
    onError: (_) => socket.destroy(),
    cancelOnError: true,
  );
  socket.listen(
    (data) => channel.sink.add(data),
    onDone: channel.close,
    onError: (_) => channel.close(),
    cancelOnError: true,
  );
}

/// A running tunnel started from a [PortForward] config, plus whatever
/// needs closing to tear it down.
class _ActiveForward {
  _ActiveForward({this.serverSocket, this.remoteForward, required this.subscription});

  final ServerSocket? serverSocket;
  final SSHRemoteForward? remoteForward;
  final StreamSubscription<void> subscription;

  Future<void> close() async {
    await subscription.cancel();
    await serverSocket?.close();
    remoteForward?.close();
  }
}

enum TerminalConnectionState {
  connecting,
  connected,
  // Was connected, then the connection dropped without the user asking to
  // disconnect (e.g. the phone switched networks) - a reconnect is being
  // retried automatically in the background, see [TerminalSession._scheduleReconnect].
  reconnecting,
  closed,
  failed,
}

/// Backoff schedule (seconds) between automatic reconnect attempts, capped
/// at the last entry for every attempt beyond it.
const _reconnectBackoffSeconds = [2, 4, 8, 16, 30];

/// One live (or once-live) SSH connection plus its terminal buffer.
///
/// Owned by [SessionManager] rather than any screen showing it, so it keeps
/// running when its tab isn't the one in front, or the terminal screen is
/// popped entirely - reopening the same host re-displays the same
/// [terminal] (scrollback and all) instead of reconnecting from scratch.
class TerminalSession extends ChangeNotifier {
  TerminalSession(this.host);

  final SshHost host;
  final Terminal terminal = Terminal(maxLines: 10000);
  final TerminalController terminalController = TerminalController();

  /// Owned by the session (not the tab widget showing it) so the tabs
  /// screen can request focus for whichever session's tab is active,
  /// without a background tab's [TerminalView] stealing keyboard input.
  final FocusNode focusNode = FocusNode();

  SSHClient? _client;
  SSHSession? _sshSession;
  bool _wired = false;
  bool _disposed = false;

  /// True once the user has explicitly asked to disconnect (or the session
  /// is being torn down) - stops the unexpected-close handler below from
  /// starting an auto-reconnect loop on a connection nobody wants anymore.
  bool _userClosed = false;
  bool _everConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  HostRepository? _repo;

  TerminalConnectionState state = TerminalConnectionState.connecting;
  String? errorMessage;

  final Map<String, _ActiveForward> _activeForwards = {};
  final Map<String, String> _forwardErrors = {};

  /// Unnamed forwards opened on the fly (e.g. by a Database connection
  /// tunneling to a remote MySQL/MariaDB server), keyed by the local port
  /// they bound. Kept separate from [_activeForwards] so they never show up
  /// in the user-visible saved [PortForward] list.
  final Map<int, _ActiveForward> _ephemeralForwards = {};

  /// IDs of [PortForward]s currently tunneling traffic through this session.
  Set<String> get activeForwardIds => _activeForwards.keys.toSet();

  /// Error from the last failed attempt to start this forward, if any.
  String? forwardError(String id) => _forwardErrors[id];

  /// Whether the toolbar's Ctrl/Alt keys are armed, i.e. will modify the
  /// next character typed instead of that character being sent as-is.
  bool ctrlArmed = false;
  bool altArmed = false;

  void toggleCtrl() {
    ctrlArmed = !ctrlArmed;
    _notify();
  }

  void toggleAlt() {
    altArmed = !altArmed;
    _notify();
  }

  /// Applies an armed Ctrl/Alt modifier to the next typed character, then
  /// disarms it - mirrors how a physical modifier key is held down for one
  /// keystroke on a mobile "extra keys" toolbar.
  void _handleTypedOutput(String data) {
    if ((ctrlArmed || altArmed) && data.isNotEmpty) {
      final ctrl = ctrlArmed;
      final alt = altArmed;
      ctrlArmed = false;
      altArmed = false;
      _notify();
      if (terminal.charInput(data.runes.first, ctrl: ctrl, alt: alt)) return;
    }
    _sshSession?.write(utf8.encode(data));
  }

  /// Connects (or reconnects) using [repo] to look up credentials.
  ///
  /// [isAutoRetry] marks a call made internally by [_scheduleReconnect]
  /// rather than the user tapping "Sambungkan ulang" - it skips resetting
  /// [_userClosed] and the backoff counter, which a manual retry should
  /// always reset.
  Future<void> connect(HostRepository repo, {bool isAutoRetry = false}) async {
    if (_disposed) return;
    _repo = repo;
    if (!isAutoRetry) {
      _userClosed = false;
      _reconnectAttempt = 0;
      _reconnectTimer?.cancel();
    }

    state = TerminalConnectionState.connecting;
    errorMessage = null;
    _notify();

    if (!_wired) {
      _wired = true;
      terminal.onOutput = _handleTypedOutput;
      terminal.onResize = (width, height, pixelWidth, pixelHeight) =>
          _sshSession?.resizeTerminal(width, height, pixelWidth, pixelHeight);
    }

    try {
      final socket = await SSHSocket.connect(
        host.address,
        host.port,
        timeout: const Duration(seconds: 15),
      );

      List<SSHKeyPair>? identities;
      if (host.authType == SshAuthType.privateKey) {
        final pem = await repo.getPrivateKey(host.id);
        if (pem == null || pem.isEmpty) {
          throw Exception('Private key belum diisi untuk host ini');
        }
        final passphrase = await repo.getPassphrase(host.id);
        identities = SSHKeyPair.fromPem(
          pem,
          (passphrase != null && passphrase.isNotEmpty) ? passphrase : null,
        );
      }

      final client = SSHClient(
        socket,
        username: host.username,
        onPasswordRequest: host.authType == SshAuthType.password
            ? () => repo.getPassword(host.id)
            : null,
        identities: identities,
      );
      _client = client;

      await client.authenticated;

      final sshSession = await client.shell(
        pty: SSHPtyConfig(
          width: terminal.viewWidth,
          height: terminal.viewHeight,
        ),
      );
      _sshSession = sshSession;

      sshSession.stdout.listen((data) {
        terminal.write(utf8.decode(data, allowMalformed: true));
      });
      sshSession.stderr.listen((data) {
        terminal.write(utf8.decode(data, allowMalformed: true));
      });

      state = TerminalConnectionState.connected;
      _reconnectAttempt = 0;
      _everConnected = true;
      _notify();

      sshSession.done.then((_) {
        if (_disposed) return;
        _client?.close();
        unawaited(_stopAllForwards());
        if (_userClosed) {
          state = TerminalConnectionState.closed;
          _notify();
        } else {
          _scheduleReconnect();
        }
      });
    } catch (e) {
      errorMessage = e.toString();
      // A session that connected successfully at least once keeps retrying
      // through further failures (e.g. the network is still down) instead
      // of giving up - that's the whole point of auto-reconnect. A session
      // that has never connected (bad password, unreachable host) still
      // stops at `failed` and waits for a manual retry, so a typo doesn't
      // spin forever.
      if (_everConnected && !_userClosed) {
        _scheduleReconnect();
      } else {
        state = TerminalConnectionState.failed;
        _notify();
      }
    }
  }

  /// Schedules a reconnect attempt after an unexpected disconnect, with
  /// increasing backoff so a prolonged outage doesn't spin the connection
  /// attempt (and the user's battery/data) every couple of seconds.
  void _scheduleReconnect() {
    if (_disposed || _userClosed) return;
    state = TerminalConnectionState.reconnecting;
    _notify();

    final delay = _reconnectBackoffSeconds[_reconnectAttempt.clamp(
      0,
      _reconnectBackoffSeconds.length - 1,
    )];
    _reconnectAttempt++;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_disposed || _userClosed) return;
      connect(_repo!, isAutoRetry: true);
    });
  }

  /// Writes [text] to the remote shell as if typed, e.g. to run a saved
  /// command shortcut. No-op if not currently connected.
  void sendInput(String text) {
    _sshSession?.write(utf8.encode(text));
  }

  /// Starts tunneling traffic for [forward] through this session's SSH
  /// connection. No-op if it's already running. Requires the session to be
  /// [TerminalConnectionState.connected] - the resulting error message (if
  /// any) is available afterwards via [forwardError].
  Future<void> startForward(PortForward forward) async {
    if (_activeForwards.containsKey(forward.id)) return;
    final client = _client;
    if (client == null || state != TerminalConnectionState.connected) {
      _forwardErrors[forward.id] = 'Sesi belum terhubung';
      _notify();
      return;
    }

    try {
      final active = forward.type == PortForwardType.local
          ? await _startLocalForward(client, forward)
          : await _startRemoteForward(client, forward);
      _activeForwards[forward.id] = active;
      _forwardErrors.remove(forward.id);
    } catch (e) {
      _forwardErrors[forward.id] = e.toString();
    }
    _notify();
  }

  Future<_ActiveForward> _startLocalForward(
    SSHClient client,
    PortForward forward,
  ) async {
    final serverSocket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      forward.bindPort,
    );
    final subscription = serverSocket.listen((socket) async {
      try {
        final channel = await client.forwardLocal(
          forward.targetHost,
          forward.targetPort,
        );
        _pipe(channel, socket);
      } catch (_) {
        socket.destroy();
      }
    });
    return _ActiveForward(
      serverSocket: serverSocket,
      subscription: subscription,
    );
  }

  Future<_ActiveForward> _startRemoteForward(
    SSHClient client,
    PortForward forward,
  ) async {
    final remoteForward = await client.forwardRemote(port: forward.bindPort);
    if (remoteForward == null) {
      throw Exception(
        'Server menolak permintaan remote forward (port ${forward.bindPort} mungkin sudah dipakai)',
      );
    }
    final subscription = remoteForward.connections.listen((channel) async {
      try {
        final socket = await Socket.connect(
          forward.targetHost,
          forward.targetPort,
        );
        _pipe(channel, socket);
      } catch (_) {
        channel.destroy();
      }
    });
    return _ActiveForward(
      remoteForward: remoteForward,
      subscription: subscription,
    );
  }

  Future<void> stopForward(String id) async {
    final forward = _activeForwards.remove(id);
    _forwardErrors.remove(id);
    _notify();
    await forward?.close();
  }

  /// Opens an unnamed local forward to `targetHost:targetPort`, the same
  /// way a [PortForwardType.local] tunnel does (see [_startLocalForward]),
  /// but bound to an OS-assigned free port instead of a user-chosen one and
  /// not tracked in the saved [PortForward] list. Used by the Database tab
  /// to reach a DB server through this session's SSH connection. Requires
  /// the session to be [TerminalConnectionState.connected].
  Future<int> openEphemeralLocalForward(
    String targetHost,
    int targetPort,
  ) async {
    final client = _client;
    if (client == null || state != TerminalConnectionState.connected) {
      throw Exception('Sesi belum terhubung');
    }

    final serverSocket = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final subscription = serverSocket.listen((socket) async {
      try {
        final channel = await client.forwardLocal(targetHost, targetPort);
        _pipe(channel, socket);
      } catch (_) {
        socket.destroy();
      }
    });
    _ephemeralForwards[serverSocket.port] = _ActiveForward(
      serverSocket: serverSocket,
      subscription: subscription,
    );
    return serverSocket.port;
  }

  Future<void> closeEphemeralLocalForward(int localPort) async {
    final forward = _ephemeralForwards.remove(localPort);
    await forward?.close();
  }

  Future<void> _stopAllForwards() async {
    final forwards = [
      ..._activeForwards.values,
      ..._ephemeralForwards.values,
    ];
    _activeForwards.clear();
    _ephemeralForwards.clear();
    for (final forward in forwards) {
      await forward.close();
    }
  }

  /// Closes the underlying SSH connection. Does not touch [terminal]'s
  /// scrollback, so a closed session can still be reviewed until the user
  /// removes it from [SessionManager] entirely. Marks the close as
  /// user-initiated, so it won't trigger an auto-reconnect.
  void terminate() {
    _userClosed = true;
    _reconnectTimer?.cancel();
    unawaited(_stopAllForwards());
    _sshSession?.close();
    _client?.close();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    unawaited(_stopAllForwards());
    focusNode.dispose();
    super.dispose();
  }
}
