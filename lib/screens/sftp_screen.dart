import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/host_repository.dart';
import '../models/ssh_host.dart';
import '../session/sftp_session.dart';

/// Browses [host] over SFTP: navigate directories, upload/download files,
/// create folders, rename and delete entries. Connects independently of
/// any terminal session for that host.
class SftpScreen extends StatefulWidget {
  final SshHost host;

  const SftpScreen({super.key, required this.host});

  @override
  State<SftpScreen> createState() => _SftpScreenState();
}

class _SftpScreenState extends State<SftpScreen> {
  late final SftpSession _session;

  @override
  void initState() {
    super.initState();
    _session = SftpSession(widget.host);
    _session.connect(context.read<HostRepository>());
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  Future<void> _mkdir() async {
    final name = await _promptName(title: 'Folder Baru', label: 'Nama folder');
    if (name == null || name.isEmpty) return;
    try {
      await _session.mkdir(name);
    } catch (e) {
      _showError('Gagal membuat folder: $e');
    }
  }

  Future<void> _rename(SftpName entry) async {
    final name = await _promptName(
      title: 'Rename',
      label: 'Nama baru',
      initialValue: entry.filename,
    );
    if (name == null || name.isEmpty || name == entry.filename) return;
    try {
      await _session.rename(entry, name);
    } catch (e) {
      _showError('Gagal rename: $e');
    }
  }

  Future<void> _delete(SftpName entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus?'),
        content: Text('"${entry.filename}" akan dihapus.'),
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
    try {
      await _session.delete(entry);
    } catch (e) {
      _showError('Gagal menghapus: $e');
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.pickFiles();
    final picked = result?.files.single;
    if (picked?.path == null) return;

    final localFile = File(picked!.path!);
    final totalBytes = await localFile.length();

    try {
      await _runWithProgress(
        label: 'Mengunggah ${picked.name}',
        totalBytes: totalBytes,
        task: (onProgress) =>
            _session.upload(localFile, picked.name, onProgress: onProgress),
      );
    } catch (e) {
      _showError('Gagal mengunggah: $e');
    }
  }

  Future<void> _download(SftpName entry) async {
    try {
      final dir = await _downloadDirectory();
      final localFile = File('${dir.path}/${entry.filename}');

      await _runWithProgress(
        label: 'Mengunduh ${entry.filename}',
        totalBytes: entry.attr.size,
        task: (onProgress) =>
            _session.download(entry, localFile, onProgress: onProgress),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tersimpan di ${localFile.path}')),
      );
    } catch (e) {
      _showError('Gagal mengunduh: $e');
    }
  }

  Future<Directory> _downloadDirectory() async {
    Directory? base;
    if (Platform.isAndroid) {
      base = await getExternalStorageDirectory();
    }
    base ??= await getApplicationDocumentsDirectory();

    final dir = Directory('${base.path}/Termul');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String?> _promptName({
    required String title,
    required String label,
    String? initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _runWithProgress({
    required String label,
    required int? totalBytes,
    required Future<void> Function(void Function(int bytes) onProgress) task,
  }) async {
    final progress = ValueNotifier<int>(0);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (context, bytes, _) {
            final ratio = (totalBytes != null && totalBytes > 0)
                ? (bytes / totalBytes).clamp(0.0, 1.0).toDouble()
                : null;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: ratio),
                const SizedBox(height: 12),
                Text(
                  totalBytes != null
                      ? '${humanFileSize(bytes)} / ${humanFileSize(totalBytes)}'
                      : humanFileSize(bytes),
                ),
              ],
            );
          },
        ),
      ),
    );

    try {
      await task((bytes) => progress.value = bytes);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _session.state == SftpConnectionState.connected
                  ? _session.path
                  : widget.host.name,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (_session.state == SftpConnectionState.connected) ...[
                IconButton(
                  icon: const Icon(Icons.drive_folder_upload_outlined),
                  tooltip: 'Naik satu folder',
                  onPressed: _session.canGoUp ? _session.goUp : null,
                ),
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined),
                  tooltip: 'Folder baru',
                  onPressed: _mkdir,
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file_outlined),
                  tooltip: 'Upload',
                  onPressed: _upload,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Muat ulang',
                  onPressed: _session.refresh,
                ),
              ],
            ],
          ),
          body: _buildBody(),
        );
      },
    );
  }

  Widget _buildBody() {
    switch (_session.state) {
      case SftpConnectionState.connecting:
        return const Center(child: CircularProgressIndicator());
      case SftpConnectionState.failed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Gagal konek SFTP: ${_session.errorMessage ?? 'unknown error'}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      _session.connect(context.read<HostRepository>()),
                  child: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        );
      case SftpConnectionState.connected:
        if (_session.entries.isEmpty) {
          return const Center(child: Text('Folder kosong'));
        }
        return ListView.separated(
          itemCount: _session.entries.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) => _entryTile(_session.entries[index]),
        );
    }
  }

  Widget _entryTile(SftpName entry) {
    final isDir = entry.attr.isDirectory;
    return ListTile(
      leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file_outlined),
      title: Text(entry.filename),
      subtitle: isDir
          ? null
          : Text(
              '${humanFileSize(entry.attr.size ?? 0)} · ${formatMtime(entry.attr.modifyTime)}',
            ),
      onTap: isDir ? () => _session.open(entry) : () => _download(entry),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'download') _download(entry);
          if (value == 'rename') _rename(entry);
          if (value == 'delete') _delete(entry);
        },
        itemBuilder: (context) => [
          if (!isDir)
            const PopupMenuItem(value: 'download', child: Text('Download')),
          const PopupMenuItem(value: 'rename', child: Text('Rename')),
          const PopupMenuItem(value: 'delete', child: Text('Hapus')),
        ],
      ),
    );
  }
}

String humanFileSize(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  return unitIndex == 0
      ? '${size.toInt()} ${units[unitIndex]}'
      : '${size.toStringAsFixed(1)} ${units[unitIndex]}';
}

String formatMtime(int? unixSeconds) {
  if (unixSeconds == null) return '-';
  final d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
