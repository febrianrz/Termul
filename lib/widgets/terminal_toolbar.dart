import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../session/terminal_session.dart';

/// Extra-keys bar shown above the on-screen keyboard while a
/// [TerminalSession] is connected: keys mobile keyboards don't expose
/// directly (Ctrl, Alt, Esc, arrows, Home/End/PgUp/PgDn, Ins/Del) plus a
/// handful of shell symbols that are annoying to reach.
class TerminalToolbar extends StatelessWidget {
  final TerminalSession session;

  const TerminalToolbar({super.key, required this.session});

  static const _symbols = [
    '|',
    '\\',
    '~',
    '/',
    '-',
    ':',
    ';',
    '@',
    r'$',
    '*',
    '!',
    '?',
  ];

  Terminal get _terminal => session.terminal;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          children: [
            _ToolbarKey(
              label: 'Ctrl',
              active: session.ctrlArmed,
              onTap: session.toggleCtrl,
            ),
            _ToolbarKey(
              label: 'Alt',
              active: session.altArmed,
              onTap: session.toggleAlt,
            ),
            _ToolbarKey(
              label: 'Tab',
              onTap: () => _terminal.keyInput(TerminalKey.tab),
            ),
            _ToolbarKey(
              label: 'Esc',
              onTap: () => _terminal.keyInput(TerminalKey.escape),
            ),
            _ToolbarKey(
              icon: Icons.keyboard_arrow_up,
              onTap: () => _terminal.keyInput(TerminalKey.arrowUp),
            ),
            _ToolbarKey(
              icon: Icons.keyboard_arrow_down,
              onTap: () => _terminal.keyInput(TerminalKey.arrowDown),
            ),
            _ToolbarKey(
              icon: Icons.keyboard_arrow_left,
              onTap: () => _terminal.keyInput(TerminalKey.arrowLeft),
            ),
            _ToolbarKey(
              icon: Icons.keyboard_arrow_right,
              onTap: () => _terminal.keyInput(TerminalKey.arrowRight),
            ),
            _ToolbarKey(
              label: 'Home',
              onTap: () => _terminal.keyInput(TerminalKey.home),
            ),
            _ToolbarKey(
              label: 'End',
              onTap: () => _terminal.keyInput(TerminalKey.end),
            ),
            _ToolbarKey(
              label: 'PgUp',
              onTap: () => _terminal.keyInput(TerminalKey.pageUp),
            ),
            _ToolbarKey(
              label: 'PgDn',
              onTap: () => _terminal.keyInput(TerminalKey.pageDown),
            ),
            _ToolbarKey(
              label: 'Ins',
              onTap: () => _terminal.keyInput(TerminalKey.insert),
            ),
            _ToolbarKey(
              label: 'Del',
              onTap: () => _terminal.keyInput(TerminalKey.delete),
            ),
            for (final symbol in _symbols)
              _ToolbarKey(
                label: symbol,
                onTap: () => _terminal.textInput(symbol),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool active;
  final VoidCallback onTap;

  const _ToolbarKey({
    this.label,
    this.icon,
    this.active = false,
    required this.onTap,
  }) : assert(label != null || icon != null);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      child: Material(
        color: active ? colorScheme.primary : colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            constraints: const BoxConstraints(minWidth: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: icon != null
                ? Icon(
                    icon,
                    size: 20,
                    color: active
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                  )
                : Text(
                    label!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: active
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
