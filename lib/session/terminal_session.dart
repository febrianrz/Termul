import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../data/host_repository.dart';
import '../models/ssh_host.dart';

enum TerminalConnectionState { connecting, connected, closed, failed }

/// One live (or once-live) SSH connection plus its terminal buffer.
///
/// Owned by [SessionManager] rather than any [TerminalScreen], so it keeps
/// running when the screen showing it is popped - reopening the same host
/// re-displays the same [terminal] (scrollback and all) instead of
/// reconnecting from scratch.
class TerminalSession extends ChangeNotifier {
  TerminalSession(this.host);

  final SshHost host;
  final Terminal terminal = Terminal(maxLines: 10000);
  final TerminalController terminalController = TerminalController();

  SSHClient? _client;
  SSHSession? _sshSession;
  bool _wired = false;
  bool _disposed = false;

  TerminalConnectionState state = TerminalConnectionState.connecting;
  String? errorMessage;

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

  Future<void> connect(HostRepository repo) async {
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
      _notify();

      sshSession.done.then((_) {
        state = TerminalConnectionState.closed;
        _notify();
      });
    } catch (e) {
      state = TerminalConnectionState.failed;
      errorMessage = e.toString();
      _notify();
    }
  }

  /// Writes [text] to the remote shell as if typed, e.g. to run a saved
  /// command shortcut. No-op if not currently connected.
  void sendInput(String text) {
    _sshSession?.write(utf8.encode(text));
  }

  /// Closes the underlying SSH connection. Does not touch [terminal]'s
  /// scrollback, so a closed session can still be reviewed until the user
  /// removes it from [SessionManager] entirely.
  void terminate() {
    _sshSession?.close();
    _client?.close();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
