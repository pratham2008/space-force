import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../zero_vector_game.dart';
import '../effects/particle_effects.dart';
import 'player.dart';

class Enemy extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks {
  static const double _size = 40.0;

  // ── Base stats ───────────────────────────────────────────────────────────────
  final double baseSpeed;
  final int scoreValue;
  int hp;

  // ── Hover config ─────────────────────────────────────────────────────────────
  // The Y fraction ceiling the enemy descends to before hovering.
  // e.g. 0.35 means it stops at 35% from the top of the screen.
  final double hoverYFraction; // max Y = game.size.y * hoverYFraction
  static const double _hoverMinFraction = 0.10; // min Y = 10% from top

  // ── Movement state ───────────────────────────────────────────────────────────
  double _currentSpeed;
  bool _aggressiveMode = false;
  bool _hovering = false;      // true once the enemy reaches its hover band
  double _hoverTargetY = 0;    // assigned on first hover entry
  double _oscillationPhase = 0;
  static const double _oscillationAmplitude = 30.0; // pixels
  static const double _oscillationSpeed = 1.8;      // radians / second

  // ── Fire system ──────────────────────────────────────────────────────────────
  double _fireTimer = 0;
  late double _fireInterval;
  final Random _random = Random();

  // When true the enemy skips hover and starts directly in aggressive mode.
  final bool startAggressive;

  Enemy({
    required Vector2 position,
    this.baseSpeed = 120.0,
    this.scoreValue = 10,
    required this.hp,
    required this.hoverYFraction,
    this.startAggressive = false,
  })  : _currentSpeed = baseSpeed,
        super(
          position: position,
          size: Vector2.all(_size),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
    _fireInterval = _calculateFireInterval();
    _fireTimer = _random.nextDouble() * _fireInterval;

    if (startAggressive) {
      // Skip hover entirely — go straight to aggressive chase mode.
      _aggressiveMode = true;
      _currentSpeed = baseSpeed * 1.4;
    } else {
      // Randomise initial X oscillation phase so enemies don't move in sync
      _oscillationPhase = _random.nextDouble() * 2 * pi;

      // Pick a random hover Y within the allowed band:
      //   [screenH * _hoverMinFraction, screenH * hoverYFraction]
      final minY = game.size.y * _hoverMinFraction;
      final maxY = game.size.y * hoverYFraction;
      _hoverTargetY = minY + _random.nextDouble() * (maxY - minY);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_aggressiveMode) {
      _updateAggressive(dt);
    } else {
      _updateHover(dt);
    }

    // Hard ceiling: never cross into player zone (>= 60% of screen)
    final playerZoneCeiling = game.size.y * 0.60;
    if (position.y > playerZoneCeiling) {
      position.y = playerZoneCeiling;
    }

    // Off-screen bottom — only reachable in aggressive mode
    if (position.y > game.size.y + _size) {
      removeFromParent();
      return;
    }

    // ── Fire ─────────────────────────────────────────────────────────────────
    _fireTimer += dt;
    if (_fireTimer >= _fireInterval) {
      _fireTimer = 0;
      _fireInterval = _calculateFireInterval();
      _fire();
    }
  }

  // ── Normal hover movement ────────────────────────────────────────────────────

  void _updateHover(double dt) {
    if (!_hovering) {
      // Descend toward hover target Y
      position.y += _currentSpeed * dt;
      if (position.y >= _hoverTargetY) {
        position.y = _hoverTargetY;
        _hovering = true;
      }
    } else {
      // Gentle horizontal oscillation while hovering
      _oscillationPhase += _oscillationSpeed * dt;
      position.x += sin(_oscillationPhase) * _oscillationAmplitude * dt;

      // Clamp X within screen
      position.x = position.x.clamp(_size / 2, game.size.x - _size / 2);
    }
  }

  // ── Aggressive movement ──────────────────────────────────────────────────────

  void _updateAggressive(double dt) {
    // Chase player X gradually
    final px = game.player?.position.x ?? position.x;
    final dx = (px - position.x).clamp(-_currentSpeed * dt, _currentSpeed * dt);
    position.x += dx;
    // Full speed downward
    position.y += _currentSpeed * dt;
  }

  // ── Activate aggressive mode ─────────────────────────────────────────────────

  void activateAggressiveMode() {
    if (_aggressiveMode) return;
    _aggressiveMode = true;
    _hovering = false;
    _currentSpeed = baseSpeed * 1.4;
  }

  // ── HP / Death ────────────────────────────────────────────────────────────────

  void hit(int damage) {
    hp -= damage;
    if (hp <= 0) {
      // Explosion particles on death
      game.add(explosionParticles(position.clone()));
      game.audioManager.playSfx('explosion.wav');
      game.onEnemyKilled(scoreValue);
      removeFromParent();
    } else {
      // Spark particles on non-lethal hit
      game.add(sparkParticles(position.clone()));
    }
  }

  // ── Collision with Player ─────────────────────────────────────────────────────

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      game.applyCollisionDamage();
      other.takeDamage(isCollision: true);
      removeFromParent();
    }
  }

  // ── Fire logic ───────────────────────────────────────────────────────────────

  double _calculateFireInterval() {
    final w = game.wave;
    if (w <= 2) return 2.0;
    if (w <= 5) return 1.5;
    return 0.8 + _random.nextDouble() * 0.7;
  }

  void _fire() {
    game.add(
      EnemyBullet(position: Vector2(position.x, position.y + _size / 2)),
    );
  }

  // ── Render ────────────────────────────────────────────────────────────────────

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFE53935);
    final path = Path()
      ..moveTo(size.x / 2, 0)
      ..lineTo(size.x, size.y / 2)
      ..lineTo(size.x / 2, size.y)
      ..lineTo(0, size.y / 2)
      ..close();
    canvas.drawPath(path, paint);

    // HP bar — only shown when damaged
    final maxHp = 2 + (game.wave * 0.6).floor();
    if (hp < maxHp) {
      final barW = size.x;
      final filled = (hp / maxHp).clamp(0.0, 1.0) * barW;
      canvas.drawRect(
        Rect.fromLTWH(0, -6, barW, 4),
        Paint()..color = const Color(0x66FF1744),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, -6, filled, 4),
        Paint()..color = const Color(0xFFFF1744),
      );
    }
  }
}

// ── Enemy Bullet ─────────────────────────────────────────────────────────────

class EnemyBullet extends PositionComponent
    with HasGameReference<ZeroVectorGame>, CollisionCallbacks {
  static const double _speed = 250.0;
  static const double _width = 5.0;
  static const double _height = 12.0;

  EnemyBullet({required Vector2 position})
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
    position.y += _speed * dt;
    if (position.y > game.size.y + _height) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      game.applyBulletDamageToPlayer();
      other.takeDamage(isCollision: false);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFFF6D00);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
  }
}
