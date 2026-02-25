import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';

/// Circular targeting reticle shown on the player during missile lock-on.
/// Pulses 1.0→1.1 over 0.8s, then auto-removes (caller fires missile after).
class MissileLockReticle extends Component
    with HasGameReference<ZeroVectorGame> {

  static const double _lockDuration = 0.8;
  double _timer = 0;
  double _pulsePhase = 0;

  /// Called when lock completes; spawn missile from [missilePos] toward player.
  final void Function() onLockComplete;

  MissileLockReticle({required this.onLockComplete});

  @override
  void update(double dt) {
    super.update(dt);
    _timer += dt;
    _pulsePhase += dt * (pi * 2 / 0.4); // One full pulse per 0.4s

    if (_timer >= _lockDuration) {
      onLockComplete();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final player = game.player;
    if (player == null) return;

    final center = Offset(player.position.x, player.position.y);

    // Pulse scale 1.0 → 1.1 (ease sinusoidal)
    final pulseFactor = 1.0 + sin(_pulsePhase).abs() * 0.1;
    final radius = 22.0 * pulseFactor;

    // Lock progress opacity: ramps from 0.2 → 0.6
    final progress = (_timer / _lockDuration).clamp(0.0, 1.0);
    final opacity  = 0.2 + progress * 0.4;

    final paint = Paint()
      ..color = const Color(0xFFFF3D00).withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..blendMode = BlendMode.plus;

    // Outer circle
    canvas.drawCircle(center, radius, paint);

    // Corner tick marks (4 quadrant notches)
    const tickLength = 6.0;
    for (int i = 0; i < 4; i++) {
      final angle = (pi / 2) * i;
      final x1 = center.dx + cos(angle) * (radius - tickLength);
      final y1 = center.dy + sin(angle) * (radius - tickLength);
      final x2 = center.dx + cos(angle) * radius;
      final y2 = center.dy + sin(angle) * radius;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }

    // Progress arc — fills as lock approaches completion
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -pi / 2,
      progress * 2 * pi,
      false,
      paint..color = const Color(0xFFFF6D00).withValues(alpha: opacity + 0.1),
    );
  }
}
