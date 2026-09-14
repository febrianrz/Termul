import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import '../data/host_repository.dart';
import '../l10n/app_strings.dart';
import '../models/command_shortcut.dart';
import '../models/ssh_host.dart';
import '../session/session_manager.dart';
import '../session/terminal_session.dart';
import '../theme/theme_controller.dart';
import '../widgets/terminal_toolbar.dart';
import 'port_forward_screen.dart';
import 'shortcut_screen.dart';

/// Shows every open [TerminalSession] as a tab, tmux-style: switching tabs
/// is instant (no navigation, no reconnect), and every tab's terminal
/// keeps running live in the background even while another tab is in
/// front, since each one is backed by a session owned by [SessionManager]
/// rather than by this screen.
///
/// [initialHost], if given, is opened (or just selected, if already open)
/// once when this screen first builds - pass it when navigating in from a
/// host tile or the session switcher.
class TerminalTabsScreen extends StatefulWidget {
  final SshHost? initialHost;

  const TerminalTabsScreen({super.key, this.initialHost});

  @override
  State<TerminalTabsScreen> createState() => _TerminalTabsScreenState();
}

class _TerminalTabsScreenState extends State<TerminalTabsScreen>
    with SingleTickerProviderStateMixin {
  final AppStrings _s = AppStrings();
  TabController? _tabController;
  String? _activeHostId;
  int _controllerLength = -1;

  @override
  void initState() {
    super.initState();
    final host = widget.initialHost;
    _activeHostId = host?.id;
    if (host != null) {
      context.read<SessionManager>().open(
        host,
        context.read<HostRepository>(),
      );
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  /// Recreates the [TabController] whenever the number of open sessions
  /// changes (Flutter's [TabController] has a fixed [TabController.length]),
  /// trying to keep the same tab selected by host id across the swap.
  void _ensureController(List<TerminalSession> sessions) {
    if (_tabController != null && sessions.length == _controllerLength) {
      return;
    }

    final wanted = _activeHostId;
    final foundIndex = wanted == null
        ? -1
        : sessions.indexWhere((s) => s.host.id == wanted);
    final index = sessions.isEmpty
        ? 0
        : (foundIndex >= 0 ? foundIndex : sessions.length - 1);

    _tabController?.dispose();
    _tabController = TabController(
      length: sessions.length,
      initialIndex: index,
      vsync: this,
    )..addListener(_onTabIndexChanged);
    _controllerLength = sessions.length;
    _activeHostId = sessions.isEmpty ? null : sessions[index].host.id;
  }

  void _onTabIndexChanged() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) return;
    final sessions = context.read<SessionManager>().sessions;
    if (controller.index < sessions.length) {
      final active = sessions[controller.index];
      _activeHostId = active.host.id;
      // Not autofocus: this tab's TerminalView was already mounted (every
      // tab builds up front), so re-requesting focus here is what makes
      // the keyboard follow the tab the user just switched to.
      active.focusNode.requestFocus();
    }
  }

  Future<void> _addSession() async {
    final repo = context.read<HostRepository>();
    final manager = context.read<SessionManager>();
    final openIds = manager.sessions.map((s) => s.host.id).toSet();
    final available = repo.getAll().where((h) => !openIds.contains(h.id));

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_s.allHostsHaveOpenSession)),
      );
      return;
    }

    final picked = await showModalBottomSheet<SshHost>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: available
              .map(
                (h) => ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: Text(h.name),
                  subtitle: Text('${h.username}@${h.address}:${h.port}'),
                  onTap: () => Navigator.of(context).pop(h),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (picked != null) {
      manager.open(picked, repo);
      setState(() => _activeHostId = picked.id);
    }
  }

  void _closeSession(TerminalSession session) {
    context.read<SessionManager>().closeSession(session.host.id);
  }

  Future<void> _runShortcut(TerminalSession session) async {
    final shortcut = await Navigator.of(context).push<CommandShortcut>(
      MaterialPageRoute(
        builder: (_) => const ShortcutScreen(pickerMode: true),
      ),
    );
    if (shortcut != null) {
      session.sendInput('${shortcut.command}\n');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<SessionManager>().sessions;
    _ensureController(sessions);

    if (sessions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_s.terminalTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_s.noActiveSessions),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: Text(_s.backToHostList),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _tabController!;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: sessions
              .map(
                (s) => _SessionTab(
                  key: ValueKey(s.host.id),
                  session: s,
                  onClose: () => _closeSession(s),
                ),
              )
              .toList(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: _s.newSession,
            onPressed: _addSession,
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final active = sessions[controller.index.clamp(
                0,
                sessions.length - 1,
              )];
              return AnimatedBuilder(
                animation: active,
                builder: (context, _) {
                  final reconnecting =
                      active.state == TerminalConnectionState.reconnecting;
                  final canReconnect =
                      active.state == TerminalConnectionState.closed ||
                      active.state == TerminalConnectionState.failed;
                  final canRunShortcut =
                      active.state == TerminalConnectionState.connected;

                  if (reconnecting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  return PopupMenuButton<VoidCallback>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) => action(),
                    itemBuilder: (context) => [
                      if (canReconnect)
                        PopupMenuItem<VoidCallback>(
                          value: () =>
                              active.connect(context.read<HostRepository>()),
                          child: ListTile(
                            leading: const Icon(Icons.refresh),
                            title: Text(_s.reconnect),
                          ),
                        ),
                      PopupMenuItem<VoidCallback>(
                        value: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                PortForwardScreen(host: active.host),
                          ),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.swap_horiz),
                          title: Text(_s.portForward),
                        ),
                      ),
                      if (canRunShortcut)
                        PopupMenuItem<VoidCallback>(
                          value: () => _runShortcut(active),
                          child: ListTile(
                            leading: const Icon(Icons.bolt_outlined),
                            title: Text(_s.runShortcut),
                          ),
                        ),
                      PopupMenuItem<VoidCallback>(
                        value: () => _closeSession(active),
                        child: ListTile(
                          leading: const Icon(Icons.link_off),
                          title: Text(_s.disconnect),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: controller,
        children: sessions
            .map(
              (s) => _SessionView(
                key: ValueKey(s.host.id),
                session: s,
                autofocus: s.host.id == _activeHostId,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SessionTab extends StatelessWidget {
  final TerminalSession session;
  final VoidCallback onClose;

  const _SessionTab({
    super.key,
    required this.session,
    required this.onClose,
  });

  Color _dotColor(TerminalConnectionState state) {
    switch (state) {
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

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: AnimatedBuilder(
        animation: session,
        builder: (context, _) => Tooltip(
          message: session.host.name,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _dotColor(session.state),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tab's body: the connecting/failed/connected UI plus the extra keys
/// toolbar, scoped to a single [session] so it can live inside a
/// [TabBarView] page.
class _SessionView extends StatelessWidget {
  final TerminalSession session;
  final bool autofocus;

  const _SessionView({
    super.key,
    required this.session,
    required this.autofocus,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppStrings();
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        switch (session.state) {
          case TerminalConnectionState.connecting:
            return const Center(child: CircularProgressIndicator());
          case TerminalConnectionState.failed:
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.connectFailed(session.errorMessage ?? s.unknownError),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          case TerminalConnectionState.connected:
          case TerminalConnectionState.closed:
          case TerminalConnectionState.reconnecting:
            final closed = session.state == TerminalConnectionState.closed;
            final reconnecting =
                session.state == TerminalConnectionState.reconnecting;
            return Column(
              children: [
                if (closed || reconnecting)
                  Container(
                    width: double.infinity,
                    color: Colors.orange.shade800,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      reconnecting
                          ? s.connectionLostReconnecting
                          : s.connectionLost,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                Expanded(
                  child: TerminalView(
                    session.terminal,
                    controller: session.terminalController,
                    focusNode: session.focusNode,
                    autofocus: autofocus,
                    readOnly: closed || reconnecting,
                    theme: context
                        .watch<ThemeController>()
                        .preset
                        .terminalTheme,
                    // Disables the on-screen keyboard's autocorrect/word
                    // suggestion composing behavior (default
                    // TextInputType.emailAddress still lets some keyboards
                    // batch keystrokes into a composing region before
                    // committing them) - without this, typed characters can
                    // land only after a whole word commits, making the
                    // terminal cursor appear to lag behind typing.
                    keyboardType: TextInputType.visiblePassword,
                  ),
                ),
                if (!closed && !reconnecting)
                  TerminalToolbar(session: session),
              ],
            );
        }
      },
    );
  }
}
