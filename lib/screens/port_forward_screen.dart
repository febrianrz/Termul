import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../data/host_repository.dart';
import '../l10n/app_strings.dart';
import '../models/port_forward.dart';
import '../models/ssh_host.dart';
import '../session/session_manager.dart';
import '../session/terminal_session.dart';

/// Manages SSH tunnels (local/remote port forwards) for [host]. Tunnels run
/// through the same [TerminalSession] as the host's terminal - opening this
/// screen connects (or reuses) that session so a forward can be toggled on
/// even before the terminal itself has been opened.
class PortForwardScreen extends StatefulWidget {
  final SshHost host;

  const PortForwardScreen({super.key, required this.host});

  @override
  State<PortForwardScreen> createState() => _PortForwardScreenState();
}

class _PortForwardScreenState extends State<PortForwardScreen> {
  final AppStrings _s = AppStrings();
  late final TerminalSession _session;
  late List<PortForward> _forwards;

  @override
  void initState() {
    super.initState();
    _session = context.read<SessionManager>().open(
      widget.host,
      context.read<HostRepository>(),
    );
    _reload();
  }

  void _reload() {
    setState(() {
      _forwards = context.read<HostRepository>().getForwardsForHost(
        widget.host.id,
      );
    });
  }

  Future<void> _toggle(PortForward forward, bool enable) async {
    if (enable) {
      await _session.startForward(forward);
    } else {
      await _session.stopForward(forward.id);
    }
  }

  Future<void> _addOrEdit({PortForward? forward}) async {
    final result = await showDialog<PortForward>(
      context: context,
      builder: (context) => _PortForwardDialog(
        hostId: widget.host.id,
        forward: forward,
      ),
    );
    if (result == null) return;
    await context.read<HostRepository>().saveForward(result);
    if (mounted) _reload();
  }

  Future<void> _delete(PortForward forward) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_s.deleteTunnelTitle),
        content: Text(_s.deleteTunnelBody(forward.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _session.stopForward(forward.id);
    await context.read<HostRepository>().deleteForward(forward.id);
    if (mounted) _reload();
  }

  String _subtitle(PortForward forward) {
    final arrow = forward.type == PortForwardType.local ? '→' : '←';
    final label = forward.type == PortForwardType.local ? _s.local : _s.remote;
    return '$label · ${forward.bindPort} $arrow ${forward.targetHost}:${forward.targetPort}';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        final connected = _session.state == TerminalConnectionState.connected;
        return Scaffold(
          appBar: AppBar(title: Text(_s.portForwardTitle(widget.host.name))),
          body: Column(
            children: [
              if (!connected)
                Container(
                  width: double.infinity,
                  color: Colors.orange.shade800,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    _s.sessionNotConnectedNotice,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              Expanded(
                child: _forwards.isEmpty
                    ? Center(child: Text(_s.noTunnelsYet))
                    : ListView.separated(
                        itemCount: _forwards.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final forward = _forwards[index];
                          final active = _session.activeForwardIds.contains(
                            forward.id,
                          );
                          final error = _session.forwardError(forward.id);
                          return ListTile(
                            leading: Icon(
                              forward.type == PortForwardType.local
                                  ? Icons.call_made
                                  : Icons.call_received,
                            ),
                            title: Text(forward.name),
                            subtitle: Text(
                              error ?? _subtitle(forward),
                              style: error == null
                                  ? null
                                  : const TextStyle(color: Colors.redAccent),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onLongPress: () => _addOrEdit(forward: forward),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: active,
                                  onChanged: (value) =>
                                      _toggle(forward, value),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _addOrEdit(forward: forward);
                                    }
                                    if (value == 'delete') _delete(forward);
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text(_s.edit),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(_s.delete),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _addOrEdit(),
            tooltip: _s.addTunnelTooltip,
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class _PortForwardDialog extends StatefulWidget {
  final String hostId;
  final PortForward? forward;

  const _PortForwardDialog({required this.hostId, this.forward});

  @override
  State<_PortForwardDialog> createState() => _PortForwardDialogState();
}

class _PortForwardDialogState extends State<_PortForwardDialog> {
  final AppStrings _s = AppStrings();
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.forward?.name,
  );
  late final _bindPortController = TextEditingController(
    text: widget.forward?.bindPort.toString(),
  );
  late final _targetHostController = TextEditingController(
    text: widget.forward?.targetHost ?? 'localhost',
  );
  late final _targetPortController = TextEditingController(
    text: widget.forward?.targetPort.toString(),
  );
  late PortForwardType _type = widget.forward?.type ?? PortForwardType.local;

  @override
  void dispose() {
    _nameController.dispose();
    _bindPortController.dispose();
    _targetHostController.dispose();
    _targetPortController.dispose();
    super.dispose();
  }

  String? _validatePort(String? v) {
    final port = int.tryParse(v?.trim() ?? '');
    if (port == null || port <= 0 || port > 65535) return _s.invalidPort;
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      PortForward(
        id: widget.forward?.id ?? const Uuid().v4(),
        hostId: widget.hostId,
        name: _nameController.text.trim(),
        type: _type,
        bindPort: int.parse(_bindPortController.text.trim()),
        targetHost: _targetHostController.text.trim(),
        targetPort: int.parse(_targetPortController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.forward == null ? _s.newTunnel : _s.editTunnel),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(labelText: _s.shortcutName),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? _s.requiredField : null,
              ),
              const SizedBox(height: 12),
              SegmentedButton<PortForwardType>(
                segments: [
                  ButtonSegment(
                    value: PortForwardType.local,
                    label: Text(_s.local),
                    icon: const Icon(Icons.call_made),
                  ),
                  ButtonSegment(
                    value: PortForwardType.remote,
                    label: Text(_s.remote),
                    icon: const Icon(Icons.call_received),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bindPortController,
                decoration: InputDecoration(
                  labelText: _type == PortForwardType.local
                      ? _s.localPortHint
                      : _s.remotePortHint,
                ),
                keyboardType: TextInputType.number,
                validator: _validatePort,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetHostController,
                decoration: InputDecoration(
                  labelText: _s.targetHost,
                  hintText: _s.targetHostHint,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? _s.requiredField : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetPortController,
                decoration: InputDecoration(labelText: _s.targetPort),
                keyboardType: TextInputType.number,
                validator: _validatePort,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_s.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(_s.save)),
      ],
    );
  }
}
