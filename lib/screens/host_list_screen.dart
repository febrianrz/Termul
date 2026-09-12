import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_service.dart';
import '../data/host_repository.dart';
import '../models/host_group.dart';
import '../models/ssh_host.dart';
import 'host_edit_screen.dart';
import 'host_group_screen.dart';
import 'login_screen.dart';
import 'terminal_screen.dart';

class HostListScreen extends StatefulWidget {
  const HostListScreen({super.key});

  @override
  State<HostListScreen> createState() => _HostListScreenState();
}

class _HostListScreenState extends State<HostListScreen> {
  late List<SshHost> _hosts;
  late List<HostGroup> _groups;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadAuthStatus();
  }

  Future<void> _loadAuthStatus() async {
    final loggedIn = await context.read<AuthService>().isLoggedIn();
    if (mounted) setState(() => _loggedIn = loggedIn);
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
    if (result == true) _loadAuthStatus();
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
    if (mounted) setState(() => _loggedIn = false);
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
      leading: const CircleAvatar(child: Icon(Icons.dns)),
      title: Text(host.name),
      subtitle: Text('${host.username}@${host.address}:${host.port}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TerminalScreen(host: host)),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') _openEditor(host: host);
          if (value == 'delete') _delete(host);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Hapus')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_hosts.isEmpty) {
      return _EmptyState(onAdd: () => _openEditor());
    }

    if (_groups.isEmpty) {
      return ListView.separated(
        itemCount: _hosts.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) => _hostTile(_hosts[index]),
      );
    }

    final byGroup = <String?, List<SshHost>>{};
    for (final host in _hosts) {
      byGroup.putIfAbsent(host.groupId, () => []).add(host);
    }

    final sections = <Widget>[];
    for (final group in _groups) {
      final hosts = byGroup[group.id];
      if (hosts == null || hosts.isEmpty) continue;
      sections.add(_sectionHeader(group.name));
      sections.addAll(hosts.map(_hostTile));
    }
    final ungrouped = byGroup[null];
    if (ungrouped != null && ungrouped.isNotEmpty) {
      sections.add(_sectionHeader('Tanpa grup'));
      sections.addAll(ungrouped.map(_hostTile));
    }

    return ListView(children: sections);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termul'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Kelola Grup',
            onPressed: _openGroups,
          ),
          if (_loggedIn)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _logout,
            )
          else
            IconButton(
              icon: const Icon(Icons.login),
              tooltip: 'Login with Alter One',
              onPressed: _login,
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
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
