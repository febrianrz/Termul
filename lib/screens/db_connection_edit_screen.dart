import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/db_repository.dart';
import '../data/host_repository.dart';
import '../l10n/app_strings.dart';
import '../models/db_connection.dart';
import '../models/host_group.dart';
import '../models/ssh_host.dart';
import '../session/db_session.dart';
import '../session/session_manager.dart';

/// Preset swatches for a connection's color dot - kept to a small fixed
/// palette instead of a full color-picker package, per the "as simple as
/// possible" ask this feature was built for.
const List<int> _dbColorSwatches = [
  0xFFE53935, // red
  0xFFFB8C00, // orange
  0xFFFDD835, // yellow
  0xFF43A047, // green
  0xFF00ACC1, // cyan
  0xFF1E88E5, // blue
  0xFF5E35B1, // deep purple
  0xFFD81B60, // pink
  0xFF6D4C41, // brown
  0xFF757575, // grey
];

class DbConnectionEditScreen extends StatefulWidget {
  final DbConnection? connection;

  const DbConnectionEditScreen({super.key, this.connection});

  @override
  State<DbConnectionEditScreen> createState() =>
      _DbConnectionEditScreenState();
}

class _DbConnectionEditScreenState extends State<DbConnectionEditScreen> {
  final AppStrings _s = AppStrings();
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(
    text: widget.connection?.name,
  );
  late final _hostController = TextEditingController(
    text: widget.connection?.host,
  );
  late final _portController = TextEditingController(
    text: (widget.connection?.port ?? 3306).toString(),
  );
  late final _usernameController = TextEditingController(
    text: widget.connection?.username,
  );
  final _passwordController = TextEditingController();
  late final _databaseController = TextEditingController(
    text: widget.connection?.database,
  );
  late final _tagsController = TextEditingController(
    text: (widget.connection?.tags ?? const <String>[]).join(', '),
  );
  late final _sqliteRemotePathController = TextEditingController(
    text: widget.connection?.sqliteRemotePath,
  );

  late DbEngine _engine = widget.connection?.engine ?? DbEngine.mysql;
  late DbConnectMode _connectMode =
      widget.connection?.connectMode ?? DbConnectMode.tunnel;
  late String? _sshHostId = widget.connection?.sshHostId;
  late String? _groupId = widget.connection?.groupId;
  late int _colorValue = widget.connection?.colorValue ?? _dbColorSwatches[5];
  late SqliteSource _sqliteSource =
      widget.connection?.sqliteSource ?? SqliteSource.local;
  String? _sqliteLocalPath = widget.connection?.sqliteLocalPath;

  bool get _isSqlite => _engine == DbEngine.sqlite;

  late List<SshHost> _sshHosts;
  late List<HostGroup> _groups;
  bool _saving = false;
  bool _testing = false;

  bool get _isEditing => widget.connection != null;

  @override
  void initState() {
    super.initState();
    _sshHosts = context.read<HostRepository>().getAll();
    _groups = context.read<DbRepository>().getAllGroups();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _databaseController.dispose();
    _tagsController.dispose();
    _sqliteRemotePathController.dispose();
    super.dispose();
  }

  Future<void> _pickSqliteFile() async {
    final result = await FilePicker.pickFiles();
    final path = result?.files.single.path;
    if (path != null) setState(() => _sqliteLocalPath = path);
  }

  /// Returns an error message if the current engine/mode-specific fields
  /// are incomplete, or `null` if the draft is ready to save/test.
  String? _validate() {
    if (_isSqlite) {
      if (_sqliteSource == SqliteSource.local) {
        if (_sqliteLocalPath == null || _sqliteLocalPath!.isEmpty) {
          return _s.selectSqliteFile;
        }
      } else {
        if (_sshHostId == null) return _s.selectSshHost;
        if (_sqliteRemotePathController.text.trim().isEmpty) {
          return _s.enterSqliteRemotePath;
        }
      }
    } else if (_connectMode == DbConnectMode.tunnel && _sshHostId == null) {
      return _s.selectSshHost;
    }
    return null;
  }

  int _defaultPortFor(DbEngine engine) =>
      engine == DbEngine.postgres ? 5432 : 3306;

  List<String> _parseTags() => _tagsController.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();

