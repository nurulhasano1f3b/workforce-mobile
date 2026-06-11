import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/punch.dart';

/// The large primary punch action button.
///
/// Performance contract: the onPressed callback must return synchronously
/// (or fire-and-forget).  This widget itself never shows a spinner.
/// A haptic tap-response happens on press to give sub-100 ms physical feedback.
class PunchButton extends StatefulWidget {
  const PunchButton({
    super.key,
    required this.label,
    required this.punchType,
    required this.onPressed,
    this.color,
  });

  /// Text on the button (e.g. "Clock In", "Clock Out", "End Break").
  final String label;

  /// The punch type this button will submit.
  final PunchType punchType;

  /// Called synchronously on tap.  Must NOT be async from the caller's
  /// perspective — use fire-and-forget (unawaited) inside.
  final VoidCallback onPressed;

  /// Overrides the default colour derived from [punchType].
  final Color? color;

  @override
  State<PunchButton> createState() => _PunchButtonState();
}

class _PunchButtonState extends State<PunchButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  Color _defaultColor() {
    return switch (widget.punchType) {
      PunchType.clockIn => const Color(0xFF1B8A5A),   // green
      PunchType.clockOut => const Color(0xFFB03A2E),  // red
      PunchType.breakStart => const Color(0xFFD97706), // amber
      PunchType.breakEnd => const Color(0xFF1B8A5A),  // green (returning)
    };
  }

  void _handleTapDown(TapDownDetails _) {
    HapticFeedback.mediumImpact();
    _scaleCtrl.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _scaleCtrl.reverse();
    widget.onPressed();
  }

  void _handleTapCancel() {
    _scaleCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? _defaultColor();
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 72),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(100),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Smaller secondary action button (e.g. "Start Break" when clocked in).
class SecondaryPunchButton extends StatelessWidget {
  const SecondaryPunchButton({
    super.key,
    required this.label,
    required this.punchType,
    required this.onPressed,
  });

  final String label;
  final PunchType punchType;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Color(0xFFD97706), width: 2),
        foregroundColor: const Color(0xFFD97706),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
