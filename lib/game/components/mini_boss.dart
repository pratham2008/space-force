import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import '../effects/particle_effects.dart';
import '../effects/warp_ring_component.dart';
import 'hittable.dart';
import 'player.dart';
import 'missile_projectile.dart';
import 'missile_lock_reticle.dart';



class MiniBoss extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks, Hittable {

  final int wave;
  int hp;

  // ── Movement ────────────────────────────────────────────────────────────────
  static const double _entrySpeed  = 80.0;
  static const double _oscillationAmplitude = 40.0;
  double _hoverTargetY = 0;
  bool _hovering = false;
  double _oscillationPhase = 0;

  // ── Fire ────────────────────────────────────────────────────────────────────
  double _gunTimer   = 0;
  double _missileTimer = 0;
  bool _missileReticleActive = false;
  final Random _random = Random();

  double get _gunInterval   => (1.8 - wave * 0.04).clamp(0.4, 1.8);
  double get _missileInterval => (6.0 - wave * 0.1).clamp(2.5, 6.0);

  MiniBoss({required this.wave, required this.hp, required Vector2 position})
      : super(
          position: position,
          size: Vector2.zero(), // sized in onLoad based on screen
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Size: 22% of screen height, proportional width
    size = Vector2(game.size.y * 0.22 * 1.4, game.size.y * 0.22);

    add(RectangleHitbox(
      size: Vector2(size.x * 0.85, size.y * 0.8),
      position: Vector2(size.x * 0.075, size.y * 0.1),
    ));

    _hoverTargetY = game.size.y * 0.25;
    _oscillationPhase = _random.nextDouble() * 2 * pi;

    game.add(WarpRingComponent(
      position: position.clone(),
      color: const Color(0xFFFF1744),
    ));
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _oscillationPhase += 1.0 * dt;

    if (!_hovering) {
      position.y += _entrySpeed * dt;
      if (position.y >= _hoverTargetY) {
        position.y = _hoverTargetY;
        _hovering = true;
      }
    } else {
      position.x += sin(_oscillationPhase) * _oscillationAmplitude * dt;
      position.x = position.x.clamp(size.x / 2, game.size.x - size.x / 2);
    }

    if (!_hovering) return;

    // ── Machine gun (2 ports) ──────────────────────────────────────────────
    _gunTimer += dt;
    if (_gunTimer >= _gunInterval) {
      _gunTimer = 0;
      _fireGuns();
    }

    // ── Missile (1 launcher) ──────────────────────────────────────────────
    _missileTimer += dt;
    if (_missileTimer >= _missileInterval && !_missileReticleActive) {
      _missileTimer = 0;
      _missileReticleActive = true;
      game.add(MissileLockReticle(onLockComplete: _onMissileLockComplete));
    }
  }

  void _fireGuns() {
    final cx = position.x;
    final cy = position.y + size.y / 2;
    final offset = size.x * 0.35;

    // Two gun ports
    for (final x in [cx - offset, cx + offset]) {
      game.add(EnemyBulletMiniBoss(position: Vector2(x, cy)));
    }
    game.audioManager.playSfx('enemy_shoot.wav');
  }

  void _onMissileLockComplete() {
    _missileReticleActive = false;
    final player = game.player;
    if (player == null) return;
    final spawnPos  = Vector2(position.x, position.y + size.y / 2);
    final rawDir    = player.position - spawnPos; // Capture at fire time
    final direction = rawDir.length > 0.001
        ? (rawDir..normalize())
        : Vector2(0, 1);
    game.add(MissileProjectile(
      position: spawnPos,
      damage: missileWaveDamage(wave),
      direction: direction,
    ));
    game.audioManager.playSfx('enemy_shoot.wav');
  }

  // ── Collision/Damage ────────────────────────────────────────────────────────

