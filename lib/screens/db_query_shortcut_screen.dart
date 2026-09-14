import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/db_repository.dart';
import '../l10n/app_strings.dart';
import '../models/db_connection.dart';
import '../models/db_query_shortcut.dart';

/// Manage saved SQL query shortcuts: add, edit, delete. Used both for
/// management (from the Database tab) and, in picker mode, to pick one to
/// insert into a workspace tab's query editor - the DB-side equivalent of
/// [ShortcutScreen] (`lib/screens/shortcut_screen.dart`).
class DbQueryShortcutScreen extends StatefulWidget {
  /// When true, tapping a shortcut pops the screen with it selected instead
  /// of opening the editor.
  final bool pickerMode;

  /// In picker mode, restricts the list to shortcuts that apply to this
  /// engine (i.e. `shortcut.engine == null || shortcut.engine == engine`).
  final DbEngine? engine;

  const DbQueryShortcutScreen({super.key, this.pickerMode = false, this.engine});

  @override
  State<DbQueryShortcutScreen> createState() => _DbQueryShortcutScreenState();
}

class _DbQueryShortcutScreenState extends State<DbQueryShortcutScreen> {
  final AppStrings _s = AppStrings();
  late List<DbQueryShortcut> _shortcuts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      final all = context.read<DbRepository>().getAllQueryShortcuts();
      _shortcuts = widget.pickerMode
          ? all
                .where(
                  (s) => s.engine == null || s.engine == widget.engine,
                )
                .toList()
          : all;
    });
  }

  Future<void> _addOrEdit({DbQueryShortcut? shortcut}) async {
    final repo = context.read<DbRepository>();
    final nameController = TextEditingController(text: shortcut?.name);
    final sqlController = TextEditingController(text: shortcut?.sql);
    DbEngine? engine = shortcut?.engine;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(shortcut == null ? _s.addShortcut : _s.editShortcut),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(labelText: _s.shortcutName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sqlController,
                decoration: InputDecoration(
                  labelText: _s.sqlQueryHint,
                ),
                style: const TextStyle(fontFamily: 'monospace'),
                maxLines: 4,
                minLines: 1,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DbEngine?>(
                initialValue: engine,
                decoration: InputDecoration(labelText: _s.dbEngine),
                items: [
                  DropdownMenuItem<DbEngine?>(child: Text(_s.anyEngine)),
                  const DropdownMenuItem(
                    value: DbEngine.mysql,
                    child: Text('MySQL'),
                  ),
                  const DropdownMenuItem(
                    value: DbEngine.mariadb,
                    child: Text('MariaDB'),
                  ),
                  const DropdownMenuItem(
                    value: DbEngine.postgres,
                    child: Text('PostgreSQL'),
                  ),
                  const DropdownMenuItem(
                    value: DbEngine.sqlite,
                    child: Text('SQLite'),
                  ),
                ],
                onChanged: (value) => setDialogState(() => engine = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_s.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_s.save),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final name = nameController.text.trim();
    final sql = sqlController.text.trim();
    if (name.isEmpty || sql.isEmpty) return;

    await repo.saveQueryShortcut(
      DbQueryShortcut(
        id: shortcut?.id ?? const Uuid().v4(),
        name: name,
        sql: sql,
        engine: engine,
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _delete(DbQueryShortcut shortcut) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.deleteShortcutTitle),
        content: Text(_s.deleteShortcutBody(shortcut.name)),
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
      await context.read<DbRepository>().deleteQueryShortcut(shortcut.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pickerMode ? _s.runQuery : _s.dbQueryShortcuts,
        ),
      ),
      body: _shortcuts.isEmpty
          ? Center(child: Text(_s.noCommandShortcutsYet))
          : ListView.separated(
              itemCount: _shortcuts.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final shortcut = _shortcuts[index];
                return ListTile(
                  leading: const Icon(Icons.bolt_outlined),
                  title: Text(shortcut.name),
                  subtitle: Text(
                    shortcut.sql,
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
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'edit', child: Text(_s.edit)),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(_s.delete),
                            ),
                          ],
                        ),
                );
              },
            ),
      floatingActionButton: widget.pickerMode
          ? null
          : FloatingActionButton(
              onPressed: () => _addOrEdit(),
              tooltip: _s.addShortcutTooltip,
              child: const Icon(Icons.add),
            ),
    );
  }
}
