import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';

import '../models/command_shortcut.dart';
import '../models/host_group.dart';
import '../models/ssh_host.dart';

/// Stores host metadata in a local Hive box and secrets (password,
/// private key, passphrase) in the platform secure storage (Keychain /
/// Keystore). Everything is local-only for now — no cloud sync.
class HostRepository {
  static const _boxName = 'ssh_hosts';
  static const _groupsBoxName = 'ssh_groups';
  static const _shortcutsBoxName = 'command_shortcuts';

  final _secureStorage = const FlutterSecureStorage();
  late final Box _box;
  late final Box _groupsBox;
  late final Box _shortcutsBox;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _groupsBox = await Hive.openBox(_groupsBoxName);
    _shortcutsBox = await Hive.openBox(_shortcutsBoxName);
  }

  List<SshHost> getAll() {
    return _box.values
        .map((e) => SshHost.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> save(
    SshHost host, {
    String? password,
    String? privateKey,
    String? passphrase,
  }) async {
    await _box.put(host.id, host.toMap());
    if (password != null) {
      await _secureStorage.write(key: 'password_${host.id}', value: password);
    }
    if (privateKey != null) {
      await _secureStorage.write(
        key: 'privateKey_${host.id}',
        value: privateKey,
      );
    }
    if (passphrase != null) {
      await _secureStorage.write(
        key: 'passphrase_${host.id}',
        value: passphrase,
      );
    }
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    await _secureStorage.delete(key: 'password_$id');
    await _secureStorage.delete(key: 'privateKey_$id');
    await _secureStorage.delete(key: 'passphrase_$id');
  }

  Future<String?> getPassword(String id) =>
      _secureStorage.read(key: 'password_$id');

  Future<String?> getPrivateKey(String id) =>
      _secureStorage.read(key: 'privateKey_$id');

  Future<String?> getPassphrase(String id) =>
      _secureStorage.read(key: 'passphrase_$id');

  List<HostGroup> getAllGroups() {
    return _groupsBox.values
        .map((e) => HostGroup.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> saveGroup(HostGroup group) async {
    await _groupsBox.put(group.id, group.toMap());
  }

  /// Deletes the group and un-assigns any hosts that belonged to it.
  Future<void> deleteGroup(String id) async {
    await _groupsBox.delete(id);
    for (final host in getAll()) {
      if (host.groupId == id) {
        host.groupId = null;
        await _box.put(host.id, host.toMap());
      }
    }
  }

  List<CommandShortcut> getAllShortcuts() {
    return _shortcutsBox.values
        .map(
          (e) => CommandShortcut.fromMap(Map<dynamic, dynamic>.from(e as Map)),
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> saveShortcut(CommandShortcut shortcut) async {
    await _shortcutsBox.put(shortcut.id, shortcut.toMap());
  }

  Future<void> deleteShortcut(String id) async {
    await _shortcutsBox.delete(id);
  }
}
