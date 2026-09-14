import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/db_repository.dart';
import '../data/host_repository.dart';
import '../l10n/app_strings.dart';
import '../models/db_connection.dart';
import '../models/db_query_shortcut.dart';
import '../services/db/db_driver.dart';
import '../session/db_session.dart';
import '../session/db_session_manager.dart';
import '../session/session_manager.dart';

/// Shows every open [DbSession] as a tab, the Database-tab equivalent of
/// [TerminalTabsScreen] (`lib/screens/terminal_tabs_screen.dart`): switching
/// tabs is instant, and each connection keeps running in the background via
/// [DbSessionManager] rather than dying when its tab isn't in front.
///
/// [initialConnection], if given, is opened (or just selected, if already
/// open) once when this screen first builds.
class DbWorkspaceScreen extends StatefulWidget {
  final DbConnection? initialConnection;

  const DbWorkspaceScreen({super.key, this.initialConnection});

  @override
  State<DbWorkspaceScreen> createState() => _DbWorkspaceScreenState();
}

class _DbWorkspaceScreenState extends State<DbWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  final AppStrings _s = AppStrings();
  TabController? _tabController;
  String? _activeConnectionId;
  int _controllerLength = -1;

  @override
  void initState() {
    super.initState();
    final connection = widget.initialConnection;
    _activeConnectionId = connection?.id;
    if (connection != null) {
      context.read<DbSessionManager>().open(
        connection,
        context.read<DbRepository>(),
        context.read<HostRepository>(),
        context.read<SessionManager>(),
      );
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _ensureController(List<DbSession> sessions) {
    if (_tabController != null && sessions.length == _controllerLength) {
      return;
    }

    final wanted = _activeConnectionId;
    final foundIndex = wanted == null
        ? -1
        : sessions.indexWhere((s) => s.connection.id == wanted);
    final index = sessions.isEmpty
        ? 0
        : (foundIndex >= 0 ? foundIndex : sessions.length - 1);

    _tabController?.dispose();
    _tabController = TabController(
      length: sessions.length,
      initialIndex: index,
      vsync: this,
    );
    _controllerLength = sessions.length;
    _activeConnectionId = sessions.isEmpty ? null : sessions[index].connection.id;
  }

  void _closeSession(DbSession session) {
    context.read<DbSessionManager>().closeSession(session.connection.id);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<DbSessionManager>().sessions;
    _ensureController(sessions);

    if (sessions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_s.databaseTab)),
        body: Center(
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: Text(_s.backToHostList),
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
                (s) => _DbSessionTab(
                  key: ValueKey(s.connection.id),
                  session: s,
                  onClose: () => _closeSession(s),
                ),
              )
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: controller,
        children: sessions
            .map(
              (s) => _DbSessionView(key: ValueKey(s.connection.id), session: s),
            )
            .toList(),
      ),
    );
  }
}

class _DbSessionTab extends StatelessWidget {
  final DbSession session;
  final VoidCallback onClose;

  const _DbSessionTab({super.key, required this.session, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Tooltip(
        message: session.connection.name,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Color(session.connection.colorValue),
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
    );
  }
}

/// One tab's body: connecting/failed UI, or (once connected) a database and
/// table picker above a SQL editor and its results grid, scoped to a single
/// [session] so it can live inside a [TabBarView] page.
class _DbSessionView extends StatefulWidget {
  final DbSession session;

  const _DbSessionView({super.key, required this.session});

  @override
  State<_DbSessionView> createState() => _DbSessionViewState();
}

class _DbSessionViewState extends State<_DbSessionView> {
  final AppStrings _s = AppStrings();
  final _sqlController = TextEditingController();

  List<String> _databases = [];
  List<String> _tables = [];
  List<DbQueryShortcut> _shortcuts = [];
  String? _selectedDatabase;
  DbQueryResult? _result;
  String? _queryError;
  bool _running = false;
  DbConnectionState? _lastLoadedFor;

  int _subTab = 0; // 0 = Query, 1 = Users
  List<DbUser>? _users;
  String? _usersError;
  bool _loadingUsers = false;

  @override
  void initState() {
    super.initState();
    _selectedDatabase = widget.session.connection.database;
    widget.session.addListener(_onSessionChanged);
    _maybeLoadDatabases();
    _loadShortcuts();
  }

