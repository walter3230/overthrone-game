import 'package:flutter/material.dart';

/// Floating damage/heal popup data
class DamagePopup {
  final int id;
  final int unitId;
  final String text;
  final Color color;

  const DamagePopup({
    required this.id,
    required this.unitId,
    required this.text,
    required this.color,
  });
}

/// Screen flash effect for AoE attacks
class AoeFlashOverlay extends StatefulWidget {
  const AoeFlashOverlay({super.key, required this.trigger, required this.child});
  final bool trigger;
  final Widget child;

  @override
  State<AoeFlashOverlay> createState() => _AoeFlashOverlayState();
}

class _AoeFlashOverlayState extends State<AoeFlashOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = Tween(begin: 0.0, end: 0.3).animate(_ctrl);
  }

  @override
  void didUpdateWidget(covariant AoeFlashOverlay old) {
    super.didUpdateWidget(old);
    if (widget.trigger && !old.trigger) {
      _ctrl.forward(from: 0).then((_) => _ctrl.reverse());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _opacity,
          builder: (_, __) => IgnorePointer(
            child: Container(
              color: Colors.white.withValues(alpha: _opacity.value),
            ),
          ),
        ),
      ],
    );
  }
}

/// Crit flash effect (golden border flash)
class CritFlashWidget extends StatelessWidget {
  const CritFlashWidget({super.key, required this.isCrit, required this.child});
  final bool isCrit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isCrit) return child;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: .5),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}
