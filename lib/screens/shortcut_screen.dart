import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/host_repository.dart';
import '../models/command_shortcut.dart';

/// Manage saved command shortcuts: add, edit, delete. Used both for
/// management (from the host list) and, in picker mode, to pick one to
/// run in a terminal session.
class ShortcutScreen extends StatefulWidget {
  /// When true, tapping a shortcut pops the screen with it selected instead
  /// of opening the editor.
  final bool pickerMode;

  const ShortcutScreen({super.key, this.pickerMode = false});

  @override
  State<ShortcutScreen> createState() => _ShortcutScreenState();
}

class _ShortcutScreenState extends State<ShortcutScreen> {
  late List<CommandShortcut> _shortcuts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _shortcuts = context.read<HostRepository>().getAllShortcuts();
    });
  }

  Future<void> _addOrEdit({CommandShortcut? shortcut}) async {
    final repo = context.read<HostRepository>();
    final nameController = TextEditingController(text: shortcut?.name);
    final commandController = TextEditingController(text: shortcut?.command);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(shortcut == null ? 'Tambah Shortcut' : 'Edit Shortcut'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commandController,
              decoration: const InputDecoration(
                labelText: 'Command',
                hintText: 'contoh: docker ps',
              ),
              style: const TextStyle(fontFamily: 'monospace'),
              maxLines: 3,
              minLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final name = nameController.text.trim();
    final command = commandController.text.trim();
    if (name.isEmpty || command.isEmpty) return;

    await repo.saveShortcut(
      CommandShortcut(
        id: shortcut?.id ?? const Uuid().v4(),
        name: name,
        command: command,
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _delete(CommandShortcut shortcut) async {
    final repo = context.read<HostRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus shortcut?'),
        content: Text('Shortcut "${shortcut.name}" akan dihapus.'),
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
      await repo.deleteShortcut(shortcut.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pickerMode ? 'Jalankan Shortcut' : 'Command Shortcut',
        ),
      ),
      body: _shortcuts.isEmpty
          ? const Center(child: Text('Belum ada shortcut'))
          : ListView.separated(
              itemCount: _shortcuts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final shortcut = _shortcuts[index];
                return ListTile(
                  leading: const Icon(Icons.bolt_outlined),
                  title: Text(shortcut.name),
                  subtitle: Text(
                    shortcut.command,
                    style: const TextStyle(fontFamily: 'monospace'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: widget.pickerMode
                      ? () => Navigator.of(context).pop(shortcut)
                      : () => _addOrEdit(shortcut: shortcut),
                  trailing: widget.pickerMode
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _addOrEdit(shortcut: shortcut);
                            if (value == 'delete') _delete(shortcut);
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
        onPressed: () => _addOrEdit(),
        tooltip: 'Tambah shortcut',
        child: const Icon(Icons.add),
      ),
    );
  }
}
