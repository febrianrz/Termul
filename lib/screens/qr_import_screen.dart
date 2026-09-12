import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/host_repository.dart';
import '../l10n/app_strings.dart';
import '../models/ssh_host.dart';
import 'host_edit_screen.dart';

/// One host carried inside a `termul_sync_batch` QR payload, alongside its
/// private key (kept separate from [SshHost] since the key is never stored
/// on the model itself - see [HostRepository]).
class _ScannedHost {
  final SshHost host;
  final String privateKey;

  _ScannedHost(this.host, this.privateKey);
}

/// Scans QR codes produced by the `termul` shell agent (see `agent/`).
///
/// The agent packs as many hosts as fit into each QR code (a `hosts` array
/// under `termul_sync_batch`), so one scan is usually all it takes for a
/// handful of hosts - this just confirms the batch and saves it directly.
/// A lone host from an older agent version (`termul_sync`) still opens the
/// usual add-host form for review instead, since there's nothing to batch.
class QrImportScreen extends StatefulWidget {
  const QrImportScreen({super.key});

  @override
  State<QrImportScreen> createState() => _QrImportScreenState();
}

class _QrImportScreenState extends State<QrImportScreen> {
  final AppStrings _s = AppStrings();
  bool _busy = false;

  SshHost _hostFrom(Map<String, dynamic> data) => SshHost(
    id: const Uuid().v4(),
    name: (data['name'] as String?) ?? '',
    address: (data['address'] as String?) ?? '',
    port: (data['port'] as num?)?.toInt() ?? 22,
    username: (data['username'] as String?) ?? '',
    authType: SshAuthType.privateKey,
  );

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || capture.barcodes.isEmpty) return;

    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic>) return;
      data = decoded;
    } catch (_) {
      return;
    }

    if (data['termul_sync_batch'] != null) {
      await _handleBatch(data);
    } else if (data['termul_sync'] != null) {
      await _handleSingle(data);
    }
  }

  Future<void> _handleBatch(Map<String, dynamic> data) async {
    final rawHosts = data['hosts'];
    if (rawHosts is! List || rawHosts.isEmpty) return;

    final scanned = <_ScannedHost>[];
    for (final entry in rawHosts) {
      if (entry is! Map<String, dynamic>) continue;
      final privateKey = entry['privateKey'] as String?;
      if (privateKey == null || privateKey.isEmpty) continue;
      scanned.add(_ScannedHost(_hostFrom(entry), privateKey));
    }
    if (scanned.isEmpty) return;

    setState(() => _busy = true);
    final confirmed = await _confirmBatchImport(scanned);
    if (confirmed == true) {
      final repo = context.read<HostRepository>();
      for (final s in scanned) {
        await repo.save(s.host, privateKey: s.privateKey);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_s.hostsImported(scanned.length))),
        );
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool?> _confirmBatchImport(List<_ScannedHost> scanned) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.importHostsQuestion(scanned.length)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: scanned
                .map(
                  (s) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.dns_outlined),
                    title: Text(s.host.name),
                    subtitle: Text(
                      '${s.host.username}@${s.host.address}:${s.host.port}',
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_s.import),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSingle(Map<String, dynamic> data) async {
    final privateKey = data['privateKey'] as String?;
    if (privateKey == null || privateKey.isEmpty) return;

    setState(() => _busy = true);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HostEditScreen(
          prefill: _hostFrom(data),
          prefillPrivateKey: privateKey,
        ),
      ),
    );

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_s.importFromComputer),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_s.done),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: Text(
              _s.qrImportInstructions,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(onDetect: _onDetect),
                if (_busy) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