  void _loadShortcuts() {
    final engine = widget.session.connection.engine;
    final all = context.read<DbRepository>().getAllQueryShortcuts();
    setState(() {
      _shortcuts = all
          .where((s) => s.engine == null || s.engine == engine)
          .toList();
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _sqlController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    _maybeLoadDatabases();
    if (mounted) setState(() {});
  }

  Future<void> _maybeLoadDatabases() async {
    final session = widget.session;
    if (session.state != DbConnectionState.connected) return;
    if (_lastLoadedFor == DbConnectionState.connected) return;
    _lastLoadedFor = DbConnectionState.connected;

    try {
      final databases = await session.listDatabases();
      if (!mounted) return;
      setState(() => _databases = databases);
      if (_selectedDatabase != null) {
        await _loadTables(_selectedDatabase!);
      }
    } catch (_) {
      // Best-effort - the query editor still works without the picker.
    }
  }

  Future<void> _loadTables(String database) async {
    try {
      final tables = await widget.session.listTables(database);
      if (!mounted) return;
      setState(() => _tables = tables);
    } catch (_) {
      // Best-effort, same as above.
    }
  }

  Future<void> _runQuery() async {
    final sql = _sqlController.text.trim();
    if (sql.isEmpty) return;

    setState(() {
      _running = true;
      _queryError = null;
    });
    try {
      final result = await widget.session.runQuery(
        sql,
        database: _selectedDatabase,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _queryError = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    try {
      final users = await widget.session.listUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (e) {
      if (!mounted) return;
      setState(() => _usersError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _createUserDialog() async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final hostController = TextEditingController(text: '%');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.createUser),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              autofocus: true,
              decoration: InputDecoration(labelText: _s.username),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: _s.password),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hostController,
              decoration: InputDecoration(labelText: _s.hostPattern),
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
    );

    if (saved != true) return;
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final host = hostController.text.trim();
    if (username.isEmpty || password.isEmpty) return;

    try {
      await widget.session.createUser(
        username,
        password,
        host: host.isEmpty ? null : host,
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _dropUserConfirm(DbUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.dropUserConfirmTitle),
        content: Text(_s.dropUserConfirmBody(user.username)),
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

    try {
      await widget.session.dropUser(user.username, host: user.host);
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _viewGrants(DbUser user) async {
    List<String> grants;
    try {
      grants = await widget.session.listGrants(user.username, host: user.host);
    } catch (e) {
      grants = [e.toString()];
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.host != null ? '${user.username}@${user.host}' : user.username),
        content: SizedBox(
          width: double.maxFinite,
          child: grants.isEmpty
              ? Text(_s.noGrantsFound)
              : ListView(
                  shrinkWrap: true,
                  children: grants
                      .map(
                        (g) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            g,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_s.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _reconnect() {
    _lastLoadedFor = null;
    return widget.session.connect(
      context.read<DbRepository>(),
      context.read<HostRepository>(),
      context.read<SessionManager>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.session.state) {
      case DbConnectionState.connecting:
        return const Center(child: CircularProgressIndicator());
      case DbConnectionState.failed:
      case DbConnectionState.closed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.session.state == DbConnectionState.failed) ...[
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    widget.session.errorMessage ?? '',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: _reconnect,
                  icon: const Icon(Icons.refresh),
                  label: Text(_s.reconnect),
                ),
              ],
            ),
          ),
        );
      case DbConnectionState.connected:
        return _connectedBody();
    }
  }

  Widget _connectedBody() {
    if (!widget.session.supportsUserManagement) return _queryTab();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(_s.queryTabLabel)),
              ButtonSegment(value: 1, label: Text(_s.usersTab)),
            ],
            selected: {_subTab},
            onSelectionChanged: (s) {
              setState(() => _subTab = s.first);
              if (_subTab == 1) _loadUsers();
            },
          ),
        ),
        Expanded(child: _subTab == 0 ? _queryTab() : _usersTab()),
      ],
    );
  }

  Widget _usersTab() {
    if (_loadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usersError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_usersError!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    final users = _users ?? [];
    return Stack(
      children: [
        users.isEmpty
            ? Center(child: Text(_s.noUsersFound))
            : ListView.separated(
                itemCount: users.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(user.username),
                    subtitle: user.host != null ? Text('@${user.host}') : null,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'grants') _viewGrants(user);
                        if (value == 'drop') _dropUserConfirm(user);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'grants',
                          child: Text(_s.viewGrants),
                        ),
                        PopupMenuItem(value: 'drop', child: Text(_s.dropUser)),
                      ],
                    ),
                  );
                },
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _createUserDialog,
            tooltip: _s.createUser,
            child: const Icon(Icons.person_add_alt),
          ),
        ),
      ],
    );
  }

  Widget _queryTab() {
    return Column(
      children: [
        if (_databases.isNotEmpty) _dbTablePicker(),
        if (_shortcuts.isNotEmpty) _shortcutChipRow(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _sqlController,
            decoration: InputDecoration(
              hintText: _s.sqlQueryHint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            maxLines: 4,
            minLines: 2,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: _running ? null : _runQuery,
                icon: _running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_s.runQuery),
              ),
              if (_result != null) ...[
                const SizedBox(width: 12),
                Text(
                  _s.queryRowsInfo(_result!.rows.length, _result!.affectedRows),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _resultsArea()),
      ],
    );
  }

  Widget _shortcutChipRow() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        itemCount: _shortcuts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final shortcut = _shortcuts[index];
          return ActionChip(
            avatar: const Icon(Icons.bolt_outlined, size: 16),
            label: Text(shortcut.name),
            onPressed: () =>
                setState(() => _sqlController.text = shortcut.sql),
          );
        },
      ),
    );
  }

  Widget _dbTablePicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: _selectedDatabase,
              decoration: InputDecoration(
                labelText: _s.databaseTab,
                isDense: true,
              ),
              items: _databases
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDatabase = value;
                  _tables = [];
                });
                if (value != null) _loadTables(value);
              },
            ),
          ),
          if (_tables.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: _s.selectTableHint,
                  isDense: true,
                ),
                items: _tables
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (table) {
                  if (table == null) return;
                  setState(
                    () => _sqlController.text = 'SELECT * FROM `$table` LIMIT 100',
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultsArea() {
    if (_queryError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_queryError!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    final result = _result;
    if (result == null) {
      return Center(child: Text(_s.selectTableHint));
    }
    if (result.rows.isEmpty) {
      return Center(child: Text(_s.queryResultEmpty));
    }

    // First 500 rows only - no server-side pagination yet, see the plan's
    // "known limitation" note for this slice.
    final rows = result.rows.take(500).toList();
    return Scrollbar(
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: result.columns
                .map((c) => DataColumn(label: Text(c)))
                .toList(),
            rows: rows
                .map(
                  (row) => DataRow(
                    cells: row
                        .map((v) => DataCell(Text(v?.toString() ?? 'NULL')))
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
