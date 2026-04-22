import 'package:flutter/material.dart';

/// App launcher icon widget (can be exported as PNG)
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, this.size = 512});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF7C4DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withValues(alpha: .4),
            blurRadius: size * 0.1,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: _CrownPatternPainter(
                  color: Colors.white.withValues(alpha: .08),
                ),
              ),
            ),
            // Crown icon
            Center(
              child: Icon(
                Icons.military_tech,
                size: size * 0.55,
                color: Colors.white.withValues(alpha: .9),
              ),
            ),
            // Glow ring
            Center(
              child: Container(
                width: size * 0.75,
                height: size * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .15),
                    width: size * 0.015,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrownPatternPainter extends CustomPainter {
  final Color color;
  _CrownPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2;
    
    // Diagonal lines
    for (double i = -size.height; i < size.width + size.height; i += size.width / 8) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
