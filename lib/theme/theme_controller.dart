import 'package:flutter/foundation.dart';

import '../data/settings_repository.dart';
import 'theme_preset.dart';

/// Holds the currently-selected [ThemePreset] and persists changes via
/// [SettingsRepository], so app chrome and the terminal palette re-theme
/// together whenever the user picks a different preset in Settings.
class ThemeController extends ChangeNotifier {
  ThemeController(this._repo) : presetId = _repo.getThemePreset();

  final SettingsRepository _repo;
  ThemePresetId presetId;

  ThemePreset get preset => ThemePreset.byId(presetId);

  Future<void> setPreset(ThemePresetId id) async {
    if (id == presetId) return;
    presetId = id;
    notifyListeners();
    await _repo.setThemePreset(id);
  }
}
