enum SshAuthType { password, privateKey }

/// Metadata for a saved SSH host. Secrets (password / private key /
/// passphrase) are never stored here — they live in secure storage,
/// keyed by [id], and are looked up separately when connecting.
class SshHost {
  final String id;
  String name;
  String address;
  int port;
  String username;
  SshAuthType authType;
  String? groupId;

  SshHost({
    required this.id,
    required this.name,
    required this.address,
    this.port = 22,
    required this.username,
    this.authType = SshAuthType.password,
    this.groupId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'port': port,
    'username': username,
    'authType': authType.name,
    'groupId': groupId,
  };

  factory SshHost.fromMap(Map<dynamic, dynamic> map) => SshHost(
    id: map['id'] as String,
    name: map['name'] as String,
    address: map['address'] as String,
    port: map['port'] as int,
    username: map['username'] as String,
    authType: SshAuthType.values.firstWhere(
      (e) => e.name == map['authType'],
      orElse: () => SshAuthType.password,
    ),
    groupId: map['groupId'] as String?,
  );
}
