import 'package:dartssh2/dartssh2.dart';

import '../models/ssh_host.dart';

/// Validates SSH auth against a host without opening a shell/PTY - unlike
/// [TerminalSession.connect] (`lib/session/terminal_session.dart`), which
/// this mirrors for the socket+auth steps, nothing is left running on the
/// remote server afterwards: the connection is closed the moment
/// authentication succeeds or fails.
class SshConnectionTester {
  /// Returns `null` on success, or a human-readable error message.
  static Future<String?> test({
    required String address,
    required int port,
    required String username,
    required SshAuthType authType,
    String? password,
    String? privateKeyPem,
    String? passphrase,
  }) async {
    SSHClient? client;
    try {
      final socket = await SSHSocket.connect(
        address,
        port,
        timeout: const Duration(seconds: 15),
      );

      List<SSHKeyPair>? identities;
      if (authType == SshAuthType.privateKey) {
        if (privateKeyPem == null || privateKeyPem.isEmpty) {
          return 'Private key belum diisi';
        }
        identities = SSHKeyPair.fromPem(
          privateKeyPem,
          (passphrase != null && passphrase.isNotEmpty) ? passphrase : null,
        );
      }

      client = SSHClient(
        socket,
        username: username,
        onPasswordRequest: authType == SshAuthType.password
            ? () async => password
            : null,
        identities: identities,
      );

      await client.authenticated;
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      client?.close();
    }
  }
}
