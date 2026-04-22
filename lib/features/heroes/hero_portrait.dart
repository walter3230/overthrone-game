import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'hero_types.dart';

/// Procedurally generated hero portrait widget
/// Each hero gets a unique visual based on faction, role, and name hash
class HeroPortrait extends StatelessWidget {
  const HeroPortrait({
    super.key,
    required this.name,
    required this.faction,
    required this.role,
    this.size = 120,
    this.borderRadius = 16,
    this.showName = false,
  });

  final String name;
  final Faction faction;
  final Role role;
  final double size;
  final double borderRadius;
  final bool showName;

  int get _hash => name.hashCode.abs();

  @override
  Widget build(BuildContext context) {
    final colors = _factionGradient(faction);
    final pattern = _hash % 6;
    final accent = _accentColor(faction);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: .3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _PatternPainter(
                  pattern: pattern,
                  color: Colors.white.withValues(alpha: .06),
                  seed: _hash,
                ),
              ),
            ),

            // Central icon (role-based silhouette)
            Center(
              child: _HeroSilhouette(
                role: role,
                faction: faction,
                size: size * 0.55,
                hash: _hash,
              ),
            ),

            // Faction emblem (top-left)
            Positioned(
              left: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  faction.icon,
                  size: size * 0.12,
                  color: accent,
                ),
              ),
            ),

            // Role icon (top-right)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  role.icon,
                  size: size * 0.12,
                  color: Colors.white70,
                ),
              ),
            ),

            // Glow effect at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: size * 0.35,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .6),
                    ],
                  ),
                ),
              ),
            ),

            // Name at bottom
            if (showName)
              Positioned(
                bottom: 6,
                left: 6,
                right: 6,
                child: Text(
                  _shortName(name, faction),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.1,
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(blurRadius: 4, color: Colors.black),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _shortName(String full, Faction f) {
    final prefix = '${f.label} ';
    return full.startsWith(prefix) ? full.substring(prefix.length) : full;
  }
}

/// Hero silhouette based on role
class _HeroSilhouette extends StatelessWidget {
  const _HeroSilhouette({
    required this.role,
    required this.faction,
    required this.size,
    required this.hash,
  });

  final Role role;
  final Faction faction;
  final double size;
  final int hash;

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor(faction);

    // Different icon combos based on role
    final (IconData mainIcon, IconData? bgIcon) = switch (role) {
      Role.warrior => (Icons.shield_outlined, Icons.bolt),
      Role.ranger => (Icons.gps_fixed, Icons.near_me_outlined),
      Role.raider => (Icons.content_cut, Icons.speed),
      Role.healer => (Icons.healing, Icons.favorite_border),
      Role.mage => (Icons.auto_awesome, Icons.blur_circular),
    };

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background glow
        if (bgIcon != null)
          Icon(
            bgIcon,
            size: size * 1.2,
            color: accent.withValues(alpha: .12),
          ),
        // Main icon
        Icon(
          mainIcon,
          size: size * 0.7,
          color: Colors.white.withValues(alpha: .85),
        ),
        // Decorative ring
        Container(
          width: size * 0.9,
          height: size * 0.9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: accent.withValues(alpha: .2),
              width: 2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Background pattern painter
class _PatternPainter extends CustomPainter {
  final int pattern;
  final Color color;
  final int seed;

  _PatternPainter({required this.pattern, required this.color, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1;
    final rng = Random(seed);

    switch (pattern) {
      case 0: // Diagonal lines
        for (double i = -size.height; i < size.width + size.height; i += 12) {
          canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
        }
        break;
      case 1: // Circles
        for (int i = 0; i < 8; i++) {
          final x = rng.nextDouble() * size.width;
          final y = rng.nextDouble() * size.height;
          final r = 10.0 + rng.nextDouble() * 30;
          canvas.drawCircle(Offset(x, y), r, paint..style = PaintingStyle.stroke);
        }
        break;
      case 2: // Grid dots
        for (double x = 0; x < size.width; x += 16) {
          for (double y = 0; y < size.height; y += 16) {
            canvas.drawCircle(Offset(x, y), 1.5, paint..style = PaintingStyle.fill);
          }
        }
        break;
      case 3: // Hexagonal pattern
        for (double y = 0; y < size.height; y += 20) {
          final offset = (y ~/ 20).isEven ? 0.0 : 10.0;
          for (double x = offset; x < size.width; x += 20) {
            _drawHex(canvas, Offset(x, y), 8, paint..style = PaintingStyle.stroke);
          }
        }
        break;
      case 4: // Scattered stars
        for (int i = 0; i < 12; i++) {
          final x = rng.nextDouble() * size.width;
          final y = rng.nextDouble() * size.height;
          _drawStar(canvas, Offset(x, y), 4 + rng.nextDouble() * 6, paint..style = PaintingStyle.fill);
        }
        break;
      default: // Cross hatch
        for (double i = 0; i < size.width; i += 18) {
          canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
        }
        for (double i = 0; i < size.height; i += 18) {
          canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
        }
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60.0 * i - 30) * 3.14159 / 180;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = (72.0 * i - 90) * 3.14159 / 180;
      final innerAngle = (72.0 * i + 36 - 90) * 3.14159 / 180;
      final ox = center.dx + r * cos(outerAngle);
      final oy = center.dy + r * sin(outerAngle);
      final ix = center.dx + r * 0.4 * cos(innerAngle);
      final iy = center.dy + r * 0.4 * sin(innerAngle);
      if (i == 0) path.moveTo(ox, oy); else path.lineTo(ox, oy);
      path.lineTo(ix, iy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---- Color helpers ----

List<Color> _factionGradient(Faction f) => switch (f) {
  Faction.elemental => [const Color(0xFF1A237E), const Color(0xFF7C4DFF)],
  Faction.dark => [const Color(0xFF1B0A2E), const Color(0xFF6D214F)],
  Faction.nature => [const Color(0xFF1B5E20), const Color(0xFF00BFA5)],
  Faction.mech => [const Color(0xFF263238), const Color(0xFF00ACC1)],
  Faction.voidF => [const Color(0xFF0D0221), const Color(0xFF4A148C)],
  Faction.light => [const Color(0xFFE65100), const Color(0xFFFFD54F)],
};

Color _accentColor(Faction f) => switch (f) {
  Faction.elemental => const Color(0xFF82B1FF),
  Faction.dark => const Color(0xFFCE93D8),
  Faction.nature => const Color(0xFF69F0AE),
  Faction.mech => const Color(0xFF80DEEA),
  Faction.voidF => const Color(0xFFB388FF),
  Faction.light => const Color(0xFFFFE082),
};