  DbConnection _buildDraft() => DbConnection(
    id: widget.connection?.id ?? const Uuid().v4(),
    name: _nameController.text.trim(),
    engine: _engine,
    connectMode: _connectMode,
    sshHostId: _isSqlite
        ? (_sqliteSource == SqliteSource.remote ? _sshHostId : null)
        : (_connectMode == DbConnectMode.tunnel ? _sshHostId : null),
    host: _isSqlite ? '' : _hostController.text.trim(),
    port: _isSqlite ? 0 : (int.tryParse(_portController.text.trim()) ?? 3306),
    username: _isSqlite ? '' : _usernameController.text.trim(),
    database: _isSqlite || _databaseController.text.trim().isEmpty
        ? null
        : _databaseController.text.trim(),
    sqliteSource: _isSqlite ? _sqliteSource : null,
    sqliteLocalPath: _isSqlite && _sqliteSource == SqliteSource.local
        ? _sqliteLocalPath
        : null,
    sqliteRemotePath: _isSqlite && _sqliteSource == SqliteSource.remote
        ? _sqliteRemotePathController.text.trim()
        : null,
    colorValue: _colorValue,
    tags: _parseTags(),
    groupId: _groupId,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final validationError = _validate();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    setState(() => _saving = true);
    final repo = context.read<DbRepository>();
    final connection = _buildDraft();

    await repo.save(
      connection,
      password: _passwordController.text.isNotEmpty
          ? _passwordController.text
          : null,
    );

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addGroup() async {
    final repo = context.read<DbRepository>();
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.newGroup),
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

    final group = HostGroup(id: const Uuid().v4(), name: name);
    await repo.saveGroup(group);
    if (!mounted) return;
    setState(() {
      _groups = [..._groups, group];
      _groupId = group.id;
    });
  }

  /// Validates the connection against the form's current draft values
  /// (tunneling through the chosen SSH host's already-running session, if
  /// any) without opening the workspace screen - a throwaway [DbSession] is
  /// connected then immediately closed, so nothing is left registered in
  /// [DbSessionManager].
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    final validationError = _validate();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    setState(() => _testing = true);
    final dbRepo = context.read<DbRepository>();
    final hostRepo = context.read<HostRepository>();
    final sshSessionManager = context.read<SessionManager>();

    final draft = _buildDraft();
    final typedPassword = _passwordController.text;

    // Only the secret is written here (never the connection's metadata box
    // entry) - the throwaway session below looks the password up by id the
    // same way a real one would, without silently persisting whatever else
    // is currently typed in the form before the user has pressed Save.
    if (typedPassword.isNotEmpty) {
      await dbRepo.setPassword(draft.id, typedPassword);
    }
    // Otherwise, when editing, [draft.id] already equals the saved
    // connection's id, so DbSession.connect's own repo.getPassword lookup
    // resolves to the already-persisted secret with nothing to write.

    final session = DbSession(draft);
    await session.connect(dbRepo, hostRepo, sshSessionManager);
    final error = session.state == DbConnectionState.failed
        ? session.errorMessage
        : null;
    await session.close();

