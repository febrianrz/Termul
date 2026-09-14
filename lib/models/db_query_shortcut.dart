import 'db_connection.dart';

/// A saved SQL query the user can re-run in any Database workspace tab
/// without retyping it - the DB-side equivalent of [CommandShortcut]
/// (`lib/models/command_shortcut.dart`).
class DbQueryShortcut {
  final String id;
  String name;
  String sql;

  /// Restricts this shortcut to one engine's query tab, or `null` to show
  /// it for every engine.
  DbEngine? engine;

  DbQueryShortcut({
    required this.id,
    required this.name,
    required this.sql,
    this.engine,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'sql': sql,
    'engine': engine?.name,
  };

  factory DbQueryShortcut.fromMap(Map<dynamic, dynamic> map) =>
      DbQueryShortcut(
        id: map['id'] as String,
        name: map['name'] as String,
        sql: map['sql'] as String,
        engine: map['engine'] == null
            ? null
            : DbEngine.values.firstWhere(
                (e) => e.name == map['engine'],
                orElse: () => DbEngine.mysql,
              ),
      );
}
