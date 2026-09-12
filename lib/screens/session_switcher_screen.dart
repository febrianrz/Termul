import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../session/session_manager.dart';
import '../session/terminal_session.dart';
import 'broadcast_screen.dart';
import 'terminal_screen.dart';

/// Lists every SSH session currently tracked by [SessionManager] - running
/// or disconnected - so the user can resume one without reconnecting, or
/// close it for good.
class SessionSwitcherScreen extends StatelessWidget {
  const SessionSwitcherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionManager>().sessions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sesi Aktif'),
        actions: [
          if (sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Broadcast Command',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BroadcastScreen()),
              ),
            ),
        ],
      ),
      body: sessions.isEmpty
          ? const Center(child: Text('Belum ada sesi terminal yang aktif'))
          : ListView.separated(
              itemCount: sessions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _SessionTile(
                session: sessions[index],
              ),
            ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final TerminalSession session;

  const _SessionTile({required this.session});

  Color _dotColor() {
    switch (session.state) {
      case TerminalConnectionState.connected:
        return Colors.green;
      case TerminalConnectionState.connecting:
      case TerminalConnectionState.reconnecting:
        return Colors.orange;
      case TerminalConnectionState.closed:
      case TerminalConnectionState.failed:
        return Colors.grey;
    }
  }

  String _label() {
    switch (session.state) {
      case TerminalConnectionState.connecting:
        return 'Menyambungkan…';
      case TerminalConnectionState.reconnecting:
        return 'Menyambungkan ulang…';
      case TerminalConnectionState.connected:
        return 'Terhubung';
      case TerminalConnectionState.closed:
        return 'Terputus';
      case TerminalConnectionState.failed:
        return 'Gagal: ${session.errorMessage ?? 'unknown error'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _dotColor(),
            child: const Icon(Icons.terminal, size: 18, color: Colors.white),
          ),
          title: Text(session.host.name),
          subtitle: Text(
            _label(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TerminalScreen(host: session.host),
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Tutup sesi',
            onPressed: () =>
                context.read<SessionManager>().closeSession(session.host.id),
          ),
        );
      },
    );
  }
}
