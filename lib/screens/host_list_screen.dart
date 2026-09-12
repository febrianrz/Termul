import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../data/host_repository.dart';
import '../models/host_group.dart';
import '../models/ssh_host.dart';
import '../services/update_checker.dart';
import '../session/session_manager.dart';
import '../session/terminal_session.dart';
import 'host_edit_screen.dart';
import 'host_group_screen.dart';
import 'login_screen.dart';
import 'port_forward_screen.dart';
import 'qr_import_screen.dart';
import 'session_switcher_screen.dart';
import 'settings_screen.dart';
import 'sftp_screen.dart';
import 'shortcut_screen.dart';
import 'terminal_tabs_screen.dart';
import 'web_shortcut_screen.dart';

class HostListScreen extends StatefulWidget {
  const HostListScreen({super.key});

  @override
  State<HostListScreen> createState() => _HostListScreenState();
}

class _HostListScreenState extends State<HostListScreen> {
  late List<SshHost> _hosts;
  late List<HostGroup> _groups;
  bool _loggedIn = false;
  Map<String, dynamic>? _user;
  UpdateInfo? _updateInfo;
  String _searchQuery = '';
  String? _selectedTag;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadAuthStatus();
    _checkForUpdate();
  }

  /// Best-effort, silent check so the app can flag a newer build without
  /// the user having to dig into Settings. Failures (offline, rate-limited)
  /// are ignored - this is not the only way to check, see Settings.
  Future<void> _checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final latest = await UpdateChecker.fetchLatest();
      if (mounted && latest != null && latest.buildNumber > currentBuild) {
        setState(() => _updateInfo = latest);
      }
    } catch (_) {
      // Ignore - Settings' manual "Cek Pembaruan" still works.
    }
  }

  Future<void> _loadAuthStatus() async {
    final auth = context.read<AuthService>();
    final loggedIn = await auth.isLoggedIn();
    final user = loggedIn ? await auth.fetchUser() : null;
    if (mounted) {
      setState(() {
        _loggedIn = loggedIn;
        _user = user;
      });
    }
  }

  /// Best-effort display name from `/api/user` - the schema isn't
  /// documented beyond "Alter Indonesia's", so fall back across the field
  /// names a Laravel Passport user endpoint commonly returns.
  String? _userDisplayName() {
    final user = _user;
    if (user == null) return null;
    return (user['name'] ?? user['full_name'] ?? user['email']) as String?;
  }

  String _userInitials() {
    final name = _userDisplayName();
    if (name == null || name.trim().isEmpty) return '?';
    final letters = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return letters.isEmpty ? '?' : letters;
  }

  void _reload() {
    final repo = context.read<HostRepository>();
    setState(() {
      _hosts = repo.getAll();
      _groups = repo.getAllGroups();
    });
  }

  Future<void> _openEditor({SshHost? host}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HostEditScreen(host: host)),
    );
    _reload();
  }

  Future<void> _openGroups() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HostGroupScreen()),
    );
    _reload();
  }

  void _openShortcuts() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShortcutScreen()),
    );
  }

  void _openWebShortcuts() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WebShortcutScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _importFromMac() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrImportScreen()),
    );
    _reload();
  }

  void _openSessions() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SessionSwitcherScreen()),
    );
  }

  Future<void> _delete(SshHost host) async {
    final repo = context.read<HostRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus host?'),
        content: Text('Host "${host.name}" akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.delete(host.id);
      _reload();
    }
  }

  Future<void> _login() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (result != true) return;

    await _loadAuthStatus();
    if (!mounted) return;
    final name = _userDisplayName() ?? 'Alter One';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Berhasil login sebagai $name')));
  }

  Future<void> _logout() async {
    final auth = context.read<AuthService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await auth.logout();
    if (mounted) {
      setState(() {
        _loggedIn = false;
        _user = null;
      });
    }
  }

  Widget _updateBanner(UpdateInfo info) {
    return MaterialBanner(
      leading: const Icon(Icons.system_update_outlined),
      content: Text('Update tersedia (build ${info.buildNumber})'),
      actions: [
        TextButton(
          onPressed: () => setState(() => _updateInfo = null),
          child: const Text('Nanti'),
        ),
        FilledButton(
          onPressed: () {
            setState(() => _updateInfo = null);
            launchUrl(
              Uri.parse(info.releaseUrl),
              mode: LaunchMode.externalApplication,
            );
          },
          child: const Text('Buka'),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _hostTile(SshHost host) {
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          const CircleAvatar(child: Icon(Icons.dns)),
          Positioned(
            right: -2,
            bottom: -2,
            child: _HostSessionIndicator(hostId: host.id),
          ),
        ],
      ),
      title: Text(host.name),
      subtitle: Text(
        host.tags.isEmpty
            ? '${host.username}@${host.address}:${host.port}'
            : '${host.username}@${host.address}:${host.port} · ${host.tags.join(', ')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TerminalTabsScreen(initialHost: host),
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'sftp') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => SftpScreen(host: host)),
            );
          }
          if (value == 'forward') {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PortForwardScreen(host: host)),
            );
          }
          if (value == 'edit') _openEditor(host: host);
          if (value == 'delete') _delete(host);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'sftp', child: Text('SFTP')),
          PopupMenuItem(value: 'forward', child: Text('Port Forward')),
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Hapus')),
        ],
      ),
    );
  }

  List<String> get _allTags =>
      ({for (final h in _hosts) ...h.tags}.toList()..sort());

  List<SshHost> get _filteredHosts => _hosts
      .where((h) => h.matches(_searchQuery))
      .where((h) => _selectedTag == null || h.tags.contains(_selectedTag))
      .toList();

  bool get _isFiltering => _searchQuery.isNotEmpty || _selectedTag != null;

  Widget _searchAndTagBar() {
    final tags = _allTags;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari host, alamat, atau tag…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _searchQuery = ''),
                    ),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        if (tags.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              itemCount: tags.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tag = tags[index];
                final selected = _selectedTag == tag;
                return ChoiceChip(
                  label: Text(tag),
                  selected: selected,
                  onSelected: (value) =>
                      setState(() => _selectedTag = value ? tag : null),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_hosts.isEmpty) {
      return _EmptyState(onAdd: () => _openEditor());
    }

    final hosts = _filteredHosts;
    if (hosts.isEmpty) {
      return const Center(child: Text('Tidak ada host yang cocok'));
    }

    if (_groups.isEmpty || _isFiltering) {
      return ListView.separated(
        itemCount: hosts.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) => _hostTile(hosts[index]),
      );
    }

    final byGroup = <String?, List<SshHost>>{};
    for (final host in hosts) {
      byGroup.putIfAbsent(host.groupId, () => []).add(host);
    }

    final sections = <Widget>[];
    for (final group in _groups) {
      final groupHosts = byGroup[group.id];
      if (groupHosts == null || groupHosts.isEmpty) continue;
      sections.add(_sectionHeader(group.name));
      sections.addAll(groupHosts.map(_hostTile));
    }
    final ungrouped = byGroup[null];
    if (ungrouped != null && ungrouped.isNotEmpty) {
      sections.add(_sectionHeader('Tanpa grup'));
      sections.addAll(ungrouped.map(_hostTile));
    }

    return ListView(children: sections);
  }

  Widget _menuRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termul'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'sessions') _openSessions();
              if (value == 'import_qr') _importFromMac();
              if (value == 'groups') _openGroups();
              if (value == 'shortcuts') _openShortcuts();
              if (value == 'web_shortcuts') _openWebShortcuts();
              if (value == 'settings') _openSettings();
              if (value == 'login') _login();
              if (value == 'logout') _logout();
            },
            itemBuilder: (context) {
              final sessionCount = context
                  .read<SessionManager>()
                  .sessions
                  .length;
              return [
                PopupMenuItem<String>(
                  value: 'sessions',
                  child: _menuRow(
                    Icons.terminal,
                    sessionCount > 0
                        ? 'Sesi Aktif ($sessionCount)'
                        : 'Sesi Aktif',
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'import_qr',
                  child: _menuRow(
                    Icons.qr_code_scanner,
                    'Import dari Komputer',
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'groups',
                  child: _menuRow(Icons.folder_outlined, 'Kelola Grup'),
                ),
                PopupMenuItem<String>(
                  value: 'shortcuts',
                  child: _menuRow(Icons.bolt_outlined, 'Command Shortcut'),
                ),
                PopupMenuItem<String>(
                  value: 'web_shortcuts',
                  child: _menuRow(Icons.apps_outlined, 'Web Shortcut'),
                ),
                PopupMenuItem<String>(
                  value: 'settings',
                  child: _menuRow(Icons.settings_outlined, 'Pengaturan'),
                ),
                const PopupMenuDivider(),
                if (_loggedIn) ...[
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          child: Text(
                            _userInitials(),
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _userDisplayName() ?? 'Akun',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: _menuRow(Icons.logout, 'Logout'),
                  ),
                ] else
                  PopupMenuItem<String>(
                    value: 'login',
                    child: _menuRow(Icons.login, 'Sign In Alter One'),
                  ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_updateInfo != null) _updateBanner(_updateInfo!),
          if (_hosts.isNotEmpty) _searchAndTagBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Small colored dot on a host tile's avatar showing whether that host has
/// a live [TerminalSession] right now, and roughly what state it's in -
/// so an active connection is visible from the host list itself instead
/// of only inside the session switcher.
class _HostSessionIndicator extends StatelessWidget {
  final String hostId;

  const _HostSessionIndicator({required this.hostId});

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
    final session = context.watch<SessionManager>().sessionForHost(hostId);
    if (session == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: session,
      builder: (context, _) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: _dotColor(session.state),
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).scaffoldBackgroundColor,
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.terminal, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Belum ada host SSH'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Tambah host'),
          ),
        ],
      ),
    );
  }
}
