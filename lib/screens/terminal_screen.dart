import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import '../data/host_repository.dart';
import '../models/ssh_host.dart';
import '../session/session_manager.dart';
import '../session/terminal_session.dart';

/// Displays a [TerminalSession] for [host], resuming it if one is already
/// running (see [SessionManager]) instead of always connecting fresh.
/// Popping this screen does not disconnect - the session keeps running in
/// the background until closed explicitly (here or from the switcher).
class TerminalScreen extends StatefulWidget {
  final SshHost host;

  const TerminalScreen({super.key, required this.host});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late final TerminalSession _session;

  @override
  void initState() {
    super.initState();
    _session = context.read<SessionManager>().open(
      widget.host,
      context.read<HostRepository>(),
    );
  }

  void _reconnect() {
    _session.connect(context.read<HostRepository>());
  }

  void _disconnect() {
    context.read<SessionManager>().closeSession(widget.host.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.host.name),
            actions: [
              if (_session.state == TerminalConnectionState.closed ||
                  _session.state == TerminalConnectionState.failed)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Sambungkan ulang',
                  onPressed: _reconnect,
                ),
              IconButton(
                icon: const Icon(Icons.link_off),
                tooltip: 'Disconnect',
                onPressed: _disconnect,
              ),
            ],
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_session.state) {
      case TerminalConnectionState.connecting:
        return const Center(child: CircularProgressIndicator());
      case TerminalConnectionState.failed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Gagal konek: ${_session.errorMessage ?? 'unknown error'}',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      case TerminalConnectionState.connected:
      case TerminalConnectionState.closed:
        final closed = _session.state == TerminalConnectionState.closed;
        return Column(
          children: [
            if (closed)
              Container(
                width: double.infinity,
                color: Colors.orange.shade800,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: const Text(
                  'Koneksi terputus',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            Expanded(
              child: TerminalView(
                _session.terminal,
                controller: _session.terminalController,
                autofocus: true,
                readOnly: closed,
                // Disables the on-screen keyboard's autocorrect/word-suggestion
                // composing behavior (default TextInputType.emailAddress still
                // lets some keyboards, e.g. Gboard, batch keystrokes into a
                // composing region before committing them) - without this,
                // typed characters can land only after a whole word commits,
                // making the terminal cursor appear to lag behind typing.
                keyboardType: TextInputType.visiblePassword,
              ),
            ),
          ],
        );
    }
  }
}
