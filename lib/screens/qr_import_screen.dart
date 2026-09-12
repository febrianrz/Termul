import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../models/ssh_host.dart';
import 'host_edit_screen.dart';

/// Scans QR codes produced by the `termul` shell agent (see `agent/`) and
/// opens each one in [HostEditScreen] for review before saving. Stays open
/// after each import so a batch of hosts can be brought in one after
/// another, matching the agent's "one QR per host, press Enter for the
/// next" flow.
class QrImportScreen extends StatefulWidget {
  const QrImportScreen({super.key});

  @override
  State<QrImportScreen> createState() => _QrImportScreenState();
}

class _QrImportScreenState extends State<QrImportScreen> {
  bool _busy = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || capture.barcodes.isEmpty) return;

    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> || decoded['termul_sync'] == null) {
        return;
      }
      data = decoded;
    } catch (_) {
      return;
    }

    final privateKey = data['privateKey'] as String?;
    if (privateKey == null || privateKey.isEmpty) return;

    setState(() => _busy = true);

    final prefill = SshHost(
      id: const Uuid().v4(),
      name: (data['name'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      port: (data['port'] as num?)?.toInt() ?? 22,
      username: (data['username'] as String?) ?? '',
      authType: SshAuthType.privateKey,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            HostEditScreen(prefill: prefill, prefillPrivateKey: privateKey),
      ),
    );

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import dari Mac'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Selesai'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: const Text(
              'Jalankan "termul" di Mac (lihat agent/README.md), lalu scan '
              'QR yang muncul satu per satu.',
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
