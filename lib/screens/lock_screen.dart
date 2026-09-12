import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/app_lock_controller.dart';
import '../l10n/app_strings.dart';

/// Shown in place of [HostListScreen] whenever [AppLockController.locked]
/// is true. Prompts for biometrics/PIN automatically on first build, with a
/// manual retry button for when the user dismisses the system prompt.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _authenticating = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() {
      _authenticating = true;
      _failed = false;
    });
    final ok = await context.read<AppLockController>().tryUnlock();
    if (mounted) {
      setState(() {
        _authenticating = false;
        _failed = !ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 16),
              Text(s.appLocked, style: const TextStyle(fontSize: 18)),
              if (_failed) ...[
                const SizedBox(height: 8),
                Text(
                  s.verificationFailed,
                  style: const TextStyle(color: Colors.orange),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _authenticating ? null : _unlock,
                icon: const Icon(Icons.fingerprint),
                label: Text(_authenticating ? s.verifying : s.open),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
