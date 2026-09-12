import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import '../data/host_repository.dart';
import '../models/ssh_host.dart';

enum SftpConnectionState { connecting, connected, failed }

/// One SFTP browsing session for [host]. Connects independently of any
/// terminal session (its own [SSHClient]/[SftpClient]) and tracks the
/// current remote directory plus its listing.
class SftpSession extends ChangeNotifier {
  SftpSession(this.host);

  final SshHost host;

  SSHClient? _client;
  SftpClient? _sftp;
  bool _disposed = false;

  SftpConnectionState state = SftpConnectionState.connecting;
  String? errorMessage;

  /// Current remote directory, always an absolute path (e.g. `/home/user`).
  String path = '/';
  List<SftpName> entries = const [];

  bool get canGoUp => path != '/';

  Future<void> connect(HostRepository repo) async {
    state = SftpConnectionState.connecting;
    errorMessage = null;
    _notify();

    try {
      final socket = await SSHSocket.connect(
        host.address,
        host.port,
        timeout: const Duration(seconds: 15),
      );

      List<SSHKeyPair>? identities;
      if (host.authType == SshAuthType.privateKey) {
        final pem = await repo.getPrivateKey(host.id);
        if (pem == null || pem.isEmpty) {
          throw Exception('Private key belum diisi untuk host ini');
        }
        final passphrase = await repo.getPassphrase(host.id);
        identities = SSHKeyPair.fromPem(
          pem,
          (passphrase != null && passphrase.isNotEmpty) ? passphrase : null,
        );
      }

      final client = SSHClient(
        socket,
        username: host.username,
        onPasswordRequest: host.authType == SshAuthType.password
            ? () => repo.getPassword(host.id)
            : null,
        identities: identities,
      );
      _client = client;
      await client.authenticated;

      final sftp = await client.sftp();
      _sftp = sftp;
      path = await sftp.absolute('.');

      state = SftpConnectionState.connected;
      await _reload();
    } catch (e) {
      state = SftpConnectionState.failed;
      errorMessage = e.toString();
      _notify();
    }
  }

  Future<void> _reload() async {
    final names = await _sftp!.listdir(path);
    entries = names.where((n) => n.filename != '.' && n.filename != '..').toList()
      ..sort((a, b) {
        if (a.attr.isDirectory != b.attr.isDirectory) {
          return a.attr.isDirectory ? -1 : 1;
        }
        return a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
      });
    _notify();
  }

  Future<void> refresh() => _reload();

  Future<void> open(SftpName entry) async {
    if (!entry.attr.isDirectory) return;
    path = _join(path, entry.filename);
    await _reload();
  }

  Future<void> goUp() async {
    if (!canGoUp) return;
    final segments = path.split('/')..removeWhere((s) => s.isEmpty);
    segments.removeLast();
    path = segments.isEmpty ? '/' : '/${segments.join('/')}';
    await _reload();
  }

  String _join(String base, String name) =>
      base == '/' ? '/$name' : '$base/$name';

  Future<void> mkdir(String name) async {
    await _sftp!.mkdir(_join(path, name));
    await _reload();
  }

  Future<void> delete(SftpName entry) async {
    final full = _join(path, entry.filename);
    if (entry.attr.isDirectory) {
      await _sftp!.rmdir(full);
    } else {
      await _sftp!.remove(full);
    }
    await _reload();
  }

  Future<void> rename(SftpName entry, String newName) async {
    await _sftp!.rename(_join(path, entry.filename), _join(path, newName));
    await _reload();
  }

  /// Uploads [localFile] into the current directory as [remoteName].
  Future<void> upload(
    File localFile,
    String remoteName, {
    void Function(int bytesSent)? onProgress,
  }) async {
    final remoteFile = await _sftp!.open(
      _join(path, remoteName),
      mode:
          SftpFileOpenMode.create |
          SftpFileOpenMode.truncate |
          SftpFileOpenMode.write,
    );
    try {
      await remoteFile
          .write(localFile.openRead().cast(), onProgress: onProgress)
          .done;
    } finally {
      await remoteFile.close();
    }
    await _reload();
  }

  /// Downloads [entry] (from the current directory) into [localFile].
  Future<void> download(
    SftpName entry,
    File localFile, {
    void Function(int bytesRead)? onProgress,
  }) async {
    final remoteFile = await _sftp!.open(
      _join(path, entry.filename),
      mode: SftpFileOpenMode.read,
    );
    try {
      await remoteFile.downloadTo(
        localFile.openWrite(),
        onProgress: onProgress,
        closeDestination: true,
      );
    } finally {
      await remoteFile.close();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sftp?.close();
    _client?.close();
    super.dispose();
  }
}
