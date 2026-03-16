import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import 'player.dart';
import 'bullet.dart';
import 'enemy.dart';
import 'mini_boss.dart';
import 'missile_ship.dart';
import 'missile_projectile.dart';

/// A deep-space wormhole hazard with realistic gravitational pull.
/// Attracts nearby objects (bullets, enemies, missiles) within its gravity
/// radius. Instant kill on contact with the player ship.
class Wormhole extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks {

  static const double _driftSpeed = 35.0;
  static const double _radius = 42.0;

  /// Objects within this radius get pulled toward the centre.
  static const double _gravityRadius = 140.0;

  /// Strength of the gravitational pull (pixels/s² at closest range).
  static const double _gravityStrength = 280.0;

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
      radius: _radius * 0.65,
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
      return;
    }

    // ── Gravitational attraction ──────────────────────────────────────────────
    _applyGravity<Bullet>(dt);
    _applyGravity<EnemyBullet>(dt);
    _applyGravity<EnemyBulletMiniBoss>(dt);
    _applyGravity<MissileProjectile>(dt);
    _applyGravity<Enemy>(dt);
    _applyGravity<MissileShip>(dt);
  }

  /// Pulls all children of type [T] toward this wormhole's centre.
  /// Force scales with inverse distance (stronger when closer).
  /// Objects that reach the core are consumed (removed).
  void _applyGravity<T extends PositionComponent>(double dt) {
    for (final obj in game.children.whereType<T>()) {
      final diff = position - obj.position;
      final dist = diff.length;

      if (dist < 1 || dist > _gravityRadius) continue;

      // Consume objects that reach the core
      if (dist < _radius * 0.3) {
        obj.removeFromParent();
        continue;
      }

      // Inverse-distance force: stronger as objects approach
      final force = _gravityStrength * (1.0 - dist / _gravityRadius);
      final direction = diff.normalized();
      obj.position.addScaled(direction, force * dt);
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
      final brightness = 0.2 + 0.25 * (1 - arm / 5) * pulse;
      _armPaint.color = Color.lerp(
        const Color(0xFF1B2B4A),
        const Color(0xFFB8C8E8),
        (arm / 5),
      )!.withValues(alpha: brightness);
      canvas.drawPath(path, _armPaint);
    }

    // 3. Event horizon ring (faint blue-silver)
    _ringPaint.color = const Color(0xFF7090B8).withValues(alpha: 0.25 * pulse);
    canvas.drawCircle(Offset(cx, cy), _radius * 0.28 * pulse, _ringPaint);

    // 4. Gravitational lensing glow
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
