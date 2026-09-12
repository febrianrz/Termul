import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/update_checker.dart';
import '../theme/theme_controller.dart';
import '../theme/theme_preset.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          const _SectionHeader('Tema'),
          for (final preset in ThemePreset.values)
            RadioListTile<ThemePresetId>(
              value: preset.id,
              groupValue: controller.presetId,
              onChanged: (id) => controller.setPreset(id!),
              title: Text(preset.label),
              secondary: _ThemeSwatch(preset: preset),
            ),
          const Divider(height: 32),
          const _SectionHeader('Tentang'),
          const _AppVersionTile(),
          const _UpdateCheckTile(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// A quick preview of a [ThemePreset]'s terminal palette: background plus a
/// few ANSI colors, as small dots.
class _ThemeSwatch extends StatelessWidget {
  final ThemePreset preset;

  const _ThemeSwatch({required this.preset});

  @override
  Widget build(BuildContext context) {
    final t = preset.terminalTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(t.background),
        _dot(t.red),
        _dot(t.green),
        _dot(t.blue),
      ],
    );
  }

  Widget _dot(Color color) => Container(
    width: 14,
    height: 14,
    margin: const EdgeInsets.only(left: 3),
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white24),
    ),
  );
}

class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Termul'),
          subtitle: Text(
            info == null
                ? 'Memuat versi...'
                : 'Versi ${info.version} (${info.buildNumber})',
          ),
        );
      },
    );
  }
}

/// Manually checks GitHub Releases for a newer build than the one
/// installed - there's no automatic background check, so this is the only
/// way the app can tell the user a new build exists.
class _UpdateCheckTile extends StatefulWidget {
  const _UpdateCheckTile();

  @override
  State<_UpdateCheckTile> createState() => _UpdateCheckTileState();
}

class _UpdateCheckTileState extends State<_UpdateCheckTile> {
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final latest = await UpdateChecker.fetchLatest();

      if (!mounted) return;
      if (latest == null) {
        _showMessage('Tidak bisa mengecek pembaruan. Coba lagi nanti.');
      } else if (latest.buildNumber > currentBuild) {
        _showUpdateDialog(latest);
      } else {
        _showMessage('Sudah versi terbaru (build $currentBuild).');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showUpdateDialog(UpdateInfo info) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update tersedia'),
        content: Text('Build ${info.buildNumber} sudah tersedia di GitHub.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              launchUrl(
                Uri.parse(info.releaseUrl),
                mode: LaunchMode.externalApplication,
              );
            },
            child: const Text('Buka'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.system_update_outlined),
      title: const Text('Cek Pembaruan'),
      trailing: _checking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _checking ? null : _check,
    );
  }
}
