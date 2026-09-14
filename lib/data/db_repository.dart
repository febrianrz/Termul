import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';

import '../models/db_connection.dart';
import '../models/db_query_shortcut.dart';
import '../models/host_group.dart';

/// Stores Database-tab metadata (connections, groups, saved query
/// shortcuts) the same way [HostRepository] (`lib/data/host_repository.dart`)
/// stores SSH hosts - Hive boxes for metadata, secure storage for the
/// password - but kept as its own repository since this is a separate
/// domain from SSH hosts, not more entities bolted onto that class.
///
/// Groups reuse the [HostGroup] model (`lib/models/host_group.dart`): it's
/// already just `{id, name}`, so there's no need for a near-identical
/// `DbGroup` type - only the box differs.
class DbRepository {
  static const _connectionsBoxName = 'db_connections';
  static const _groupsBoxName = 'db_groups';
  static const _queryShortcutsBoxName = 'db_query_shortcuts';

  final _secureStorage = const FlutterSecureStorage();
  late final Box _connectionsBox;
  late final Box _groupsBox;
  late final Box _queryShortcutsBox;

  Future<void> init() async {
    _connectionsBox = await Hive.openBox(_connectionsBoxName);
    _groupsBox = await Hive.openBox(_groupsBoxName);
    _queryShortcutsBox = await Hive.openBox(_queryShortcutsBoxName);
  }

  List<DbConnection> getAll() {
    return _connectionsBox.values
        .map(
          (e) => DbConnection.fromMap(Map<dynamic, dynamic>.from(e as Map)),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> save(DbConnection connection, {String? password}) async {
    await _connectionsBox.put(connection.id, connection.toMap());
    if (password != null) {
      await _secureStorage.write(
        key: 'db_password_${connection.id}',
        value: password,
      );
    }
  }

  Future<void> delete(String id) async {
    await _connectionsBox.delete(id);
    await _secureStorage.delete(key: 'db_password_$id');
  }

  Future<String?> getPassword(String id) =>
      _secureStorage.read(key: 'db_password_$id');

  /// Writes only the secret, leaving the connection's metadata box entry
  /// untouched - used by the edit screen's Test Connection button so trying
  /// a new password doesn't also persist whatever else is currently typed
  /// in the form before the user has pressed Save.
  Future<void> setPassword(String id, String password) =>
      _secureStorage.write(key: 'db_password_$id', value: password);

  List<HostGroup> getAllGroups() {
    return _groupsBox.values
        .map((e) => HostGroup.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> saveGroup(HostGroup group) async {
    await _groupsBox.put(group.id, group.toMap());
  }

  /// Deletes the group and un-assigns any connections that belonged to it.
  Future<void> deleteGroup(String id) async {
    await _groupsBox.delete(id);
    for (final connection in getAll()) {
      if (connection.groupId == id) {
        connection.groupId = null;
        await _connectionsBox.put(connection.id, connection.toMap());
      }
    }
  }

  List<DbQueryShortcut> getAllQueryShortcuts() {
    return _queryShortcutsBox.values
        .map(
          (e) => DbQueryShortcut.fromMap(Map<dynamic, dynamic>.from(e as Map)),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> saveQueryShortcut(DbQueryShortcut shortcut) async {
    await _queryShortcutsBox.put(shortcut.id, shortcut.toMap());
  }

  Future<void> deleteQueryShortcut(String id) async {
    await _queryShortcutsBox.delete(id);
  }
}
