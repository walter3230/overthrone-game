// lib/ui/game_theme.dart
import 'package:flutter/material.dart';

/// Overthrone özel oyun teması - X-Heroes tarzı karanlık RPG teması
class GameTheme {
  GameTheme._();

  // ─── Ana Renkler ───
  static const Color abyss = Color(0xFF0A0E1A);        // En koyu zemin
  static const Color deepNavy = Color(0xFF0F1629);      // Kart zemin
  static const Color darkSurface = Color(0xFF151B2E);   // Yüzey
  static const Color midSurface = Color(0xFF1C2340);     // Orta yüzey
  static const Color elevatedSurface = Color(0xFF232B48); // Yüksek yüzey

  // ─── Vurgu Renkleri ───
  static const Color royalGold = Color(0xFFFFD54F);
  static const Color cosmicPurple = Color(0xFF7C4DFF);
  static const Color neonBlue = Color(0xFF4FC3F7);
  static const Color plasmaRed = Color(0xFFFF5252);
  static const Color voidViolet = Color(0xFF9C27B0);
  static const Color emeraldGlow = Color(0xFF69F0AE);
  static const Color amberEnergy = Color(0xFFFFAB00);

  // ─── Faction Renkleri ───
  static const Map<int, List<Color>> factionGradients = {
    0: [Color(0xFF1565C0), Color(0xFF7C4DFF)], // Elemental - blue→purple
    1: [Color(0xFF1A1A2E), Color(0xFF6D214F)], // Dark - deep purple→crimson
    2: [Color(0xFF1B5E20), Color(0xFF00897B)],  // Nature - forest→teal
    3: [Color(0xFF37474F), Color(0xFF00BCD4)],  // Mech - steel→cyan
    4: [Color(0xFF1A1A2E), Color(0xFF4E31AA)],  // Void - dark→violet
    5: [Color(0xFFFF8F00), Color(0xFFFFEE58)],  // Light - gold→bright
  };

  static const Map<int, Color> factionGlow = {
    0: Color(0xFF4FC3F7),  // Elemental - neon blue glow
    1: Color(0xFFE91E63),  // Dark - crimson glow
    2: Color(0xFF69F0AE),  // Nature - green glow
    3: Color(0xFF00E5FF),  // Mech - cyan glow
    4: Color(0xFF9C27B0),  // Void - purple glow
    5: Color(0xFFFFD54F),  // Light - gold glow
  };

  // ─── Rarity Renkleri ───
  static const Map<int, Color> rarityGlow = {
    0: Color(0xFFFFD54F),  // S+ - altın
    1: Color(0xFF7C4DFF),  // S  - mor
    2: Color(0xFF4FC3F7),  // A  - mavi
    3: Color(0xFF78909C),  // B  - gri
  };

  static const Map<int, List<Color>> rarityBorderGradients = {
    0: [Color(0xFFFFD54F), Color(0xFFFF8F00), Color(0xFFFFD54F)], // S+
    1: [Color(0xFF7C4DFF), Color(0xFFE91E63)],                     // S
    2: [Color(0xFF4FC3F7), Color(0xFF2196F3)],                     // A
    3: [Color(0xFF78909C), Color(0xFF546E7A)],                     // B
  };

  // ─── Tema Verileri ───
  static ThemeData get darkGameTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: abyss,
        colorScheme: const ColorScheme.dark(
          primary: cosmicPurple,
          onPrimary: Colors.white,
          secondary: royalGold,
          onSecondary: abyss,
          surface: darkSurface,
          onSurface: Colors.white,
          error: plasmaRed,
          outline: Color(0xFF2A3352),
          outlineVariant: Color(0xFF1E2644),
        ),
        cardTheme: CardThemeData(
          color: darkSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A3352)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: cosmicPurple,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
          ),
          headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: Colors.white,
          ),
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          titleMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          bodyMedium: TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
          labelLarge: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
          labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white60,
          ),
        ),
      );
}

/// Glow efektli container
class GlowContainer extends StatelessWidget {
  const GlowContainer({
    super.key,
    required this.child,
    this.glowColor = GameTheme.cosmicPurple,
    this.glowRadius = 12,
    this.borderRadius = 16,
    this.backgroundColor,
    this.borderGradient,
    this.padding,
  });

  final Widget child;
  final Color glowColor;
  final double glowRadius;
  final double borderRadius;
  final Color? backgroundColor;
  final List<Color>? borderGradient;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    if (borderGradient != null) {
      return Container(
        padding: padding,
        decoration: ShapeDecoration(
          shape: GradientBoxBorder(
            gradient: LinearGradient(colors: borderGradient!),
            borderWidth: 1.5,
          ),
          color: backgroundColor ?? GameTheme.darkSurface,
          shadows: [
            BoxShadow(
              color: glowColor.withOpacity(0.15),
              blurRadius: glowRadius,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: glowColor.withOpacity(0.05),
              blurRadius: glowRadius * 2,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? GameTheme.darkSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: glowColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.15),
            blurRadius: glowRadius,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: glowColor.withOpacity(0.05),
            blurRadius: glowRadius * 2,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Gradient border için özel Border sınıfı - OutlinedBorder tabanlı
class GradientBoxBorder extends OutlinedBorder {
  const GradientBoxBorder({
    required this.gradient,
    this.borderWidth = 1.0,
    super.side = BorderSide.none,
  });

  final Gradient gradient;
  final double borderWidth;

  @override
  EdgeInsetsGeometry get insets => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) {
    return GradientBoxBorder(
      gradient: gradient,
      borderWidth: borderWidth * t,
      side: side.scale(t),
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? other, double t) {
    if (other is GradientBoxBorder) {
      return GradientBoxBorder(
        gradient: Gradient.lerp(other.gradient, gradient, t)!,
        borderWidth: other.borderWidth + (borderWidth - other.borderWidth) * t,
      );
    }
    return super.lerpFrom(other, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? other, double t) {
    if (other is GradientBoxBorder) {
      return GradientBoxBorder(
        gradient: Gradient.lerp(gradient, other.gradient, t)!,
        borderWidth: borderWidth + (other.borderWidth - borderWidth) * t,
      );
    }
    return super.lerpTo(other, t);
  }

  @override
  GradientBoxBorder copyWith({BorderSide? side, Gradient? gradient, double? borderWidth}) {
    return GradientBoxBorder(
      gradient: gradient ?? this.gradient,
      borderWidth: borderWidth ?? this.borderWidth,
      side: side ?? this.side,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(RRect.fromRectAndRadius(
      rect.deflate(borderWidth),
      const Radius.circular(16),
    ));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(RRect.fromRectAndRadius(
      rect,
      const Radius.circular(16),
    ));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      paint,
    );
  }
}

/// Pulse animasyonlu glow
class PulsingGlow extends StatefulWidget {
  const PulsingGlow({
    super.key,
    required this.child,
    this.color = GameTheme.cosmicPurple,
    this.minOpacity = 0.1,
    this.maxOpacity = 0.3,
    this.durationMs = 2000,
  });

  final Widget child;
  final Color color;
  final double minOpacity;
  final double maxOpacity;
  final int durationMs;

  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.durationMs),
    )..repeat(reverse: true);
    _anim = Tween(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(_anim.value),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Shimmer efektli overlay (kart üstü parıltı)
class ShimmerOverlay extends StatefulWidget {
  const ShimmerOverlay({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<ShimmerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final dx = _ctrl.value * 2.5 - 0.5;
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(dx - 0.3, 0),
                      end: Alignment(dx + 0.3, 0),
                      colors: const [
                        Colors.transparent,
                        Color(0x18FFFFFF),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
