import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import '../data/host_repository.dart';
import '../models/ssh_host.dart';

enum _ConnectionState { connecting, connected, closed, failed }

class TerminalScreen extends StatefulWidget {
  final SshHost host;

  const TerminalScreen({super.key, required this.host});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final _terminal = Terminal(maxLines: 10000);
  final _terminalController = TerminalController();

  SSHClient? _client;
  SSHSession? _session;
  _ConnectionState _state = _ConnectionState.connecting;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _terminal.onOutput = (data) {
      _session?.write(utf8.encode(data));
    };
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      _session?.resizeTerminal(width, height, pixelWidth, pixelHeight);
    };
    _connect();
  }

  Future<void> _connect() async {
    final repo = context.read<HostRepository>();
    final host = widget.host;

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

      final session = await client.shell(
        pty: SSHPtyConfig(
          width: _terminal.viewWidth,
          height: _terminal.viewHeight,
        ),
      );
      _session = session;

      session.stdout.listen((data) {
        _terminal.write(utf8.decode(data, allowMalformed: true));
      });
      session.stderr.listen((data) {
        _terminal.write(utf8.decode(data, allowMalformed: true));
      });

      if (!mounted) return;
      setState(() => _state = _ConnectionState.connected);

      session.done.then((_) {
        if (!mounted) return;
        setState(() => _state = _ConnectionState.closed);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _ConnectionState.failed;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _session?.close();
    _client?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.host.name),
        actions: [
          if (_state == _ConnectionState.closed ||
              _state == _ConnectionState.failed)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Sambungkan ulang',
              onPressed: () {
                setState(() {
                  _state = _ConnectionState.connecting;
                  _errorMessage = null;
                });
                _connect();
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ConnectionState.connecting:
        return const Center(child: CircularProgressIndicator());
      case _ConnectionState.failed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Gagal konek: ${_errorMessage ?? 'unknown error'}',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      case _ConnectionState.connected:
      case _ConnectionState.closed:
        return Column(
          children: [
            if (_state == _ConnectionState.closed)
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
                _terminal,
                controller: _terminalController,
                autofocus: true,
                readOnly: _state == _ConnectionState.closed,
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
