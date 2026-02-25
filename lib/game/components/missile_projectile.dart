import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import '../effects/particle_effects.dart';
import 'player.dart';
import 'hittable.dart';

/// Computes missile damage for a given wave — called ONCE at creation.
int missileWaveDamage(int wave) {
  if (wave <= 8)  return 30;
  if (wave <= 12) return 50;
  if (wave <= 15) return 75;
  return 75; // Wave 16+; Boss missiles override with 100 in Phase 15
}

/// Guided-at-launch missile: direction is captured at fire time and fixed.
/// Does NOT live-track. Does NOT re-derive damage on impact.
class MissileProjectile extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks, Hittable {

  static const double _speed   = 480.0;
  static const double _width   = 6.0;
  static const double _height  = 22.0;
  static const int    _maxHits = 3;

  /// Damage captured at creation time, never mutated.
  final int damage;

  /// Normalized direction vector — set at creation, never changed.
  final Vector2 direction;

  int _hitsRemaining = _maxHits;

  MissileProjectile({
    required Vector2 position,
    required this.damage,
    required this.direction,
  }) : super(
          position: position,
          size: Vector2(_width, _height),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(
      size: Vector2(_width, _height),
      collisionType: CollisionType.active,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.addScaled(direction, _speed * dt);
    // Remove once well off-screen
    if (position.y > game.size.y + 50 || position.y < -50 ||
        position.x < -50 || position.x > game.size.x + 50) {
      removeFromParent();
    }
  }

  /// Called by Bullet — but missiles can't be hit by other missiles.
  /// This satisfies Hittable for completeness (player bullet → missile).
  @override
  void hit(int bulletDamage) {
    _hitsRemaining--;
    final pCount = game.children.whereType<ParticleSystemComponent>().length;
    if (pCount < kMaxParticleSystems) {
      game.add(sparkParticles(position.clone()));
    }
    if (_hitsRemaining <= 0) {
      if (pCount < kMaxParticleSystems) {
        game.add(explosionParticles(position.clone()));
      }
      game.audioManager.playSfx('explosion.wav');
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      // Damage is pre-computed at creation — never re-derived here.
      game.applyMissileDamageToPlayer(damage);
      other.takeDamage(isCollision: false);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    // Outer glow
    canvas.drawOval(
      Rect.fromLTWH(-3, -3, _width + 6, _height + 6),
      Paint()
        ..color = const Color(0xFFFF6D00).withValues(alpha: 0.25)
        ..blendMode = BlendMode.plus,
    );
    // Main body
    canvas.drawPath(
      Path()
        ..moveTo(_width / 2, 0)
        ..lineTo(_width, _height * 0.6)
        ..lineTo(_width * 0.7, _height)
        ..lineTo(_width * 0.3, _height)
        ..lineTo(0, _height * 0.6)
        ..close(),
      Paint()..color = const Color(0xFFFF3D00),
    );
    // Hot nose tip
    canvas.drawCircle(
      Offset(_width / 2, 2), 2,
      Paint()
        ..color = Colors.white
        ..blendMode = BlendMode.plus,
    );
    // HP bar (shown after first hit)
    if (_hitsRemaining < _maxHits) {
      final ratio = _hitsRemaining / _maxHits;
      canvas.drawRect(
        Rect.fromLTWH(-1, -7, _width + 2, 2),
        Paint()..color = Colors.black26,
      );
      canvas.drawRect(
        Rect.fromLTWH(-1, -7, (_width + 2) * ratio, 2),
        Paint()..color = const Color(0xFFFF6D00),
      );
    }
  }
}
