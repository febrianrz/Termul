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
  List<String> tags;

  SshHost({
    required this.id,
    required this.name,
    required this.address,
    this.port = 22,
    required this.username,
    this.authType = SshAuthType.password,
    this.groupId,
    List<String>? tags,
  }) : tags = tags ?? [];

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'port': port,
    'username': username,
    'authType': authType.name,
    'groupId': groupId,
    'tags': tags,
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
    tags: (map['tags'] as List?)?.cast<String>() ?? const [],
  );

  /// Whether [query] matches this host's name, address, username or any tag
  /// (case-insensitive). Used by the host list's search box.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        address.toLowerCase().contains(q) ||
        username.toLowerCase().contains(q) ||
        tags.any((t) => t.toLowerCase().contains(q));
  }
}
