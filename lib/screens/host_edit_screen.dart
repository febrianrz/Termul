import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/host_repository.dart';
import '../models/ssh_host.dart';

class HostEditScreen extends StatefulWidget {
  final SshHost? host;

  const HostEditScreen({super.key, this.host});

  @override
  State<HostEditScreen> createState() => _HostEditScreenState();
}

class _HostEditScreenState extends State<HostEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(text: widget.host?.name);
  late final _addressController = TextEditingController(
    text: widget.host?.address,
  );
  late final _portController = TextEditingController(
    text: (widget.host?.port ?? 22).toString(),
  );
  late final _usernameController = TextEditingController(
    text: widget.host?.username,
  );
  final _passwordController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _passphraseController = TextEditingController();

  late SshAuthType _authType = widget.host?.authType ?? SshAuthType.password;
  bool _saving = false;

  bool get _isEditing => widget.host != null;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final repo = context.read<HostRepository>();

    final host = SshHost(
      id: widget.host?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 22,
      username: _usernameController.text.trim(),
      authType: _authType,
    );

    await repo.save(
      host,
      password: _authType == SshAuthType.password &&
              _passwordController.text.isNotEmpty
          ? _passwordController.text
          : null,
      privateKey: _authType == SshAuthType.privateKey &&
              _privateKeyController.text.isNotEmpty
          ? _privateKeyController.text
          : null,
      passphrase: _authType == SshAuthType.privateKey &&
              _passphraseController.text.isNotEmpty
          ? _passphraseController.text
          : null,
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Host' : 'Tambah Host')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Host / IP',
                hintText: 'contoh: 192.168.1.10',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final port = int.tryParse(v?.trim() ?? '');
                if (port == null || port <= 0 || port > 65535) {
                  return 'Port tidak valid';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 20),
            SegmentedButton<SshAuthType>(
              segments: const [
                ButtonSegment(
                  value: SshAuthType.password,
                  label: Text('Password'),
                  icon: Icon(Icons.password),
                ),
                ButtonSegment(
                  value: SshAuthType.privateKey,
                  label: Text('Private key'),
                  icon: Icon(Icons.key),
                ),
              ],
              selected: {_authType},
              onSelectionChanged: (s) => setState(() => _authType = s.first),
            ),
            const SizedBox(height: 12),
            if (_authType == SshAuthType.password)
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: _isEditing ? '(kosongkan jika tidak diubah)' : null,
                ),
                obscureText: true,
              )
            else ...[
              TextFormField(
                controller: _privateKeyController,
                decoration: InputDecoration(
                  labelText: 'Private key (PEM)',
                  hintText: _isEditing
                      ? '(kosongkan jika tidak diubah)'
                      : '-----BEGIN OPENSSH PRIVATE KEY-----',
                ),
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passphraseController,
                decoration: const InputDecoration(
                  labelText: 'Passphrase (opsional)',
                ),
                obscureText: true,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
