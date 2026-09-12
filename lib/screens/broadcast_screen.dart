import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/command_shortcut.dart';
import '../session/session_manager.dart';
import '../session/terminal_session.dart';
import 'shortcut_screen.dart';

/// Sends the same command to several open terminal sessions at once, e.g.
/// running `docker ps` across every host in a cluster without switching
/// between tabs one by one.
class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final _commandController = TextEditingController();
  final Set<String> _selectedHostIds = {};

  @override
  void initState() {
    super.initState();
    // Pre-select every already-connected session - the common case is
    // "run this on all my open hosts".
    final sessions = context.read<SessionManager>().sessions;
    _selectedHostIds.addAll(
      sessions
          .where((s) => s.state == TerminalConnectionState.connected)
          .map((s) => s.host.id),
    );
  }

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  Future<void> _pickShortcut() async {
    final shortcut = await Navigator.of(context).push<CommandShortcut>(
      MaterialPageRoute(
        builder: (_) => const ShortcutScreen(pickerMode: true),
      ),
    );
    if (shortcut != null) {
      setState(() => _commandController.text = shortcut.command);
    }
  }

  void _send(List<TerminalSession> sessions) {
    final command = _commandController.text;
    if (command.isEmpty || _selectedHostIds.isEmpty) return;

    var sent = 0;
    for (final session in sessions) {
      if (!_selectedHostIds.contains(session.host.id)) continue;
      if (session.state != TerminalConnectionState.connected) continue;
      session.sendInput('$command\n');
      sent++;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Terkirim ke $sent sesi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionManager>().sessions;

    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast Command')),
      body: sessions.isEmpty
          ? const Center(child: Text('Belum ada sesi terminal yang aktif'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _commandController,
                    decoration: InputDecoration(
                      labelText: 'Command',
                      hintText: 'contoh: docker ps',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.bolt_outlined),
                        tooltip: 'Pilih dari shortcut',
                        onPressed: _pickShortcut,
                      ),
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                    minLines: 1,
                    maxLines: 3,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Kirim ke sesi mana saja:'),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final connected =
                          session.state == TerminalConnectionState.connected;
                      return CheckboxListTile(
                        value: _selectedHostIds.contains(session.host.id),
                        onChanged: connected
                            ? (value) => setState(() {
                                if (value == true) {
                                  _selectedHostIds.add(session.host.id);
                                } else {
                                  _selectedHostIds.remove(session.host.id);
                                }
                              })
                            : null,
                        title: Text(session.host.name),
                        subtitle: Text(
                          connected ? 'Terhubung' : 'Tidak terhubung',
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnimatedBuilder(
                    animation: _commandController,
                    builder: (context, _) => FilledButton.icon(
                      onPressed: _selectedHostIds.isEmpty ||
                              _commandController.text.isEmpty
                          ? null
                          : () => _send(sessions),
                      icon: const Icon(Icons.send),
                      label: Text('Kirim ke ${_selectedHostIds.length} sesi'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
