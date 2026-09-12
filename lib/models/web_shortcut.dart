import 'dart:typed_data';

/// A saved link to a web dashboard/tool (Portainer, Dokploy, GitHub, ...)
/// shown as a launcher-style icon grid. [favicon] is fetched once from the
/// target site itself (see `FaviconFetcher`) and cached here so opening the
/// grid never needs network access.
class WebShortcut {
  final String id;
  String name;
  String url;
  bool favorite;
  Uint8List? favicon;

  WebShortcut({
    required this.id,
    required this.name,
    required this.url,
    this.favorite = false,
    this.favicon,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'url': url,
    'favorite': favorite,
    'favicon': favicon,
  };

  factory WebShortcut.fromMap(Map<dynamic, dynamic> map) => WebShortcut(
    id: map['id'] as String,
    name: map['name'] as String,
    url: map['url'] as String,
    favorite: map['favorite'] as bool? ?? false,
    favicon: map['favicon'] as Uint8List?,
  );

  /// Whether [query] matches this shortcut's name or URL (case-insensitive).
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) || url.toLowerCase().contains(q);
  }
}
