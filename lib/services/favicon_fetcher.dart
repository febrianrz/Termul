import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Fetches a site's favicon directly from the site itself - deliberately
/// not via a public favicon API (e.g. Google's), since self-hosted tools
/// like Portainer/Dokploy typically live on a private network/VPN that a
/// public service can't reach.
class FaviconFetcher {
  FaviconFetcher._();

  static final _linkTagPattern = RegExp(r'<link\b[^>]*>', caseSensitive: false);
  static final _relPattern = RegExp(
    r'''rel\s*=\s*["']([^"']*)["']''',
    caseSensitive: false,
  );
  static final _hrefPattern = RegExp(
    r'''href\s*=\s*["']([^"']*)["']''',
    caseSensitive: false,
  );

  /// Returns the favicon's raw bytes, or null if none could be found or
  /// downloaded (network error, no icon declared and no /favicon.ico).
  static Future<Uint8List?> fetch(String rawUrl) async {
    final uri = _normalize(rawUrl);
    if (uri == null) return null;

    try {
      final page = await http
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (page.statusCode == 200) {
        final href = _extractIconHref(page.body);
        if (href != null) {
          final bytes = await _download(uri.resolve(href));
          if (bytes != null) return bytes;
        }
      }
    } catch (_) {
      // Fall through to the /favicon.ico guess below.
    }

    return _download(uri.replace(path: '/favicon.ico', query: ''));
  }

  static Uri? _normalize(String rawUrl) {
    var value = rawUrl.trim();
    if (value.isEmpty) return null;
    if (!value.contains('://')) value = 'https://$value';
    return Uri.tryParse(value);
  }

  /// Finds the first `<link rel="...icon...">` tag's `href`, regardless of
  /// attribute order - a small, targeted regex scan rather than a full HTML
  /// parser, since all we need is one attribute off one tag.
  static String? _extractIconHref(String html) {
    for (final match in _linkTagPattern.allMatches(html)) {
      final tag = match.group(0)!;
      final rel = _relPattern.firstMatch(tag)?.group(1)?.toLowerCase();
      if (rel == null || !rel.contains('icon')) continue;
      final href = _hrefPattern.firstMatch(tag)?.group(1);
      if (href != null && href.isNotEmpty) return href;
    }
    return null;
  }

  static Future<Uint8List?> _download(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {
      // Best-effort only.
    }
    return null;
  }
}
