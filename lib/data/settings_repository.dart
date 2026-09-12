import 'package:hive_ce/hive.dart';

import '../theme/theme_preset.dart';

/// Small app-wide preferences (currently just the chosen theme) in their
/// own local Hive box, separate from [HostRepository]'s host/group data.
class SettingsRepository {
  static const _boxName = 'app_settings';
  static const _themePresetKey = 'theme_preset';
  static const _biometricLockKey = 'biometric_lock_enabled';

  late final Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  ThemePresetId getThemePreset() {
    final name = _box.get(_themePresetKey) as String?;
    return ThemePresetId.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ThemePresetId.termul,
    );
  }

  Future<void> setThemePreset(ThemePresetId id) async {
    await _box.put(_themePresetKey, id.name);
  }

  bool getBiometricLockEnabled() =>
      _box.get(_biometricLockKey, defaultValue: false) as bool;

  Future<void> setBiometricLockEnabled(bool enabled) async {
    await _box.put(_biometricLockKey, enabled);
  }
}
