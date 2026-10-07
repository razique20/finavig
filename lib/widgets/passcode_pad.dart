import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Callback for a completed passcode entry. Return `null` to accept (the panel
/// clears itself) or a message to reject (the panel shakes, clears and shows
/// that message).
typedef PasscodeSubmit = Future<String?> Function(String pin);

/// Row of dots showing how many digits of the passcode have been entered.
class PasscodeDots extends StatelessWidget {
  final int length;
  final int filled;
  final bool error;

  /// White dots for a dark backdrop (the lock overlay); ink dots for a sheet.
  final bool onDark;

  const PasscodeDots({
    super.key,
    required this.length,
    required this.filled,
    this.error = false,
    this.onDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = error
        ? FinavigColors.danger
        : (onDark ? Colors.white : FinavigColors.ink);
    final idleBorder = (onDark ? Colors.white : Colors.black).withOpacity(0.35);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? activeColor : Colors.transparent,
              border: Border.all(
                color: i < filled ? activeColor : idleBorder,
                width: 1.6,
              ),
            ),
          ),
          if (i != length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }
}

/// Numeric keypad for passcode entry (1–9, then optional leading action, 0,
/// backspace).
class PasscodeKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Optional widget placed in the bottom-left slot — used for the biometric
  /// button.
  final Widget? leading;

  /// When false every key is inert (e.g. during a lockout).
  final bool enabled;

  /// White digits on a dark backdrop; ink digits on a light one.
  final bool onDark;

  const PasscodeKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.leading,
    this.enabled = true,
    this.onDark = true,
  });

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final digit in row) _digitKey(digit),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 74, height: 64, child: Center(child: leading)),
            _digitKey('0'),
            _iconKey(
              icon: Icons.backspace_outlined,
              onTap: enabled ? onBackspace : null,
              semanticLabel: 'Delete',
            ),
          ],
        ),
      ],
    );
  }

  Widget _digitKey(String digit) => _iconKey(
        label: digit,
        onTap: enabled ? () => onDigit(digit) : null,
        semanticLabel: digit,
      );

  Widget _iconKey({
    String? label,
    IconData? icon,
    VoidCallback? onTap,
    required String semanticLabel,
  }) {
    final fg = onDark ? Colors.white : FinavigColors.ink;
    return SizedBox(
      width: 74,
      height: 64,
      child: Center(
        child: Semantics(
          button: true,
          label: semanticLabel,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.04),
                ),
                child: icon != null
                    ? Icon(icon, size: 22, color: fg)
                    : Text(
                        label ?? '',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: fg,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The full passcode entry experience: title, dots, error line and keypad.
///
/// Owns only the transient input state; the meaning of a completed passcode is
/// decided by [onSubmit], which lets the lock overlay, the setup flow and the
/// verify prompts share one implementation.
class PasscodeLockPanel extends StatefulWidget {
  final String title;
  final String? subtitle;
  final PasscodeSubmit onSubmit;

  /// Extra action under the keypad (e.g. "Forgot passcode?").
  final Widget? footer;

  /// Biometric trigger placed in the keypad's bottom-left slot.
  final Widget? biometricButton;

  /// Set false to freeze input (lockout in effect).
  final bool enabled;

  final int length;
  final bool onDark;

  const PasscodeLockPanel({
    super.key,
    required this.title,
    required this.onSubmit,
    this.subtitle,
    this.footer,
    this.biometricButton,
    this.enabled = true,
    this.length = 6,
    this.onDark = true,
  });

  @override
  State<PasscodeLockPanel> createState() => _PasscodeLockPanelState();
}

class _PasscodeLockPanelState extends State<PasscodeLockPanel>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _error;
  bool _busy = false;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_busy || !widget.enabled || _pin.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == widget.length) _submit();
  }

  void _onBackspace() {
    if (_busy || !widget.enabled || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _submit() async {
    final pin = _pin;
    setState(() => _busy = true);
    final message = await widget.onSubmit(pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pin = '';
      _error = message;
    });
    if (message != null) {
      HapticFeedback.mediumImpact();
      _shake.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.onDark ? Colors.white : FinavigColors.textPrimaryLight;
    final subtitleColor = widget.onDark
        ? Colors.white.withOpacity(0.65)
        : FinavigColors.textSecondaryLight;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: titleColor,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: subtitleColor),
            ),
          ),
        ],
        const SizedBox(height: 28),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            final dx = math.sin(t * math.pi * 6) * 9 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: PasscodeDots(
            length: widget.length,
            filled: _pin.length,
            error: _error != null,
            onDark: widget.onDark,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 20,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _error == null
                ? const SizedBox.shrink(key: ValueKey('ok'))
                : Text(
                    _error!,
                    key: ValueKey(_error),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: FinavigColors.danger,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        PasscodeKeypad(
          onDigit: _onDigit,
          onBackspace: _onBackspace,
          leading: widget.biometricButton,
          enabled: widget.enabled && !_busy,
          onDark: widget.onDark,
        ),
        if (widget.footer != null) ...[
          const SizedBox(height: 6),
          widget.footer!,
        ],
      ],
    );
  }
}
