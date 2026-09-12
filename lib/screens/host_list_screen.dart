import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/host_repository.dart';
import '../models/ssh_host.dart';
import 'host_edit_screen.dart';
import 'terminal_screen.dart';

class HostListScreen extends StatefulWidget {
  const HostListScreen({super.key});

  @override
  State<HostListScreen> createState() => _HostListScreenState();
}

class _HostListScreenState extends State<HostListScreen> {
  late List<SshHost> _hosts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _hosts = context.read<HostRepository>().getAll();
    });
  }

  Future<void> _openEditor({SshHost? host}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HostEditScreen(host: host)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termul')),
      body: _hosts.isEmpty
          ? _EmptyState(onAdd: () => _openEditor())
          : ListView.separated(
              itemCount: _hosts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final host = _hosts[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.dns)),
                  title: Text(host.name),
                  subtitle: Text('${host.username}@${host.address}:${host.port}'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TerminalScreen(host: host),
                    ),
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
              },
            ),
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
