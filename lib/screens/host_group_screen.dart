import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/host_repository.dart';
import '../l10n/app_strings.dart';
import '../models/host_group.dart';

/// Manage SSH host groups: add, rename, delete. Deleting a group just
/// un-assigns its hosts (they become ungrouped), it never deletes hosts.
class HostGroupScreen extends StatefulWidget {
  const HostGroupScreen({super.key});

  @override
  State<HostGroupScreen> createState() => _HostGroupScreenState();
}

class _HostGroupScreenState extends State<HostGroupScreen> {
  final AppStrings _s = AppStrings();
  late List<HostGroup> _groups;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _groups = context.read<HostRepository>().getAllGroups();
    });
  }

  Future<void> _addOrRename({HostGroup? group}) async {
    final repo = context.read<HostRepository>();
    final controller = TextEditingController(text: group?.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group == null ? _s.addGroup : _s.renameGroup),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: _s.groupName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(_s.save),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    await repo.saveGroup(
      HostGroup(id: group?.id ?? const Uuid().v4(), name: name),
    );
    if (mounted) _reload();
  }

  Future<void> _delete(HostGroup group) async {
    final repo = context.read<HostRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.deleteGroupTitle),
        content: Text(_s.deleteGroupBody(group.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.deleteGroup(group.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_s.sshGroups)),
      body: _groups.isEmpty
          ? Center(child: Text(_s.noGroupsYet))
          : ListView.separated(
              itemCount: _groups.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final group = _groups[index];
                return ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(group.name),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'rename') _addOrRename(group: group);
                      if (value == 'delete') _delete(group);
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'rename', child: Text(_s.rename)),
                      PopupMenuItem(value: 'delete', child: Text(_s.delete)),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrRename(),
        tooltip: _s.addGroupTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }
}
