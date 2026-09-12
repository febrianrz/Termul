import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

/// Identifies a [ThemePreset] persisted in settings. The enum's field
/// (rather than the preset object itself) is what's stored, so presets can
/// be tweaked freely without invalidating a saved choice.
enum ThemePresetId { termul, dracula, solarizedDark, nord, monokai }

/// A named pairing of the app's accent color (seeds the Material
/// [ColorScheme]) and the terminal's own ANSI color palette, so picking one
/// preset re-themes both the app chrome and the terminal at once.
class ThemePreset {
  final ThemePresetId id;
  final String label;
  final Color seedColor;
  final TerminalTheme terminalTheme;

  const ThemePreset({
    required this.id,
    required this.label,
    required this.seedColor,
    required this.terminalTheme,
  });

  static const termul = ThemePreset(
    id: ThemePresetId.termul,
    label: 'Termul (Default)',
    seedColor: Color(0xFF00C896),
    terminalTheme: TerminalThemes.defaultTheme,
  );

  static const dracula = ThemePreset(
    id: ThemePresetId.dracula,
    label: 'Dracula',
    seedColor: Color(0xFFBD93F9),
    terminalTheme: TerminalTheme(
      cursor: Color(0xFFF8F8F2),
      selection: Color(0xFF44475A),
      foreground: Color(0xFFF8F8F2),
      background: Color(0xFF282A36),
      black: Color(0xFF21222C),
      red: Color(0xFFFF5555),
      green: Color(0xFF50FA7B),
      yellow: Color(0xFFF1FA8C),
      blue: Color(0xFFBD93F9),
      magenta: Color(0xFFFF79C6),
      cyan: Color(0xFF8BE9FD),
      white: Color(0xFFF8F8F2),
      brightBlack: Color(0xFF6272A4),
      brightRed: Color(0xFFFF6E6E),
      brightGreen: Color(0xFF69FF94),
      brightYellow: Color(0xFFFFFFA5),
      brightBlue: Color(0xFFD6ACFF),
      brightMagenta: Color(0xFFFF92DF),
      brightCyan: Color(0xFFA4FFFF),
      brightWhite: Color(0xFFFFFFFF),
      searchHitBackground: Color(0xFFFFFF2B),
      searchHitBackgroundCurrent: Color(0xFF31FF26),
      searchHitForeground: Color(0xFF000000),
    ),
  );

  static const solarizedDark = ThemePreset(
    id: ThemePresetId.solarizedDark,
    label: 'Solarized Dark',
    seedColor: Color(0xFF268BD2),
    terminalTheme: TerminalTheme(
      cursor: Color(0xFF839496),
      selection: Color(0xFF073642),
      foreground: Color(0xFF839496),
      background: Color(0xFF002B36),
      black: Color(0xFF073642),
      red: Color(0xFFDC322F),
      green: Color(0xFF859900),
      yellow: Color(0xFFB58900),
      blue: Color(0xFF268BD2),
      magenta: Color(0xFFD33682),
      cyan: Color(0xFF2AA198),
      white: Color(0xFFEEE8D5),
      brightBlack: Color(0xFF002B36),
      brightRed: Color(0xFFCB4B16),
      brightGreen: Color(0xFF586E75),
      brightYellow: Color(0xFF657B83),
      brightBlue: Color(0xFF839496),
      brightMagenta: Color(0xFF6C71C4),
      brightCyan: Color(0xFF93A1A1),
      brightWhite: Color(0xFFFDF6E3),
      searchHitBackground: Color(0xFFFFFF2B),
      searchHitBackgroundCurrent: Color(0xFF31FF26),
      searchHitForeground: Color(0xFF000000),
    ),
  );

  static const nord = ThemePreset(
    id: ThemePresetId.nord,
    label: 'Nord',
    seedColor: Color(0xFF81A1C1),
    terminalTheme: TerminalTheme(
      cursor: Color(0xFFD8DEE9),
      selection: Color(0xFF434C5E),
      foreground: Color(0xFFD8DEE9),
      background: Color(0xFF2E3440),
      black: Color(0xFF3B4252),
      red: Color(0xFFBF616A),
      green: Color(0xFFA3BE8C),
      yellow: Color(0xFFEBCB8B),
      blue: Color(0xFF81A1C1),
      magenta: Color(0xFFB48EAD),
      cyan: Color(0xFF88C0D0),
      white: Color(0xFFE5E9F0),
      brightBlack: Color(0xFF4C566A),
      brightRed: Color(0xFFBF616A),
      brightGreen: Color(0xFFA3BE8C),
      brightYellow: Color(0xFFEBCB8B),
      brightBlue: Color(0xFF81A1C1),
      brightMagenta: Color(0xFFB48EAD),
      brightCyan: Color(0xFF8FBCBB),
      brightWhite: Color(0xFFECEFF4),
      searchHitBackground: Color(0xFFFFFF2B),
      searchHitBackgroundCurrent: Color(0xFF31FF26),
      searchHitForeground: Color(0xFF000000),
    ),
  );

  static const monokai = ThemePreset(
    id: ThemePresetId.monokai,
    label: 'Monokai',
    seedColor: Color(0xFFA6E22E),
    terminalTheme: TerminalTheme(
      cursor: Color(0xFFF8F8F0),
      selection: Color(0xFF49483E),
      foreground: Color(0xFFF8F8F2),
      background: Color(0xFF272822),
      black: Color(0xFF272822),
      red: Color(0xFFF92672),
      green: Color(0xFFA6E22E),
      yellow: Color(0xFFF4BF75),
      blue: Color(0xFF66D9EF),
      magenta: Color(0xFFAE81FF),
      cyan: Color(0xFFA1EFE4),
      white: Color(0xFFF8F8F2),
      brightBlack: Color(0xFF75715E),
      brightRed: Color(0xFFF92672),
      brightGreen: Color(0xFFA6E22E),
      brightYellow: Color(0xFFF4BF75),
      brightBlue: Color(0xFF66D9EF),
      brightMagenta: Color(0xFFAE81FF),
      brightCyan: Color(0xFFA1EFE4),
      brightWhite: Color(0xFFF9F8F5),
      searchHitBackground: Color(0xFFFFFF2B),
      searchHitBackgroundCurrent: Color(0xFF31FF26),
      searchHitForeground: Color(0xFF000000),
    ),
  );

  static const List<ThemePreset> values = [
    termul,
    dracula,
    solarizedDark,
    nord,
    monokai,
  ];

  static ThemePreset byId(ThemePresetId id) =>
      values.firstWhere((p) => p.id == id, orElse: () => termul);
}
