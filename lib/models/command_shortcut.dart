/// A saved command the user can re-send into any terminal session without
/// retyping it (e.g. `docker ps`, `sudo systemctl restart nginx`).
class CommandShortcut {
  final String id;
  String name;
  String command;

  CommandShortcut({
    required this.id,
    required this.name,
    required this.command,
  });

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'command': command};

  factory CommandShortcut.fromMap(Map<dynamic, dynamic> map) =>
      CommandShortcut(
        id: map['id'] as String,
        name: map['name'] as String,
        command: map['command'] as String,
      );
}
