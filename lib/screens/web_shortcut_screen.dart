import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../data/host_repository.dart';
import '../models/web_shortcut.dart';
import '../services/favicon_fetcher.dart';

/// Launcher-style grid of saved web links (dashboards, admin panels, ...) -
/// tap an icon to open it, instead of typing/remembering the URL.
class WebShortcutScreen extends StatefulWidget {
  const WebShortcutScreen({super.key});

  @override
  State<WebShortcutScreen> createState() => _WebShortcutScreenState();
}

class _WebShortcutScreenState extends State<WebShortcutScreen> {
  late List<WebShortcut> _shortcuts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _shortcuts = context.read<HostRepository>().getAllWebShortcuts();
    });
  }

  Future<void> _addOrEdit({WebShortcut? shortcut}) async {
    final repo = context.read<HostRepository>();
    final nameController = TextEditingController(text: shortcut?.name);
    final urlController = TextEditingController(text: shortcut?.url);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(shortcut == null ? 'Tambah Shortcut' : 'Edit Shortcut'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'portainer.local:9000',
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final name = nameController.text.trim();
    var url = urlController.text.trim();
    if (name.isEmpty || url.isEmpty) return;
    if (!url.contains('://')) url = 'https://$url';

    final result = WebShortcut(
      id: shortcut?.id ?? const Uuid().v4(),
      name: name,
      url: url,
      favorite: shortcut?.favorite ?? false,
      favicon: shortcut?.url == url ? shortcut?.favicon : null,
    );

    // Save right away so the grid updates instantly; the favicon (which
    // needs a network round trip) fills in a moment later without making
    // the user wait for it up front.
    await repo.saveWebShortcut(result);
    if (mounted) _reload();

    if (result.favicon == null) {
      final favicon = await FaviconFetcher.fetch(url);
      if (favicon != null) {
        result.favicon = favicon;
        await repo.saveWebShortcut(result);
        if (mounted) _reload();
      }
    }
  }

  Future<void> _delete(WebShortcut shortcut) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus?'),
        content: Text('Shortcut "${shortcut.name}" akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await context.read<HostRepository>().deleteWebShortcut(shortcut.id);
    _reload();
  }

  Future<void> _toggleFavorite(WebShortcut shortcut) async {
    shortcut.favorite = !shortcut.favorite;
    await context.read<HostRepository>().saveWebShortcut(shortcut);
    _reload();
  }

  Future<void> _open(WebShortcut shortcut) async {
    final uri = Uri.tryParse(shortcut.url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _grid(List<WebShortcut> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 96,
        mainAxisSpacing: 12,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final shortcut = items[index];
        return _ShortcutTile(
          shortcut: shortcut,
          onTap: () => _open(shortcut),
          onEdit: () => _addOrEdit(shortcut: shortcut),
          onDelete: () => _delete(shortcut),
          onToggleFavorite: () => _toggleFavorite(shortcut),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _shortcuts.where((s) => s.favorite).toList();
    final others = _shortcuts.where((s) => !s.favorite).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Web Shortcut')),
      body: _shortcuts.isEmpty
          ? const Center(child: Text('Belum ada shortcut'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (favorites.isNotEmpty) ...[
                  _sectionLabel('Favorit'),
                  _grid(favorites),
                  const SizedBox(height: 20),
                ],
                if (others.isNotEmpty) ...[
                  if (favorites.isNotEmpty) _sectionLabel('Semua'),
                  _grid(others),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(),
        tooltip: 'Tambah shortcut',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final WebShortcut shortcut;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const _ShortcutTile({
    required this.shortcut,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  Future<void> _showMenu(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                shortcut.favorite ? Icons.star : Icons.star_border,
              ),
              title: Text(
                shortcut.favorite ? 'Hapus dari favorit' : 'Jadikan favorit',
              ),
              onTap: () => Navigator.of(context).pop('favorite'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Hapus'),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'favorite') onToggleFavorite();
    if (action == 'edit') onEdit();
    if (action == 'delete') onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      onLongPress: () => _showMenu(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _icon(context),
              if (shortcut.favorite)
                const Positioned(
                  right: -2,
                  top: -2,
                  child: Icon(Icons.star, size: 14, color: Colors.amber),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            shortcut.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _icon(BuildContext context) {
    final favicon = shortcut.favicon;
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: favicon != null
          ? Image.memory(
              favicon,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _fallbackIcon(context),
            )
          : _fallbackIcon(context),
    );
  }

  Widget _fallbackIcon(BuildContext context) {
    return Center(
      child: Text(
        shortcut.name.isEmpty ? '?' : shortcut.name[0].toUpperCase(),
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
