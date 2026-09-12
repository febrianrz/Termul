import 'dart:convert';

import 'package:http/http.dart' as http;

/// Info about the latest published build, parsed from the GitHub release
/// that `build-apk.yml` keeps updated at the "latest" tag.
class UpdateInfo {
  final int buildNumber;
  final String releaseUrl;

  UpdateInfo({required this.buildNumber, required this.releaseUrl});
}

/// Checks GitHub Releases for a newer build than the one currently
/// installed. The repo publishes every push to `main` as a single,
/// continuously-replaced "latest" release (see
/// `.github/workflows/build-apk.yml`), whose body embeds the CI run number
/// as "(build N)" - that's what gets compared against the installed app's
/// own build number.
class UpdateChecker {
  UpdateChecker._();

  static const _repo = 'febrianrz/Termul';
  static final _buildNumberPattern = RegExp(r'build (\d+)');

  /// Returns info about the latest published build, or null if none is
  /// available - offline, rate-limited, or the release has no parseable
  /// build number (e.g. a fork that hasn't set up the same workflow).
  static Future<UpdateInfo?> fetchLatest() async {
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final match = _buildNumberPattern.firstMatch(
      json['body'] as String? ?? '',
    );
    if (match == null) return null;

    return UpdateInfo(
      buildNumber: int.parse(match.group(1)!),
      releaseUrl:
          json['html_url'] as String? ??
          'https://github.com/$_repo/releases/latest',
    );
  }
}
