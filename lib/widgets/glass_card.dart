import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatefulWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.accent});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool pressed = false;
  bool entered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => entered = true); });
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? Theme.of(context).colorScheme.primary;
    return AnimatedOpacity(
      opacity: entered ? 1 : 0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: entered ? Offset.zero : const Offset(0, .018),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: widget.onTap == null ? null : (_) => setState(() => pressed = true),
          onTapCancel: widget.onTap == null ? null : () => setState(() => pressed = false),
          onTapUp: widget.onTap == null ? null : (_) => setState(() => pressed = false),
          child: AnimatedScale(
            scale: pressed ? .985 : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    color: AppPalette.card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white.withValues(alpha: .055)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: .34), blurRadius: 18, offset: const Offset(0, 8)),
                      BoxShadow(color: accent.withValues(alpha: .025), blurRadius: 18),
                    ],
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
