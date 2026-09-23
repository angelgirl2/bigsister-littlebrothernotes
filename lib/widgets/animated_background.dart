import 'package:flutter/material.dart';

class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({
    super.key,
    required this.child,
    required this.primary,
    required this.secondary,
  });
  final Widget child;
  final Color primary;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF000000)),
        IgnorePointer(
          child: CustomPaint(painter: _AmbientPainter(primary, secondary)),
        ),
        child,
      ],
    );
  }
}

class _AmbientPainter extends CustomPainter {
  const _AmbientPainter(this.primary, this.secondary);
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final points = [
      Offset(size.width * .12, size.height * .18),
      Offset(size.width * .88, size.height * .34),
      Offset(size.width * .28, size.height * .82),
    ];
    final colors = [primary, secondary, primary];
    for (var i = 0; i < points.length; i++) {
      paint.color = colors[i].withValues(alpha: .025);
      canvas.drawCircle(points[i], 120, paint);
      paint.color = colors[i].withValues(alpha: .012);
      canvas.drawCircle(points[i], 220, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) =>
      oldDelegate.primary != primary || oldDelegate.secondary != secondary;
}
