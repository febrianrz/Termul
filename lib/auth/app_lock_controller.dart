import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

import '../data/settings_repository.dart';

/// Gates the app behind the device's biometric/PIN lock when enabled in
/// Settings. Re-locks whenever the app is backgrounded, so switching away
/// and back always requires unlocking again.
class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  AppLockController(this._repo) : enabled = _repo.getBiometricLockEnabled() {
    _locked = enabled;
    WidgetsBinding.instance.addObserver(this);
  }

  final SettingsRepository _repo;
  final _auth = LocalAuthentication();

  bool enabled;
  bool _locked = false;

  /// Whether the lock screen should currently be shown.
  bool get locked => enabled && _locked;

  Future<void> setEnabled(bool value) async {
    if (value == enabled) return;
    enabled = value;
    // Don't immediately lock the screen the user just enabled this from.
    _locked = false;
    notifyListeners();
    await _repo.setBiometricLockEnabled(value);
  }

  /// Prompts the device's biometric/PIN check. Returns true (and unlocks)
  /// on success. If the device has no biometrics or screen lock configured
  /// at all, unlocking is a no-op success - there's nothing to check
  /// against, so the lock would otherwise strand the user permanently.
  Future<bool> tryUnlock() async {
    try {
      if (!await _auth.isDeviceSupported()) {
        _locked = false;
        notifyListeners();
        return true;
      }
      final ok = await _auth.authenticate(
        localizedReason: 'Buka Termul',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (ok) {
        _locked = false;
        notifyListeners();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (enabled && state == AppLifecycleState.paused) {
      _locked = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
