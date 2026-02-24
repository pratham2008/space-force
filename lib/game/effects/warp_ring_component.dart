
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A brief expanding ring effect shown when an enemy warps in.
/// Purely dt-based — no frame-dependency.
class WarpRingComponent extends PositionComponent {
  double _elapsed = 0;
  static const double _duration = 0.35;
  static const double _maxRadius = 35.0;
  final Color _color;

  WarpRingComponent({
    required Vector2 position,
    Color color = const Color(0xFF00E5FF),
  })  : _color = color,
        super(position: position, anchor: Anchor.center);

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _duration).clamp(0.0, 1.0);
    final radius = _maxRadius * t;
    final alpha = (1.0 - t).clamp(0.0, 1.0);

    // Glow ring: BlendMode.plus for better Android performance
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * (1.0 - t * 0.5)
      ..color = _color.withValues(alpha: alpha * 0.4)
      ..blendMode = BlendMode.plus;

    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = _color.withValues(alpha: alpha);

    canvas.drawCircle(Offset.zero, radius, glowPaint);
    canvas.drawCircle(Offset.zero, radius, corePaint);

    // Inner flash at t=0 (quick bright dot)
    if (t < 0.2) {
      final flashAlpha = (1.0 - t / 0.2).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset.zero,
        6 * (1.0 - t / 0.2),
        Paint()
          ..color = _color.withValues(alpha: flashAlpha)
          ..blendMode = BlendMode.plus,
      );
    }
  }
}