    if (!_isEditing && typedPassword.isNotEmpty) {
      // Clean up the password temporarily written above for a connection
      // the user hasn't actually saved yet (no metadata entry was ever
      // written for it, so this only clears that secret).
      await dbRepo.delete(draft.id);
    }

    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null ? _s.connectionOk : _s.connectionFailed(error),
        ),
        backgroundColor: error == null
            ? Colors.green.shade700
            : Colors.red.shade700,
      ),
    );
  }

  Widget _colorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _dbColorSwatches.map((value) {
        final selected = value == _colorValue;
        return GestureDetector(
          onTap: () => setState(() => _colorValue = value),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Color(value),
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(color: Colors.white, width: 2)
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? _s.editDbConnection : _s.addDbConnection),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: _s.shortcutName),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? _s.requiredField : null,
            ),
            const SizedBox(height: 20),
            Text(_s.dbEngine, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<DbEngine>(
              segments: const [
                ButtonSegment(value: DbEngine.mysql, label: Text('MySQL')),
                ButtonSegment(value: DbEngine.mariadb, label: Text('MariaDB')),
                ButtonSegment(
                  value: DbEngine.postgres,
                  label: Text('PostgreSQL'),
                ),
                ButtonSegment(value: DbEngine.sqlite, label: Text('SQLite')),
              ],
              selected: {_engine},
              onSelectionChanged: (s) => setState(() {
                final previousDefault = _defaultPortFor(_engine);
                _engine = s.first;
                final newDefault = _defaultPortFor(_engine);
                final currentPort = _portController.text.trim();
                if (currentPort.isEmpty ||
                    currentPort == previousDefault.toString()) {
                  _portController.text = newDefault.toString();
                }
              }),
            ),
            const SizedBox(height: 20),
            if (_isSqlite) ...[
              Text(_s.sqliteSource, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<SqliteSource>(
                segments: [
                  ButtonSegment(
                    value: SqliteSource.local,
                    label: Text(_s.sqliteSourceLocal),
                    icon: const Icon(Icons.smartphone),
                  ),
                  ButtonSegment(
                    value: SqliteSource.remote,
                    label: Text(_s.sqliteSourceRemote),
                    icon: const Icon(Icons.dns_outlined),
                  ),
                ],
                selected: {_sqliteSource},
                onSelectionChanged: (s) =>
                    setState(() => _sqliteSource = s.first),
              ),
              const SizedBox(height: 12),
              if (_sqliteSource == SqliteSource.local)
                OutlinedButton.icon(
                  onPressed: _pickSqliteFile,
                  icon: const Icon(Icons.file_open_outlined),
                  label: Text(
                    _sqliteLocalPath == null
                        ? _s.selectSqliteFile
                        : _sqliteLocalPath!.split('/').last,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else ...[
                DropdownButtonFormField<String?>(
                  initialValue: _sshHostId,
                  decoration: InputDecoration(labelText: _s.sshHost),
                  items: _sshHosts
                      .map(
                        (h) => DropdownMenuItem<String?>(
                          value: h.id,
                          child: Text(h.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _sshHostId = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sqliteRemotePathController,
                  decoration: InputDecoration(
                    labelText: _s.sqliteRemotePathLabel,
                    hintText: '/var/www/app/database.sqlite',
                  ),
                ),
              ],
            ] else ...[
              Text(_s.connectMode, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<DbConnectMode>(
                segments: [
                  ButtonSegment(
                    value: DbConnectMode.tunnel,
                    label: Text(_s.tunnelViaHost),
                    icon: const Icon(Icons.swap_horiz),
                  ),
                  ButtonSegment(
                    value: DbConnectMode.direct,
                    label: Text(_s.directConnection),
                    icon: const Icon(Icons.podcasts),
                  ),
                ],
                selected: {_connectMode},
                onSelectionChanged: (s) =>
                    setState(() => _connectMode = s.first),
              ),
              if (_connectMode == DbConnectMode.tunnel) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: _sshHostId,
                  decoration: InputDecoration(labelText: _s.sshHost),
                  items: _sshHosts
                      .map(
                        (h) => DropdownMenuItem<String?>(
                          value: h.id,
                          child: Text(h.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _sshHostId = value),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: _s.dbHostLabel,
                  hintText: _connectMode == DbConnectMode.tunnel
                      ? _s.dbHostTunnelHint
                      : _s.dbHostDirectHint,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? _s.requiredField : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portController,
                decoration: InputDecoration(labelText: _s.port),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final port = int.tryParse(v?.trim() ?? '');
                  if (port == null || port <= 0 || port > 65535) {
                    return _s.invalidPort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: _s.username),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? _s.requiredField : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: _s.password,
                  hintText: _isEditing ? _s.leaveBlankToKeep : null,
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _databaseController,
                decoration: InputDecoration(
                  labelText: _s.defaultDatabaseOptional,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _groupId,
                    decoration: InputDecoration(labelText: _s.groupOptional),
                    items: [
                      DropdownMenuItem<String?>(child: Text(_s.ungrouped)),
                      ..._groups.map(
                        (g) => DropdownMenuItem<String?>(
                          value: g.id,
                          child: Text(g.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _groupId = value),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined),
                  tooltip: _s.newGroupTooltip,
                  onPressed: _addGroup,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: _s.tagsOptional,
                hintText: _s.tagsHint,
              ),
            ),
            const SizedBox(height: 20),
            Text(_s.color, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            _colorPicker(),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(_s.testConnection),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_s.save),
            ),
          ],
        ),
      ),
    );
  }
}
