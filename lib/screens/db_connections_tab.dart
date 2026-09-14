import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db_repository.dart';
import '../l10n/app_strings.dart';
import '../models/db_connection.dart';
import '../models/host_group.dart';
import '../session/db_session_manager.dart';
import 'db_connection_edit_screen.dart';
import 'db_workspace_screen.dart';

/// List of saved Database connections, grouped like [HostListScreen]'s SSH
/// list: a leading color dot (per connection), tags in the subtitle, grouped
/// by [HostGroup] with an "Ungrouped" section, search bar, FAB to add.
///
/// Embedded as one of the app's bottom-nav pages (see
/// `lib/screens/host_list_screen.dart`) rather than pushed, so it owns its
/// own [AppBar]/search/FAB like [WebShortcutsTab] does.
class DbConnectionsTab extends StatefulWidget {
  const DbConnectionsTab({super.key});

  @override
  State<DbConnectionsTab> createState() => _DbConnectionsTabState();
}

class _DbConnectionsTabState extends State<DbConnectionsTab>
    with AutomaticKeepAliveClientMixin {
  final AppStrings _s = AppStrings();
  late List<DbConnection> _connections;
  late List<HostGroup> _groups;
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = context.read<DbRepository>();
    setState(() {
      _connections = repo.getAll();
      _groups = repo.getAllGroups();
    });
  }

  Future<void> _openEditor({DbConnection? connection}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DbConnectionEditScreen(connection: connection),
      ),
    );
    _reload();
  }

  void _open(DbConnection connection) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DbWorkspaceScreen(initialConnection: connection),
      ),
    );
  }

  Future<void> _delete(DbConnection connection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.deleteDbConnectionTitle),
        content: Text(_s.deleteDbConnectionBody(connection.name)),
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
    if (confirmed != true) return;

    context.read<DbSessionManager>().closeSession(connection.id);
    await context.read<DbRepository>().delete(connection.id);
    _reload();
  }

  List<DbConnection> get _filtered =>
      _connections.where((c) => c.matches(_searchQuery)).toList();

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

  Widget _tile(DbConnection connection) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(connection.colorValue),
        child: Text(
          connection.name.isEmpty ? '?' : connection.name[0].toUpperCase(),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(connection.name),
      subtitle: Text(
        connection.tags.isEmpty
            ? '${connection.username}@${connection.host}:${connection.port}'
            : '${connection.username}@${connection.host}:${connection.port}'
                  ' · ${connection.tags.join(', ')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _open(connection),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') _openEditor(connection: connection);
          if (value == 'delete') _delete(connection);
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'edit', child: Text(_s.edit)),
          PopupMenuItem(value: 'delete', child: Text(_s.delete)),
        ],
      ),
    );
  }

  Widget _body() {
    if (_connections.isEmpty) {
      return _EmptyState(onAdd: () => _openEditor());
    }

    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(child: Text(_s.noMatchingDbConnections));
    }

    if (_groups.isEmpty || _searchQuery.isNotEmpty) {
      return ListView.separated(
        itemCount: filtered.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) => _tile(filtered[index]),
      );
    }

    final byGroup = <String?, List<DbConnection>>{};
    for (final connection in filtered) {
      byGroup.putIfAbsent(connection.groupId, () => []).add(connection);
    }

    final sections = <Widget>[];
    for (final group in _groups) {
      final items = byGroup[group.id];
      if (items == null || items.isEmpty) continue;
      sections.add(_sectionHeader(group.name));
      sections.addAll(items.map(_tile));
    }
    final ungrouped = byGroup[null];
    if (ungrouped != null && ungrouped.isNotEmpty) {
      sections.add(_sectionHeader(_s.ungrouped));
      sections.addAll(ungrouped.map(_tile));
    }

    return ListView(children: sections);
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: TextField(
        decoration: InputDecoration(
          hintText: _s.searchDbConnectionsHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() => _searchQuery = ''),
                ),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Column(
          children: [
            if (_connections.isNotEmpty) _searchBar(),
            Expanded(child: _body()),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: () => _openEditor(),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storage_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(s.noDbConnectionsYet),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(s.addDbConnection),
          ),
        ],
      ),
    );
  }
}