  @override
  void hit(int damage) {
    hp -= damage;
    if (hp <= 0) {
      final pCount = game.children.whereType<ParticleSystemComponent>().length;
      if (pCount < kMaxParticleSystems) {
        game.add(explosionParticles(position.clone()));
      }
      game.audioManager.playSfx('explosion.wav');
      game.onMiniBossKilled(position.clone(), wave);
      removeFromParent();
    } else {
      final pCount = game.children.whereType<ParticleSystemComponent>().length;
      if (pCount < kMaxParticleSystems) {
        game.add(sparkParticles(position.clone()));
      }
    }
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      game.applyCollisionDamage();
      other.takeDamage(isCollision: true);
    }
  }

  // ── Render ──────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final cx = size.x / 2;
    final cy = size.y / 2;

    // ── Engine exhaust ────────────────────────────────────────────────────────
    canvas.drawPath(
      Path()
        ..moveTo(cx - 14, size.y)
        ..lineTo(cx, size.y + 20)
        ..lineTo(cx + 14, size.y)
        ..close(),
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.6)
        ..blendMode = BlendMode.plus,
    );

    // ── Hull (wider asymmetric shape) ─────────────────────────────────────────
    final hull = Path()
      ..moveTo(cx, 0)               // Nose
      ..lineTo(cx + cx * 0.6, cy * 0.5)
      ..lineTo(size.x, cy)          // Right wing
      ..lineTo(cx + cx * 0.5, cy + 8)
      ..lineTo(cx + cx * 0.3, size.y)
      ..lineTo(cx, cy * 1.6)
      ..lineTo(cx - cx * 0.3, size.y)
      ..lineTo(cx - cx * 0.5, cy + 8)
      ..lineTo(0, cy)               // Left wing
      ..lineTo(cx - cx * 0.6, cy * 0.5)
      ..close();

    canvas.drawPath(hull, Paint()..color = const Color(0xFF3B0A11));

    // ── Armor plate highlights ────────────────────────────────────────────────
    canvas.drawPath(
      Path()
        ..moveTo(cx, 4)
        ..lineTo(cx + 16, cy * 0.6)
        ..lineTo(cx - 16, cy * 0.6)
        ..close(),
      Paint()..color = const Color(0xFF6B1423),
    );

    // ── Red core glow ─────────────────────────────────────────────────────────
    final coreRect = Rect.fromCenter(center: Offset(cx, cy), width: 20, height: 20);
    canvas.drawOval(
      coreRect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, Color(0xFFFF1744), Color(0x00FF1744)],
          stops: [0.0, 0.35, 1.0],
        ).createShader(coreRect),
    );
    canvas.drawCircle(
      Offset(cx, cy), 20,
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.6)
        ..blendMode = BlendMode.plus,
    );

    // ── Weapon mounts (2 guns + 1 missile port) ───────────────────────────────
    final mountPaint = Paint()..color = const Color(0xFF1A0608);
    final gunOffsetX = cx * 0.7;
    canvas.drawRect(Rect.fromLTWH(cx - gunOffsetX - 3, cy - 8, 6, 14), mountPaint);
    canvas.drawRect(Rect.fromLTWH(cx + gunOffsetX - 3, cy - 8, 6, 14), mountPaint);
    // Central missile port
    canvas.drawRect(Rect.fromLTWH(cx - 5, cy + 4, 10, 8), mountPaint);

    // ── HP bar ───────────────────────────────────────────────────────────────
    final maxHp = _maxHp();
    final ratio  = (hp / maxHp).clamp(0.0, 1.0);
    final barW   = size.x * 0.85;
    final startX = (size.x - barW) / 2;
    canvas.drawRect(Rect.fromLTWH(startX, -12, barW, 4), Paint()..color = Colors.black45);
    canvas.drawRect(Rect.fromLTWH(startX, -12, barW * ratio, 4),
        Paint()..color = const Color(0xFFFF1744));
  }

  int _maxHp() {
    if (wave <= 12) return 600;
    if (wave <= 18) return 900;
    return 1200;
  }
}

/// Lightweight bullet fired by MiniBoss machine guns (faster, slightly different visual)
class EnemyBulletMiniBoss extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks {

  static const double _speedY = 300.0;
  static const double _width  = 5.0;
  static const double _height = 16.0;

  EnemyBulletMiniBoss({required Vector2 position})
      : super(
          position: position,
          size: Vector2(_width, _height),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += _speedY * dt;
    if (position.y > game.size.y + _height) removeFromParent();
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      game.applyBulletDamageToPlayer();
      other.takeDamage(isCollision: false);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(
      Rect.fromLTWH(-2, -2, _width + 4, _height + 4),
      Paint()
        ..color = const Color(0xFFFF1744).withValues(alpha: 0.35)
        ..blendMode = BlendMode.plus,
    );
    canvas.drawOval(
      Rect.fromLTWH(0, 0, _width, _height),
      Paint()..color = const Color(0xFFFF4444),
    );
    canvas.drawOval(
      Rect.fromLTWH(1, 1, _width - 2, _height - 4),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }
}
