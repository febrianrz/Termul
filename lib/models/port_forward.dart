enum PortForwardType { local, remote }

/// A saved SSH tunnel configuration for one host.
///
/// [PortForwardType.local] mirrors `ssh -L bindPort:targetHost:targetPort`:
/// a local port on this device is forwarded, through the SSH connection, to
/// `targetHost:targetPort` as seen from the remote server.
///
/// [PortForwardType.remote] mirrors `ssh -R bindPort:targetHost:targetPort`:
/// a port on the remote server is forwarded back to `targetHost:targetPort`
/// as seen from this device (or any host this device can reach).
class PortForward {
  final String id;
  final String hostId;
  String name;
  PortForwardType type;
  int bindPort;
  String targetHost;
  int targetPort;

  PortForward({
    required this.id,
    required this.hostId,
    required this.name,
    required this.type,
    required this.bindPort,
    required this.targetHost,
    required this.targetPort,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'hostId': hostId,
    'name': name,
    'type': type.name,
    'bindPort': bindPort,
    'targetHost': targetHost,
    'targetPort': targetPort,
  };

  factory PortForward.fromMap(Map<dynamic, dynamic> map) => PortForward(
    id: map['id'] as String,
    hostId: map['hostId'] as String,
    name: map['name'] as String,
    type: PortForwardType.values.firstWhere(
      (e) => e.name == map['type'],
      orElse: () => PortForwardType.local,
    ),
    bindPort: map['bindPort'] as int,
    targetHost: map['targetHost'] as String,
    targetPort: map['targetPort'] as int,
  );
}
