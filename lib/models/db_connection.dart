/// Which wire protocol/engine a [DbConnection] speaks. MySQL and MariaDB
/// share a driver (same protocol); Postgres and SQLite are declared here for
/// forward compatibility but aren't wired into a driver yet.
enum DbEngine { mysql, mariadb, postgres, sqlite }

/// How a [DbConnection] reaches its server. Ignored for [DbEngine.sqlite],
/// which instead reads a file (local or fetched over SFTP - not yet wired).
enum DbConnectMode { tunnel, direct }

/// Metadata for a saved database connection. Like [SshHost]
/// (`lib/models/ssh_host.dart`), the password is never stored here - it
/// lives in secure storage, keyed by [id].
class DbConnection {
  final String id;
  String name;
  DbEngine engine;
  DbConnectMode connectMode;

  /// Required when [connectMode] is [DbConnectMode.tunnel]: the SSH host
  /// whose connection is reused to open a local forward to [host]:[port].
  String? sshHostId;

  /// The database server's address and port - as seen from the SSH host
  /// when tunneling (e.g. `127.0.0.1` if the DB only listens locally on the
  /// jump host), or directly reachable from this device otherwise.
  String host;
  int port;
  String username;
  String? database;

  int colorValue;
  List<String> tags;
  String? groupId;

  DbConnection({
    required this.id,
    required this.name,
    required this.engine,
    this.connectMode = DbConnectMode.tunnel,
    this.sshHostId,
    required this.host,
    required this.port,
    required this.username,
    this.database,
    required this.colorValue,
    List<String>? tags,
    this.groupId,
  }) : tags = tags ?? [];

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'engine': engine.name,
    'connectMode': connectMode.name,
    'sshHostId': sshHostId,
    'host': host,
    'port': port,
    'username': username,
    'database': database,
    'colorValue': colorValue,
    'tags': tags,
    'groupId': groupId,
  };

  factory DbConnection.fromMap(Map<dynamic, dynamic> map) => DbConnection(
    id: map['id'] as String,
    name: map['name'] as String,
    engine: DbEngine.values.firstWhere(
      (e) => e.name == map['engine'],
      orElse: () => DbEngine.mysql,
    ),
    connectMode: DbConnectMode.values.firstWhere(
      (e) => e.name == map['connectMode'],
      orElse: () => DbConnectMode.tunnel,
    ),
    sshHostId: map['sshHostId'] as String?,
    host: map['host'] as String,
    port: map['port'] as int,
    username: map['username'] as String,
    database: map['database'] as String?,
    colorValue: map['colorValue'] as int,
    tags: (map['tags'] as List?)?.cast<String>() ?? const [],
    groupId: map['groupId'] as String?,
  );

  /// Whether [query] matches this connection's name, host, username or any
  /// tag (case-insensitive). Used by the Database tab's search box.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        host.toLowerCase().contains(q) ||
        username.toLowerCase().contains(q) ||
        tags.any((t) => t.toLowerCase().contains(q));
  }
}
