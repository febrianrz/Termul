import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';

import '../models/ssh_host.dart';

/// Stores host metadata in a local Hive box and secrets (password,
/// private key, passphrase) in the platform secure storage (Keychain /
/// Keystore). Everything is local-only for now — no cloud sync.
class HostRepository {
  static const _boxName = 'ssh_hosts';

  final _secureStorage = const FlutterSecureStorage();
  late final Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
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
}
