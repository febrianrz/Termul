import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/host_repository.dart';
import '../l10n/app_strings.dart';
import '../models/host_group.dart';
import '../models/ssh_host.dart';
import 'qr_scan_screen.dart';

class HostEditScreen extends StatefulWidget {
  final SshHost? host;

  /// Metadata to pre-fill when adding a new host (e.g. from a QR import),
  /// as opposed to [host], which puts the form in "edit" mode.
  final SshHost? prefill;
  final String? prefillPrivateKey;

  const HostEditScreen({
    super.key,
    this.host,
    this.prefill,
    this.prefillPrivateKey,
  });

  @override
  State<HostEditScreen> createState() => _HostEditScreenState();
}

class _HostEditScreenState extends State<HostEditScreen> {
  final AppStrings _s = AppStrings();
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(
    text: widget.host?.name ?? widget.prefill?.name,
  );
  late final _addressController = TextEditingController(
    text: widget.host?.address ?? widget.prefill?.address,
  );
  late final _portController = TextEditingController(
    text: (widget.host?.port ?? widget.prefill?.port ?? 22).toString(),
  );
  late final _usernameController = TextEditingController(
    text: widget.host?.username ?? widget.prefill?.username,
  );
  final _passwordController = TextEditingController();
  late final _privateKeyController = TextEditingController(
    text: widget.prefillPrivateKey,
  );
  final _passphraseController = TextEditingController();
  late final _tagsController = TextEditingController(
    text: (widget.host?.tags ?? const <String>[]).join(', '),
  );

  late SshAuthType _authType =
      widget.host?.authType ??
      (widget.prefill != null ? SshAuthType.privateKey : SshAuthType.password);
  late String? _groupId = widget.host?.groupId;
  late List<HostGroup> _groups;
  bool _saving = false;

  bool get _isEditing => widget.host != null;

  @override
  void initState() {
    super.initState();
    _groups = context.read<HostRepository>().getAllGroups();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
    _tagsController.dispose();
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
      groupId: _groupId,
      tags: _parseTags(),
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

  List<String> _parseTags() => _tagsController.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _scanQrInto(TextEditingController controller) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => controller.text = result);
    }
  }

  Future<void> _addGroup() async {
    final repo = context.read<HostRepository>();
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.newGroup),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: _s.groupName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(_s.save),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final group = HostGroup(id: const Uuid().v4(), name: name);
    await repo.saveGroup(group);
    if (!mounted) return;
    setState(() {
      _groups = [..._groups, group];
      _groupId = group.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? _s.editHost : _s.addHostTitle),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: _s.shortcutName),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? _s.requiredField : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: _s.hostAddressLabel,
                hintText: _s.hostAddressHint,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? _s.requiredField : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _portController,
              decoration: InputDecoration(labelText: _s.port),
              keyboardType: TextInputType.number,
              validator: (v) {
                final port = int.tryParse(v?.trim() ?? '');
                if (port == null || port <= 0 || port > 65535) {
                  return _s.invalidPort;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: _s.username),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? _s.requiredField : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _groupId,
                    decoration: InputDecoration(
                      labelText: _s.groupOptional,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        child: Text(_s.ungrouped),
                      ),
                      ..._groups.map(
                        (g) => DropdownMenuItem<String?>(
                          value: g.id,
                          child: Text(g.name),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _groupId = value),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.create_new_folder_outlined),
                  tooltip: _s.newGroupTooltip,
                  onPressed: _addGroup,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: _s.tagsOptional,
                hintText: _s.tagsHint,
              ),
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
                  labelText: _s.password,
                  hintText: _isEditing ? _s.leaveBlankToKeep : null,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: _s.scanQr,
                    onPressed: () => _scanQrInto(_passwordController),
                  ),
                ),
                obscureText: true,
              )
            else ...[
              TextFormField(
                controller: _privateKeyController,
                decoration: InputDecoration(
                  labelText: _s.privateKeyLabel,
                  hintText: _isEditing
                      ? _s.leaveBlankToKeep
                      : '-----BEGIN OPENSSH PRIVATE KEY-----',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: _s.scanQr,
                    onPressed: () => _scanQrInto(_privateKeyController),
                  ),
                ),
                maxLines: 6,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passphraseController,
                decoration: InputDecoration(
                  labelText: _s.passphraseOptional,
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
                  : Text(_s.save),
            ),
          ],
        ),
      ),
    );
  }
}
