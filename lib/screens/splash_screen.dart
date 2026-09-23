import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone, required this.primary});
  final VoidCallback onDone;
  final Color primary;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _master = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  late final AnimationController _orb = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  late final Animation<double> _logoScale = Tween(begin: .45, end: 1.0).animate(CurvedAnimation(parent: _master, curve: const Interval(0, .55, curve: Curves.easeOutBack)));
  late final Animation<double> _logoFade = CurvedAnimation(parent: _master, curve: const Interval(0, .45, curve: Curves.easeOut));
  late final Animation<Offset> _titleSlide = Tween(begin: const Offset(0, .55), end: Offset.zero).animate(CurvedAnimation(parent: _master, curve: const Interval(.3, .78, curve: Curves.easeOutCubic)));
  late final Animation<double> _titleFade = CurvedAnimation(parent: _master, curve: const Interval(.28, .72, curve: Curves.easeOut));
  late final Animation<double> _loader = CurvedAnimation(parent: _master, curve: const Interval(.62, 1, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2850), () { if (mounted) widget.onDone(); });
  }

  @override
  void dispose() { _master.dispose(); _orb.dispose(); _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_master, _orb, _pulse]),
        builder: (_, __) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF02040A), Color(0xFF07131A), Color(0xFF12050D), Color(0xFF030409)]))),
              CustomPaint(painter: _SplashPainter(widget.primary, _orb.value)),
              Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Transform.rotate(
                        angle: math.sin(_orb.value * math.pi * 2) * .035,
                        child: Container(
                          width: 138,
                          height: 138,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.primary.withValues(alpha: .08),
                            border: Border.all(
                              color: widget.primary.withValues(alpha: .24),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: widget.primary.withValues(
                                  alpha: .18 + _pulse.value * .12,
                                ),
                                blurRadius: 55 + _pulse.value * 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(10),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/logo.png',
                              width: 118,
                              height: 118,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SlideTransition(position: _titleSlide, child: FadeTransition(opacity: _titleFade, child: Column(children: [const Text('For Big Sister', style: TextStyle(fontSize: 31, fontWeight: FontWeight.w900, letterSpacing: .2)), const SizedBox(height: 7), const Text('❤️  🫂', style: TextStyle(fontSize: 27)), const SizedBox(height: 15), Text('یادداشت‌هایی از دل برای یک خواهر خاص', style: TextStyle(color: Colors.white.withValues(alpha: .62), fontSize: 14.5))]))),
                  const SizedBox(height: 44),
                  FadeTransition(opacity: _loader, child: Column(children: [SizedBox(width: 190, child: ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: _loader.value, minHeight: 5, backgroundColor: Colors.white.withValues(alpha: .08), valueColor: AlwaysStoppedAnimation(widget.primary)))), const SizedBox(height: 14), Text('در حال آماده‌سازی خاطره‌ها...', style: TextStyle(color: widget.primary.withValues(alpha: .78), fontSize: 12.5))])),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  _SplashPainter(this.color, this.progress);
  final Color color;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final p = Paint()..style = PaintingStyle.stroke;
    for (var i = 0; i < 7; i++) {
      final angle = progress * math.pi * 2 + i * math.pi * 2 / 7;
      final radius = 105.0 + i * 35.0;
      final r = radius + math.sin(progress * math.pi * 4 + i) * 8;
      p.strokeWidth = i == 0 ? 1.5 : 1;
      p.color = color.withValues(alpha: .08 - i * .008);
      canvas.drawCircle(center, r, p);
      final dot = Offset(center.dx + math.cos(angle) * r, center.dy + math.sin(angle) * r);
      p.style = PaintingStyle.fill;
      p.color = color.withValues(alpha: .22);
      canvas.drawCircle(dot, i == 0 ? 3.5 : 2, p);
      p.style = PaintingStyle.stroke;
    }
  }
  @override
  bool shouldRepaint(covariant _SplashPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}
