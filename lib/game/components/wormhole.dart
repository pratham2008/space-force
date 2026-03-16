import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import 'player.dart';

/// A deep-space wormhole hazard. Visually rendered as a dark gravitational
/// vortex with dim blue-white accretion arms — space-realistic, no neon.
/// Instant kill on contact with the player ship.
class Wormhole extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks {

  static const double _driftSpeed = 35.0;
  static const double _radius = 42.0;
  double _rotationPhase = 0;
  double _pulsePhase = 0;

  Wormhole({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(_radius * 2),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    add(CircleHitbox(
      radius: _radius * 0.65, // Slightly forgiving
      position: Vector2.all(_radius * 0.35),
    ));
    _rotationPhase = Random().nextDouble() * 2 * pi;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _rotationPhase += 1.8 * dt;
    _pulsePhase += 3.0 * dt;
    position.y += _driftSpeed * dt;

    if (position.y > game.size.y + _radius * 2) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      game.applyWormholeDeath();
    }
  }

  // ── Cached paints ─────────────────────────────────────────────────────────
  static final Paint _outerHaze = Paint()
    ..color = const Color(0xFF1A2744).withValues(alpha: 0.25)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
  static final Paint _armPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8;
  static final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final pulse = 0.7 + 0.3 * sin(_pulsePhase);

    // 1. Outer gravitational haze (dark blue, faint)
    canvas.drawCircle(Offset(cx, cy), _radius * 1.15 * pulse, _outerHaze);

    // 2. Accretion spiral arms (5 arms — deep blue to pale white)
    for (int arm = 0; arm < 5; arm++) {
      final baseAngle = _rotationPhase + arm * (2 * pi / 5);
      final path = Path();
      for (double t = 0; t < 1.0; t += 0.025) {
        final r = _radius * 0.12 + _radius * 0.80 * t;
        final a = baseAngle + t * 3.0;
        final x = cx + r * cos(a);
        final y = cy + r * sin(a);
        if (t == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      // Inner arms are brighter, outer fade to dark
      final brightness = 0.2 + 0.25 * (1 - arm / 5) * pulse;
      _armPaint.color = Color.lerp(
        const Color(0xFF1B2B4A), // deep space blue
        const Color(0xFFB8C8E8), // pale starlight
        (arm / 5),
      )!.withValues(alpha: brightness);
      canvas.drawPath(path, _armPaint);
    }

    // 3. Event horizon ring (faint blue-silver)
    _ringPaint.color = const Color(0xFF7090B8).withValues(alpha: 0.25 * pulse);
    canvas.drawCircle(Offset(cx, cy), _radius * 0.28 * pulse, _ringPaint);

    // 4. Gravitational lensing glow (very faint white-blue center)
    canvas.drawCircle(
      Offset(cx, cy),
      _radius * 0.18,
      Paint()
        ..color = const Color(0xFFB8C8E8).withValues(alpha: 0.3 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // 5. Dark singularity core
    canvas.drawCircle(Offset(cx, cy), _radius * 0.08, Paint()..color = const Color(0xFF050810));
  }
}
