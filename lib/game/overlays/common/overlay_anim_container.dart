import 'package:flutter/material.dart';

/// A wrapper that applies a consistent Fade + Scale transition to overlays.
/// Used to unify the entry/exit animations of all game modals.
class OverlayAnimContainer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const OverlayAnimContainer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
  });

  @override
  State<OverlayAnimContainer> createState() => _OverlayAnimContainerState();
}

class _OverlayAnimContainerState extends State<OverlayAnimContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
