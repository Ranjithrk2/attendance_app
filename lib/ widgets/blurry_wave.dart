import 'package:flutter/material.dart';

class BlurryWavePainter extends CustomPainter {
  final double progress;
  BlurryWavePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      double waveProgress = (progress + i * 0.3) % 1.0;
      double radius = 60 + waveProgress * 100; // expand from logo outward
      final opacity = (1.0 - waveProgress).clamp(0.0, 0.5); // fade out

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(opacity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BlurryWavePainter oldDelegate) => true;
}
